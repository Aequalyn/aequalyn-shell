// Showcase: a carousel of cards cut in one of the bar's end shapes. The current
// item is a large card; its neighbours are smaller cards and then thin slices on
// both sides. It sits in the middle, along the top or bottom, or down the left or
// right side, where it runs vertically, and it can be made larger or smaller.
//
// Parts that can each be turned on or off (Atelier -> Panel -> Showcase):
//   palette      the theme's colours on the large card
//   backgrounds  a second row with the theme's backgrounds, to pick one with it
//   three        the two neighbours as smaller cards instead of slices
//   live         a small desktop drawn over the card in the theme's colours
//   badges       favourite, video, light / dark and the item's own badge
//   actions      shuffle, favourite, open the folder, add your own
//
// The filters (all, favourites, recent, dark, light...) are Atelier's own, in its header.
//
// Keys (the view handles the rest): ← → move (↑ ↓ when vertical); ↑ ↓ pick a
// background (← → when vertical); Ctrl+F favourite; Enter applies.
import QtQuick
import QtQuick.Effects
import Quickshell
import "root:/settings"
import ".."
import "../../../style/Paint.js" as Paint

Item {
    id: root
    property var theme
    property string font
    property var items: []
    property int currentIndex: 0
    property var host: null
    readonly property int columns: 0
    signal picked(int index)
    signal hovered(int index)

    // ---- settings ---------------------------------------------------------------
    readonly property var cfg: Object.assign({ position: "center", size: 100, shape: "bar",
        parts: {} }, AequalynSettings.atelierCfg.showcase || {})
    function part(k) { return !cfg.parts || cfg.parts[k] !== false }
    readonly property string position: ["center", "top", "bottom", "left", "right"].indexOf(cfg.position) >= 0 ? cfg.position : "center"
    readonly property bool vertical: position === "left" || position === "right"
    readonly property real zoom: Math.max(0.6, Math.min(1.4, (Number(cfg.size) || 100) / 100))
    // "bar": the bar's own ends, pointing the way the bar's do
    readonly property var barLook: AequalynSettings.barStyleCfg || ({})
    readonly property string ends: cfg.shape && cfg.shape !== "bar" ? cfg.shape : (barLook.ends || "slant")
    readonly property string dir: cfg.shape && cfg.shape !== "bar" ? "right"
        : (["left", "both"].indexOf(barLook.pointingBar) >= 0 ? barLook.pointingBar : "right")
    readonly property real cornerR: Math.max(4, Math.min(40, Number(barLook.radius) || 12))
    // shapes that end in points or cuts overlap their neighbours a little, like slats
    readonly property bool pointed: ["rounded", "capsule", "square", "oval", "bulge"].indexOf(ends) < 0

    readonly property var cur: items[currentIndex] || ({})
    readonly property bool isThemes: host ? host.collection === "themes" : false

    // ---- sizes --------------------------------------------------------------------
    readonly property real chromeTop: 0
    readonly property real chromeBottom: 44 + (part("actions") ? 30 : 0)
    readonly property bool hasBgRow: part("backgrounds") && (cur.backgrounds || []).length > 1
    readonly property real bgRowLen: hasBgRow ? 62 * zoom : 0
    readonly property real bigW: {
        if (vertical) return Math.min(width * 0.5 - bgRowLen, (height - chromeBottom) * 0.42 * 1.6, 620 * zoom);
        return Math.min(width * (part("three") ? 0.38 : 0.48), (height - chromeTop - chromeBottom - bgRowLen) * 0.92 * 1.6, 820 * zoom);
    }
    readonly property real bigH: bigW / 1.6
    readonly property real midScale: 0.62
    readonly property real sliceThin: Math.max(26, 64 * zoom)          // across the carousel
    // pointed and cut ends reach in about half the drawn thickness (28 px): neighbours
    // tuck into that, like slats; round and square ones keep a small gap
    readonly property real overlap: pointed ? 22 : -8 * zoom

    // the cards on screen, as offsets from the current one, with their size and place
    readonly property var slots: {
        const n = items.length;
        if (n === 0) return [];
        const along = vertical ? height - chromeTop - chromeBottom : width;
        const big = vertical ? bigH : bigW;
        const out = [{ d: 0, w: bigW, h: bigH, a: 0, o: 1 }];
        let reach = big / 2;
        // outwards from the current card, one on each side at a time, while they fit
        for (let d = 1; d <= 12 && 2 * d - 1 < n; d++) {
            const mid = d === 1 && part("three");
            const w = vertical ? (mid ? bigW * 0.8 : bigW * 0.88) : (mid ? bigW * midScale : sliceThin);
            const h = vertical ? (mid ? bigH * midScale : sliceThin) : (mid ? bigH * 0.8 : bigH * 0.88);
            const len = vertical ? h : w;
            const a = reach + len / 2 - overlap;
            if (a - len / 2 > along / 2) break;          // starts past the edge
            reach = a + len / 2;
            const o = mid ? 0.82 : Math.max(0.3, 0.62 - (d - 1) * 0.06);
            out.push({ d: d, w: w, h: h, a: a, o: o });
            out.push({ d: -d, w: w, h: h, a: -a, o: o });
        }
        // fewer items than places: each item once
        const seen = {};
        return out.filter(s => { const j = ((root.currentIndex + s.d) % n + n) % n; if (seen[j]) return false; seen[j] = true; return true; });
    }

    // ---- the backgrounds row ------------------------------------------------------
    property int bgIndex: 0
    function resetBg() {
        const list = cur.backgrounds || [];
        const now = AtelierService.current;
        const i = list.indexOf(now);
        bgIndex = i >= 0 ? i : 0;
    }
    onCurChanged: resetBg()
    Component.onCompleted: resetBg()

    // ---- actions ------------------------------------------------------------------
    // Applies through Atelier itself (not this layout's signal): a full screen
    // Atelier closes right away, and this layout with it.
    function apply(index, closeAfter) {
        const it = items[index];
        if (!it) return;
        const h = host;
        if (!h) { root.picked(index); return; }
        const list = it.backgrounds || [];
        const bg = index === currentIndex && hasBgRow ? list[bgIndex] : "";
        // a chosen background goes in first: setting the theme keeps a background
        // that belongs to it, and only otherwise switches to its first one
        if (bg && bg !== AtelierService.current)
            AtelierService.run(["aequalyn-wallpaper", "set", bg], false, () => h.apply(index, closeAfter));
        else
            h.apply(index, closeAfter);
    }
    function shuffle() {
        if (items.length > 1) {
            let j = currentIndex;
            while (j === currentIndex) j = Math.floor(Math.random() * items.length);
            root.hovered(j);
        }
    }
    function openDir(dir) {
        if (dir) Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && xdg-open "$1"', "sh", dir]);
    }
    function itemDir(it) {
        if (!it) return "";
        if (it.dir) return it.dir;
        if (it.path) return it.path.replace(/\/[^/]*$/, "");
        return "";
    }
    function addDir() {
        if (isThemes) return Quickshell.env("HOME") + "/.config/aequalyn/themes";
        const f = (AequalynSettings.wallpaperCfg.folder || "~/Pictures/Wallpapers");
        return f.replace(/^~/, Quickshell.env("HOME"));
    }

    // keys this layout handles before the view does
    function handleKey(event) {
        const ctrl = event.modifiers & Qt.ControlModifier;
        if (ctrl && event.key === Qt.Key_F) { if (host) host.toggleFavorite(cur); return true; }
        const prev = vertical ? Qt.Key_Up : Qt.Key_Left, next = vertical ? Qt.Key_Down : Qt.Key_Right;
        const bgPrev = vertical ? Qt.Key_Left : Qt.Key_Up, bgNext = vertical ? Qt.Key_Right : Qt.Key_Down;
        const n = items.length;
        if (event.key === prev && n) { root.hovered((currentIndex - 1 + n) % n); return true; }
        if (event.key === next && n) { root.hovered((currentIndex + 1) % n); return true; }
        if (hasBgRow && (event.key === bgPrev || event.key === bgNext)) {
            const m = cur.backgrounds.length;
            bgIndex = (bgIndex + (event.key === bgNext ? 1 : -1) + m) % m;
            return true;
        }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            // full screen: apply and close (Shift keeps it open), as everywhere in Atelier
            apply(currentIndex, !!host && host.surface === "overlay" && !(event.modifiers & Qt.ShiftModifier));
            return true;
        }
        return false;
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const n = root.items.length;
            if (n === 0) return;
            const d = (event.angleDelta.y || event.angleDelta.x) < 0 ? 1 : -1;
            root.hovered((root.currentIndex + d + n) % n);
        }
    }

    // ---- layout ------------------------------------------------------------------
    // where the carousel's middle sits
    readonly property real cx: position === "left" ? bigW / 2 + 24 + (hasBgRow ? 0 : 0)
                             : position === "right" ? width - bigW / 2 - 24
                             : width / 2
    readonly property real cy: position === "top" ? chromeTop + bigH / 2 + 8
                             : position === "bottom" ? height - chromeBottom - bgRowLen - bigH / 2
                             : chromeTop + (height - chromeTop - chromeBottom - bgRowLen) / 2

    // the cards
    Repeater {
        model: root.slots
        delegate: Card {
            required property var modelData
            readonly property int itemIndex: ((root.currentIndex + modelData.d) % root.items.length + root.items.length) % root.items.length
            item: root.items[itemIndex] || ({})
            big: modelData.d === 0
            width: modelData.w
            height: modelData.h
            x: root.vertical ? root.cx - width / 2 : root.cx + modelData.a - width / 2
            y: root.vertical ? root.cy + modelData.a - height / 2 : root.cy - height / 2
            z: 100 - Math.abs(modelData.d)
            opacity: modelData.o
            Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            onClicked: modelData.d === 0 ? root.apply(itemIndex, false) : root.hovered(itemIndex)
        }
    }

    // the theme's backgrounds
    Item {
        id: bgRow
        visible: root.hasBgRow
        readonly property var list: root.cur.backgrounds || []
        readonly property real tw: 72 * root.zoom
        readonly property real th: 44 * root.zoom
        x: root.vertical ? (root.position === "left" ? root.cx + root.bigW / 2 + 14 : root.cx - root.bigW / 2 - 14 - tw)
                         : root.cx - (list.length * (tw - 6)) / 2
        y: root.vertical ? root.cy - (list.length * (th - 4)) / 2 : root.cy + root.bigH / 2 + 12
        Repeater {
            model: bgRow.list
            delegate: Card {
                required property var modelData
                required property int index
                item: ({ image: modelData })
                small: true
                width: bgRow.tw * (index === root.bgIndex ? 1.15 : 1)
                height: bgRow.th * (index === root.bgIndex ? 1.15 : 1)
                x: root.vertical ? 0 : index * (bgRow.tw - 6)
                y: root.vertical ? index * (bgRow.th - 4) : 0
                z: index === root.bgIndex ? 10 : 0
                opacity: index === root.bgIndex ? 1 : 0.55
                onClicked: root.bgIndex = index
            }
        }
    }

    // name and the actions
    Column {
        spacing: 6
        width: Math.max(root.bigW, 260)
        x: root.cx - width / 2
        y: root.vertical ? root.height - height - 6
         : root.position === "bottom" ? root.height - height - 4
         : root.cy + root.bigH / 2 + (root.hasBgRow ? bgRow.th * 1.15 + 20 : 12)
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: (root.cur.title || "") + (root.cur.subtitle ? "  ·  " + root.cur.subtitle : "")
                + (root.items.length ? "   " + (root.currentIndex + 1) + " / " + root.items.length : "")
            color: root.theme.textPrimary
            font.family: root.font
            font.pixelSize: 13
            elide: Text.ElideRight
        }
        Row {
            visible: root.part("actions")
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6
            ActionChip { glyph: "󰒝"; label: "Shuffle"; onClicked: root.shuffle() }
            ActionChip {
                glyph: root.host && root.host.isFavorite(root.cur) ? "★" : "☆"
                label: "Favourite"
                onClicked: if (root.host) root.host.toggleFavorite(root.cur)
            }
            ActionChip { glyph: "󰉋"; label: "Folder"; visible: root.itemDir(root.cur) !== ""; onClicked: root.openDir(root.itemDir(root.cur)) }
            ActionChip { glyph: "󰐕"; label: root.isThemes ? "Add a theme" : "Add wallpapers"; onClicked: root.openDir(root.addDir()) }
        }
    }

    component ActionChip: Rectangle {
        id: chip
        property string glyph: ""
        property string label: ""
        signal clicked()
        height: 24
        width: chipRow.implicitWidth + 16
        radius: 12
        color: chipArea.containsMouse ? root.theme.bgHover : root.theme.bgSurface
        border.color: root.theme.bgBorder
        border.width: 1
        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 6
            Text { text: chip.glyph; color: root.theme.accentPrimary; font.family: root.font; font.pixelSize: 12 }
            Text { text: chip.label; color: root.theme.textSecondary; font.family: root.font; font.pixelSize: 11 }
        }
        MouseArea { id: chipArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: chip.clicked() }
    }

    // ---- one card, cut in the chosen shape ----------------------------------------
    component Card: Item {
        id: card
        property var item: ({})
        property bool big: false
        property bool small: false
        signal clicked()
        readonly property var pal: (item && item.palette) || root.theme
        readonly property bool hasImage: !!(item && item.image)

        Item {
            id: content
            anchors.fill: parent
            layer.enabled: GraphicsInfo.api !== GraphicsInfo.Software
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: mask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }
            Rectangle { anchors.fill: parent; color: root.theme.bgSurface }
            Image {
                anchors.fill: parent
                visible: card.hasImage
                source: card.hasImage ? "file://" + card.item.image : ""
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: card.big ? 1280 : (card.small ? 200 : 480)
                asynchronous: true
                cache: true
            }
            PaletteMock {
                anchors.fill: parent
                visible: !card.hasImage && !!(card.item && card.item.palette)
                colors: (card.item && card.item.palette) || ({})
            }
            // the live desktop: bar, two windows and a dock in the item's colours
            Item {
                anchors.fill: parent
                visible: card.big && root.part("live")
                Rectangle {
                    x: parent.width * 0.1; y: parent.height * 0.07
                    width: parent.width * 0.8; height: Math.max(6, parent.height * 0.06)
                    radius: 2; color: card.pal.bgBase || "#151a26"; opacity: 0.94
                    Rectangle { x: 4; anchors.verticalCenter: parent.verticalCenter; width: parent.width * 0.12; height: parent.height * 0.5; radius: 1; color: card.pal.accentPrimary || "#88c0d0" }
                    Rectangle { anchors.right: parent.right; anchors.rightMargin: 4; anchors.verticalCenter: parent.verticalCenter; width: parent.width * 0.16; height: parent.height * 0.5; radius: 1; color: card.pal.bgSelected || "#3b4252" }
                }
                Rectangle {
                    x: parent.width * 0.12; y: parent.height * 0.19
                    width: parent.width * 0.46; height: parent.height * 0.54
                    radius: 4; color: card.pal.bgBase || "#151a26"; opacity: 0.94
                    border.width: 2; border.color: card.pal.accentPrimary || "#88c0d0"
                    Column {
                        x: 8; y: 6; spacing: 2
                        Text { text: "❯ ls"; color: card.pal.accentPrimary || "#88c0d0"; font.family: root.font; font.pixelSize: Math.max(8, card.height / 26) }
                        Text { text: "themes  walls"; color: card.pal.accentGreen || "#a3be8c"; font.family: root.font; font.pixelSize: Math.max(8, card.height / 26) }
                    }
                }
                Rectangle {
                    x: parent.width * 0.61; y: parent.height * 0.19
                    width: parent.width * 0.27; height: parent.height * 0.54
                    radius: 4; color: card.pal.bgBase || "#151a26"; opacity: 0.9
                    border.width: 1; border.color: card.pal.bgBorder || "#3b4252"
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height * 0.82
                    width: parent.width * 0.3; height: Math.max(8, parent.height * 0.08)
                    radius: height / 2; color: card.pal.bgBase || "#151a26"; opacity: 0.94
                    Row {
                        anchors.centerIn: parent; spacing: parent.width * 0.08
                        Repeater {
                            model: [card.pal.accentPrimary, card.pal.accentCyan, card.pal.accentGreen]
                            Rectangle { required property var modelData; width: card.height * 0.035; height: width; radius: width / 2; color: modelData || "#88c0d0" }
                        }
                    }
                }
            }
        }

        // the shape: the bar's painter draws it, white where the card shows
        Canvas {
            id: mask
            anchors.fill: parent
            visible: false
            layer.enabled: true
            readonly property var key: [width, height, root.ends, root.dir, root.vertical, root.cornerR, card.small]
            onKeyChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                if (width <= 0 || height <= 0) return;
                ctx.fillStyle = "#ffffff";
                ctx.save();
                let L = width, T = height;
                if (root.vertical) {
                    // the ends turn with the carousel: they face up and down
                    ctx.translate(width, 0);
                    ctx.rotate(Math.PI / 2);
                    L = height; T = width;
                }
                // The bar's ends are as deep as the shape is thick, made for a bar
                // some 30 px tall. Drawn that thin and stretched to the card's height,
                // they cut in by a few dozen pixels on a card of any size.
                const t = Math.max(12, Math.min(T, card.small ? 18 : 56));
                const r = Math.min(card.small ? 6 : root.cornerR, t / 2);
                ctx.scale(1, T / t);
                Paint.outline(ctx, 0, 0, L, t, r, root.ends, "", "", root.dir, "");
                ctx.fill();
                ctx.restore();
            }
        }

        // the colours of the large card's theme
        Row {
            visible: card.big && root.part("palette") && !!(card.item && card.item.palette)
            anchors.left: parent.left
            anchors.leftMargin: Math.max(16, parent.width * 0.08)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.max(10, parent.height * 0.05)
            spacing: 4
            Repeater {
                model: card.item && card.item.palette ? ["accentPrimary", "accentCyan", "accentGreen", "accentOrange", "accentRed", "textPrimary"] : []
                Rectangle {
                    required property var modelData
                    width: Math.max(10, card.height * 0.06); height: width; radius: 3
                    color: card.item.palette[modelData] || "transparent"
                    border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.35)
                }
            }
        }

        // badges: favourite, video, light / dark, the item's own
        Row {
            visible: root.part("badges") && !card.small && (card.big || card.width > root.sliceThin * 1.5)
            anchors.right: parent.right
            anchors.rightMargin: Math.max(16, parent.width * 0.08)
            anchors.top: parent.top
            anchors.topMargin: Math.max(8, parent.height * (card.big && root.part("live") ? 0.16 : 0.05))
            spacing: 4
            Repeater {
                model: {
                    const it = card.item || {};
                    const out = [];
                    if (root.host && root.host.isFavorite(it)) out.push("★");
                    if (it.video) out.push("▶ video");
                    if (it.palette) out.push(it.light ? "light" : "dark");
                    if (it.badge) out.push(String(it.badge).toLowerCase());
                    if (it.active) out.push("in use");
                    return out;
                }
                Rectangle {
                    required property var modelData
                    height: 18; width: badgeText.implicitWidth + 12; radius: 9
                    color: Qt.rgba(0, 0, 0, 0.6)
                    Text { id: badgeText; anchors.centerIn: parent; text: parent.modelData; color: parent.modelData === "★" ? "#f9e2af" : "#ffffff"; font.family: root.font; font.pixelSize: 10 }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: card.clicked()
        }
    }
}
