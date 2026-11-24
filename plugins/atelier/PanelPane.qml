// The theme and wallpaper picker (Super + T, Super + W): its type, and for the Showcase
// type its shape, where it sits, how big it is and what it shows. (The bar's Themes and
// Layouts buttons are set on the Bar page.)
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
    property string font: AequalynSettings.monoFont
    // "" shows every part; "type", "shape", "place" or "parts" one of them
    property string section: ""
    // the collection whose picker type the Shape part edits (the page's preview shows it)
    property string collection: "themes"
    function shows(s) { return section === "" || section === s; }

    readonly property var cfg: AequalynSettings.atelierCfg
    function set(key, value) { AequalynSettings.setIn("atelier", key, value); }
    // The shape override is shared across picker modes per collection. Slices and
    // Showcase retain their own placement, size and parts settings.
    readonly property string pickType: (cfg.layouts || {})[collection] || "slices"
    readonly property var cardsCfg: cfg.cards || ({})
    readonly property var cardsOwn: cardsCfg[collection] || ({})
    readonly property var shapeOwn: AequalynSettings.pickerCfg("cards", collection)
    readonly property var layoutOwn: AequalynSettings.pickerCfg(pickType, collection)
    readonly property string currentShape: {
        if (cardsOwn.shape !== undefined) return cardsOwn.shape;
        if (pickType === "slices") return layoutOwn.shape || "original";
        if (pickType === "showcase") return layoutOwn.shape || "bar";
        return shapeOwn.shape || "original";
    }
    readonly property string originalShape: pickType === "slices" ? "slant"
        : pickType === "showcase" ? (barLook.ends || "slant") : "rounded"
    readonly property string currentPosition: layoutOwn.position || "center"
    readonly property real currentSize: Number(layoutOwn.size) || 100
    function setShape(k) { AequalynSettings.setPicker("cards", collection, "shape", k); }
    function setFor(key, value) { AequalynSettings.setPicker(pickType, collection, key, value); }
    // the Showcase type's parts, for this collection
    readonly property var showcaseOwn: layoutOwn
    function setPart(key, on) {
        const parts = Object.assign({}, showcaseOwn.parts || {});
        parts[key] = on;
        AequalynSettings.setPicker("showcase", collection, "parts", parts);
    }

    // the bar's look: the shape tiles are painted in it, like the bar and dock ones
    readonly property var barLook: BarLooks.clean(AequalynSettings.barStyleCfg)
    readonly property var pal: Colors.forMode(theme, barLook.colorMode, barLook)

    readonly property var types: [
        ["slices", "Slices"], ["showcase", "Showcase"], ["carousel", "Carousel"], ["grid", "Grid"],
        ["filmstrip", "Filmstrip"], ["radial", "Radial"], ["list", "List"], ["spotlight", "Spotlight"]
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
                readonly property string current: (pane.cfg.layouts || {})[modelData[0]] || "slices"
                visible: pane.shows("type")
                theme: pane.theme; font: pane.font
                icon: modelData[2]
                title: modelData[1]
                sub: modelData[0] === "themes" ? "How Super + T lays out themes. Ctrl + 1 to 8 switches it while it is open."
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
            title: "Shape of the preview windows"
            sub: "For " + (pane.collection === "themes" ? "themes" : "wallpapers") + " in every picker layout. “Same as the bar” follows its shape."
            Flow {
                visible: true
                Layout.fillWidth: true
                spacing: 8
                StyleTile {
                    theme: pane.theme; font: pane.font
                    pal: pane.pal
                    edge: "top"
                    look: Object.assign({}, pane.barLook, { ends: pane.originalShape })
                    label: "Default for this layout"
                    selected: pane.currentShape === "original"
                    onClicked: pane.setShape("original")
                }
                StyleTile {
                    theme: pane.theme; font: pane.font
                    pal: pane.pal
                    edge: "top"
                    look: pane.barLook
                    label: "Same as the bar"
                    selected: pane.currentShape === "bar"
                    onClicked: pane.setShape("bar")
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
                        selected: pane.currentShape === modelData
                        onClicked: pane.setShape(modelData)
                    }
                }
            }
        }

        // ---- where it sits and how big ----------------------------------------------------
        Group {
            visible: pane.shows("place")
            theme: pane.theme; font: pane.font
            icon: "󰍹"
            title: "Where on the screen" + (pane.pickType === "slices" ? ": Slices" : pane.pickType === "showcase" ? ": Showcase" : "")
            sub: pane.pickType !== "slices" && pane.pickType !== "showcase" ? "Card based layouts use their own placement."
               : "Left and right make it run top to bottom."
            Flow {
                visible: pane.pickType === "slices" || pane.pickType === "showcase"
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                    model: pane.places
                    delegate: PictureTile {
                        required property var modelData
                        label: modelData[1]
                        selected: pane.currentPosition === modelData[0]
                        kind: "place:" + modelData[0]
                        onClicked: pane.setFor("position", modelData[0])
                    }
                }
            }
            Stepper {
                visible: pane.pickType === "slices" || pane.pickType === "showcase"
                theme: pane.theme; font: pane.font
                label: "Size"; suffix: "%"
                from: 60; to: 140; step: 10
                value: pane.currentSize
                onStepped: v => pane.setFor("size", v)
            }
        }

        // ---- what it shows ---------------------------------------------------------------
        Group {
            visible: pane.shows("parts")
            theme: pane.theme; font: pane.font
            icon: "󰋩"
            title: "What the Showcase shows: " + (pane.collection === "themes" ? "theme picker" : "wallpaper picker")
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
                    checked: !pane.showcaseOwn.parts || pane.showcaseOwn.parts[modelData[0]] !== false
                    onToggled: v => pane.setPart(modelData[0], v)
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
                    if (k === "slices") { for (const i of [-3, -2, -1, 1, 2, 3]) { const sx = i < 0 ? 26 + i * 6 : 64 + i * 6; ctx.fillStyle = off; ctx.beginPath(); ctx.moveTo(sx + 3, 9); ctx.lineTo(sx + 9, 9); ctx.lineTo(sx + 6, 41); ctx.lineTo(sx, 41); ctx.closePath(); ctx.fill(); } ctx.fillStyle = on; ctx.beginPath(); ctx.moveTo(32, 6); ctx.lineTo(70, 6); ctx.lineTo(64, 44); ctx.lineTo(26, 44); ctx.closePath(); ctx.fill(); }
                    else if (k === "showcase") { box(8, 16, 8, 18, off); box(19, 16, 8, 18, off); box(30, 9, 36, 32, on); box(69, 16, 8, 18, off); box(80, 16, 8, 18, off); }
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
            font.family: AequalynSettings.uiFont
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
