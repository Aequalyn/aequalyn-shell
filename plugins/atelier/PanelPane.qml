// The theme and wallpaper picker (Super + T, Super + W): its type, the Showcase's shape,
// where it sits and how big it is, what it shows, and what the two bar buttons do.
// Every choice is a picture. Shown by the control center's Theme picker page, a part per
// tab (`section`); the page pins a live PickerPreview above it.
import QtQuick
import QtQuick.Layouts
import "controls"
import "root:/settings"
import  "../../style/Style.js" as Style
import  "../../style/BarLooks.js" as BarLooks
import  "../../style/Colors.js" as Colors

Flickable {
    id: pane
    property var theme
    property string font: "JetBrainsMono Nerd Font"
    // "" shows every part; "type", "shape", "place" or "parts" one of them
    property string section: ""
    function shows(s) { return section === "" || section === s; }

    readonly property var cfg: AequalynSettings.atelierCfg
    function set(key, value) { AequalynSettings.setIn("atelier", key, value); }
    readonly property var showcase: cfg.showcase || ({})
    function setShowcase(key, value) {
        const next = Object.assign({}, showcase);
        next[key] = value;
        set("showcase", next);
    }

    // the bar's look: the shape tiles are painted in it, like the bar and dock ones
    readonly property var barLook: BarLooks.clean(AequalynSettings.barStyleCfg)
    readonly property var pal: Colors.forMode(theme, barLook.colorMode, barLook)

    readonly property var types: [
        ["showcase", "Showcase"], ["carousel", "Carousel"], ["grid", "Grid"], ["filmstrip", "Filmstrip"],
        ["radial", "Radial"], ["list", "List"], ["spotlight", "Spotlight"]
    ]
    readonly property var places: [["center", "Middle"], ["top", "Top"], ["bottom", "Bottom"], ["left", "Left"], ["right", "Right"]]
    readonly property var actions: [
        ["next-layout", "Next layout"], ["prev-layout", "Previous layout"],
        ["next-wallpaper", "Next wallpaper"], ["random-wallpaper", "Random wallpaper"],
        ["themes", "Themes"], ["none", "Nothing"]
    ]

    contentHeight: column.implicitHeight + 24
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    ColumnLayout {
        id: column
        width: pane.width
        spacing: 14

        // ---- type: a little drawing of each, for themes and for wallpapers ---------------
        Repeater {
            model: [["themes", "Themes", "󰏘"], ["wallpapers", "Wallpapers", "󰸉"]]
            delegate: Group {
                id: typeGroup
                required property var modelData
                readonly property string current: (pane.cfg.layouts || {})[modelData[0]] || "showcase"
                visible: pane.shows("type")
                theme: pane.theme; font: pane.font
                icon: modelData[2]
                title: modelData[1]
                sub: modelData[0] === "themes" ? "How Super + T lays out themes. Ctrl + 1 to 7 switches it while it is open."
                                               : "How Super + W lays out wallpapers."
                Flow {
                    Layout.fillWidth: true
                    spacing: 8
                    Repeater {
                        model: pane.types
                        delegate: PictureTile {
                            required property var modelData
                            label: modelData[1]
                            selected: typeGroup.current === modelData[0]
                            kind: "type:" + modelData[0]
                            onClicked: {
                                const next = Object.assign({}, pane.cfg.layouts || {});
                                next[typeGroup.modelData[0]] = modelData[0];
                                pane.set("layouts", next);
                            }
                        }
                    }
                }
            }
        }

        // ---- shape: the bar's ends, painted ---------------------------------------------
        Group {
            visible: pane.shows("shape")
            theme: pane.theme; font: pane.font
            icon: "󰕮"
            title: "Shape of the cards"
            sub: "For the Showcase. The same shapes as the bar and the docks; “Same as the bar” changes with it."
            Flow {
                Layout.fillWidth: true
                spacing: 8
                StyleTile {
                    theme: pane.theme; font: pane.font
                    pal: pane.pal
                    edge: "top"
                    look: pane.barLook
                    label: "Same as the bar"
                    selected: (pane.showcase.shape || "bar") === "bar"
                    onClicked: pane.setShowcase("shape", "bar")
                }
                Repeater {
                    model: Style.ends.options
                    delegate: StyleTile {
                        required property string modelData
                        theme: pane.theme; font: pane.font
                        pal: pane.pal
                        edge: "top"
                        look: Object.assign({}, pane.barLook, { ends: modelData })
                        label: Style.ends.labels[modelData] || modelData
                        selected: pane.showcase.shape === modelData
                        onClicked: pane.setShowcase("shape", modelData)
                    }
                }
            }
        }

        // ---- where it sits and how big ----------------------------------------------------
        Group {
            visible: pane.shows("place")
            theme: pane.theme; font: pane.font
            icon: "󰍹"
            title: "Where on the screen"
            sub: "Left and right make it run top to bottom."
            Flow {
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                    model: pane.places
                    delegate: PictureTile {
                        required property var modelData
                        label: modelData[1]
                        selected: (pane.showcase.position || "center") === modelData[0]
                        kind: "place:" + modelData[0]
                        onClicked: pane.setShowcase("position", modelData[0])
                    }
                }
            }
            Stepper {
                theme: pane.theme; font: pane.font
                label: "Size"; suffix: "%"
                from: 60; to: 140; step: 10
                value: Number(pane.showcase.size) || 100
                onStepped: v => pane.setShowcase("size", v)
            }
        }

        // ---- what it shows ---------------------------------------------------------------
        Group {
            visible: pane.shows("parts")
            theme: pane.theme; font: pane.font
            icon: "󰋩"
            title: "What the Showcase shows"
            Repeater {
                model: [
                    ["palette", "Theme colours on the large card"],
                    ["backgrounds", "The theme's wallpapers in a second row, to pick one with it"],
                    ["three", "Neighbours as cards, not slices"],
                    ["live", "A small desktop drawn in the theme's colours"],
                    ["badges", "Badges: favourite, video, light or dark"],
                    ["actions", "Shuffle, favourite, folder and add buttons"]
                ]
                delegate: Toggle {
                    required property var modelData
                    theme: pane.theme; font: pane.font
                    label: modelData[1]
                    checked: !pane.showcase.parts || pane.showcase.parts[modelData[0]] !== false
                    onToggled: v => {
                        const parts = Object.assign({}, pane.showcase.parts || {});
                        parts[modelData[0]] = v;
                        pane.setShowcase("parts", parts);
                    }
                }
            }
            Toggle {
                theme: pane.theme; font: pane.font
                label: "Preview themes on the whole desktop"
                sublabel: "The bar, dock and every panel take the colours of the theme you are on, until you pick one or close the picker."
                checked: pane.cfg.livePreview !== false
                onToggled: v => pane.set("livePreview", v)
            }
        }

        // ---- the two bar buttons -----------------------------------------------------------
        Repeater {
            model: [
                { key: "atelier", title: "Themes button", icon: "󰉦", sub: "Opens the theme picker. Shows the active theme next to the icon." },
                { key: "layouts", title: "Layouts button", icon: "󰕰", sub: "Opens Arranging windows. Shows the focused workspace's layout next to the icon." }
            ]
            delegate: Group {
                id: buttonCfg
                required property var modelData
                readonly property string k: modelData.key
                visible: pane.shows("parts")
                theme: pane.theme; font: pane.font
                icon: modelData.icon
                title: modelData.title
                sub: modelData.sub + " Add, move or hide it in Bar → What it shows."
                Toggle {
                    theme: pane.theme; font: pane.font
                    label: "Show the name"
                    checked: pane.cfg[buttonCfg.k + "ShowName"] !== false
                    onToggled: v => pane.set(buttonCfg.k + "ShowName", v)
                }
                Repeater {
                    model: [["Right", "Right click"], ["Middle", "Middle click"]]
                    delegate: ChoiceRow {
                        id: clickRow
                        required property var modelData
                        readonly property string cfgKey: buttonCfg.k + modelData[0] + "Click"
                        readonly property string fallback: buttonCfg.k === "layouts"
                            ? (modelData[0] === "Right" ? "next-layout" : "prev-layout")
                            : (modelData[0] === "Right" ? "next-wallpaper" : "random-wallpaper")
                        theme: pane.theme; font: pane.font
                        label: modelData[1]
                        options: pane.actions.map(a => a[0])
                        labels: {
                            const out = {};
                            for (const a of pane.actions) out[a[0]] = a[1];
                            return out;
                        }
                        value: pane.cfg[cfgKey] || fallback
                        onPicked: v => pane.set(cfgKey, v)
                    }
                }
            }
        }
    }

    // A choice drawn as a little picture: a type of picker ("type:grid") or where it sits
    // ("place:left").
    component PictureTile: Rectangle {
        id: tile
        property string label: ""
        property string kind: ""
        property bool selected: false
        signal clicked()
        implicitWidth: 112
        implicitHeight: 82
        radius: 12
        color: selected ? Qt.rgba(pane.theme.accentPrimary.r, pane.theme.accentPrimary.g, pane.theme.accentPrimary.b, 0.14)
             : Qt.rgba(pane.theme.textPrimary.r, pane.theme.textPrimary.g, pane.theme.textPrimary.b, area.containsMouse ? 0.10 : 0.05)
        border.width: 2
        border.color: selected ? pane.theme.accentPrimary : "transparent"
        Accessible.role: Accessible.RadioButton
        Accessible.name: label
        Accessible.checked: selected

        Canvas {
            x: 8; y: 8
            width: parent.width - 16
            height: 50
            readonly property var key: [tile.kind, tile.selected, String(pane.theme.accentPrimary), String(pane.theme.textPrimary)]
            onKeyChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const w = width, h = height;
                const ac = pane.theme.accentPrimary, fg = pane.theme.textPrimary;
                const rgba = (c, a) => "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + a + ")";
                const on = rgba(ac, 1), off = rgba(fg, 0.3);
                const box = (x, y, bw, bh, c) => { ctx.fillStyle = c; ctx.beginPath(); ctx.roundedRect(x, y, bw, bh, 3, 3); ctx.fill(); };
                // the screen
                ctx.fillStyle = rgba(fg, 0.06);
                ctx.beginPath(); ctx.roundedRect(0, 0, w, h, 6, 6); ctx.fill();
                const parts = tile.kind.split(":"), what = parts[0], k = parts[1];
                if (what === "type") {
                    if (k === "showcase") { box(8, 16, 8, 18, off); box(19, 16, 8, 18, off); box(30, 9, 36, 32, on); box(69, 16, 8, 18, off); box(80, 16, 8, 18, off); }
                    else if (k === "carousel") { box(8, 15, 20, 20, off); box(32, 7, 32, 36, on); box(68, 15, 20, 20, off); }
                    else if (k === "grid") { for (let r = 0; r < 2; r++) for (let c = 0; c < 4; c++) box(10 + c * 20, 9 + r * 17, 16, 13, r === 0 && c === 1 ? on : off); }
                    else if (k === "filmstrip") { box(18, 5, 60, 26, on); for (let c = 0; c < 5; c++) box(10 + c * 16, 35, 13, 10, c === 2 ? on : off); }
                    else if (k === "radial") { for (let i = 0; i < 8; i++) { const a = i / 8 * Math.PI * 2; box(w / 2 - 5 + Math.cos(a) * 30, h / 2 - 5 + Math.sin(a) * 17, 10, 10, i === 0 ? on : off); } }
                    else if (k === "list") { for (let r = 0; r < 4; r++) box(14, 6 + r * 10, 68, 7, r === 1 ? on : off); }
                    else if (k === "spotlight") { box(4, 4, w - 8, h - 16, on); for (let c = 0; c < 6; c++) box(14 + c * 12, h - 9, 9, 6, off); }
                } else {
                    // three cards, the middle one large, where the picker sits
                    const vert = k === "left" || k === "right";
                    const cx = k === "left" ? 14 : k === "right" ? w - 14 : w / 2;
                    const cy = k === "top" ? 12 : k === "bottom" ? h - 12 : h / 2;
                    for (const i of [-1, 0, 1]) {
                        const big = i === 0;
                        if (vert) { const a = big ? 14 : 9, b = big ? 18 : 12; box(cx - b / 2, cy + i * 15 - a / 2, b, a, big ? on : off); }
                        else { const a = big ? 22 : 14, b = big ? 16 : 11; box(cx + i * 23 - a / 2, cy - b / 2, a, b, big ? on : off); }
                    }
                }
            }
        }
        Text {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 7
            anchors.horizontalCenter: parent.horizontalCenter
            text: tile.label
            color: tile.selected ? pane.theme.textPrimary : pane.theme.textSecondary
            font.family: "sans-serif"
            font.pixelSize: 11
            font.weight: tile.selected ? Font.DemiBold : Font.Normal
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.clicked()
        }
    }
}
