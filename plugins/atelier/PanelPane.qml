// The theme and wallpaper picker (Super + T, Super + W): its type, the Showcase's
// shape, place and parts, and what the two bar buttons do. Shown by the control
// center's Theme picker page.
import QtQuick
import QtQuick.Layouts
import "controls"
import "root:/settings"
import  "../../style/parts/Ends.js" as Ends

Flickable {
    id: pane
    property var theme
    property string font: "JetBrainsMono Nerd Font"

    readonly property var cfg: AequalynSettings.atelierCfg
    function set(key, value) { AequalynSettings.setIn("atelier", key, value); }
    readonly property var showcase: cfg.showcase || ({})
    function setShowcase(key, value) {
        const next = Object.assign({}, showcase);
        next[key] = value;
        set("showcase", next);
    }

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
        spacing: 12

        // ---- the type of picker, for themes and for wallpapers ---------------------
        SectionHeader {
            theme: pane.theme; font: pane.font
            text: "Type"
            sub: "How the picker lays out themes and wallpapers. Ctrl + 1 to 7 switches it while it is open."
        }
        Repeater {
            model: [["themes", "Themes"], ["wallpapers", "Wallpapers"]]
            delegate: ChoiceRow {
                required property var modelData
                theme: pane.theme; font: pane.font
                label: modelData[1]
                options: ["showcase", "carousel", "grid", "filmstrip", "radial", "list", "spotlight"]
                labels: ({ showcase: "Showcase", carousel: "Carousel", grid: "Grid", filmstrip: "Filmstrip",
                           radial: "Radial", list: "List", spotlight: "Spotlight" })
                value: (pane.cfg.layouts || {})[modelData[0]] || "showcase"
                onPicked: v => {
                    const next = Object.assign({}, pane.cfg.layouts || {});
                    next[modelData[0]] = v;
                    pane.set("layouts", next);
                }
            }
        }

        // ---- the two bar buttons ------------------------------------------
        Repeater {
            model: [
                { key: "atelier", title: "Themes button", icon: "󰉦", sub: "Opens the theme picker. Shows the active theme next to the icon." },
                { key: "layouts", title: "Layouts button", icon: "󰕰", sub: "Opens Arranging windows. Shows the focused workspace's layout next to the icon." }
            ]
            delegate: ColumnLayout {
                id: buttonCfg
                required property var modelData
                readonly property string k: modelData.key
                Layout.fillWidth: true
                spacing: 10

                SectionHeader {
                    theme: pane.theme; font: pane.font
                    text: buttonCfg.modelData.icon + "  " + buttonCfg.modelData.title
                    sub: buttonCfg.modelData.sub + " Add, move or hide it in Bar → What it shows."
                }
                Toggle {
                    theme: pane.theme; font: pane.font
                    label: "Show the name"
                    checked: pane.cfg[buttonCfg.k + "ShowName"] !== false
                    onToggled: v => pane.set(buttonCfg.k + "ShowName", v)
                }
                Repeater {
                    model: [["Right", "Right click"], ["Middle", "Middle click"]]
                    delegate: RowLayout {
                        id: clickRow
                        required property var modelData
                        readonly property string cfgKey: buttonCfg.k + modelData[0] + "Click"
                        readonly property string fallback: buttonCfg.k === "layouts"
                            ? (modelData[0] === "Right" ? "next-layout" : "prev-layout")
                            : (modelData[0] === "Right" ? "next-wallpaper" : "random-wallpaper")
                        spacing: 10
                        Text {
                            Layout.preferredWidth: 90
                            text: clickRow.modelData[1]
                            color: pane.theme.textSecondary
                            font.family: pane.font
                            font.pixelSize: 11
                        }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 6
                            Repeater {
                                model: pane.actions
                                Chip {
                                    required property var modelData
                                    theme: pane.theme; font: pane.font; compact: true
                                    text: modelData[1]
                                    selected: (pane.cfg[clickRow.cfgKey] || clickRow.fallback) === modelData[0]
                                    onClicked: pane.set(clickRow.cfgKey, modelData[0])
                                }
                            }
                        }
                    }
                }
            }
        }

        // ---- the Showcase picker ------------------------------------------------
        SectionHeader {
            theme: pane.theme; font: pane.font
            text: "Showcase"
            sub: "The theme and wallpaper picker: a large card between smaller ones. On the left or right it runs top to bottom."
        }
        ChoiceRow {
            theme: pane.theme; font: pane.font
            label: "Position"
            options: ["center", "top", "bottom", "left", "right"]
            labels: ({ center: "Middle", top: "Top", bottom: "Bottom", left: "Left", right: "Right" })
            value: pane.showcase.position || "center"
            onPicked: v => pane.setShowcase("position", v)
        }
        Stepper {
            theme: pane.theme; font: pane.font
            label: "Size"; suffix: "%"
            from: 60; to: 140; step: 10
            value: Number(pane.showcase.size) || 100
            onStepped: v => pane.setShowcase("size", v)
        }
        ChoiceRow {
            theme: pane.theme; font: pane.font
            label: "Shape"
            options: ["bar"].concat(Ends.list.map(e => e.key))
            labels: {
                const out = { bar: "Same as the bar" };
                for (const e of Ends.list) out[e.key] = e.label;
                return out;
            }
            value: pane.showcase.shape || "bar"
            onPicked: v => pane.setShowcase("shape", v)
        }
        Repeater {
            model: [
                ["palette", "Theme colours on the large card"],
                ["backgrounds", "The theme's backgrounds in a second row, to pick one with it"],
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

        SectionHeader {
            theme: pane.theme; font: pane.font
            text: "Browsing"
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
