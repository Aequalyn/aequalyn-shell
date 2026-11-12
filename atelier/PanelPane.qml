// Panel: how Atelier opens, how big it is, and what the two bar buttons do.
import QtQuick
import QtQuick.Layouts
import "controls"
import "root:/settings"

Flickable {
    id: pane
    property var host
    property var theme
    property string font: "JetBrainsMono Nerd Font"

    readonly property var cfg: AequalynSettings.atelierCfg
    function set(key, value) { AequalynSettings.setIn("atelier", key, value); }

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

        SectionHeader {
            theme: pane.theme; font: pane.font
            text: "Open as"
            sub: "What a bar button and the Atelier keys open. Pop out and Dock in the header switch between them at any time."
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Repeater {
                model: [
                    ["panel", "Panel", "Hangs off the bar, under its button"],
                    ["window", "Window", "A window of its own you can move and tile"],
                    ["overlay", "Full screen", "Over everything, with Spotlight full size"]
                ]
                delegate: Rectangle {
                    id: card
                    required property var modelData
                    readonly property bool on: (pane.cfg.openAs || "panel") === modelData[0]
                    readonly property color ink: on ? pane.theme.accentPrimary : pane.theme.textMuted
                    Layout.fillWidth: true
                    Layout.preferredHeight: 150
                    radius: 12
                    color: on ? pane.theme.bgSelected : (cardArea.containsMouse ? pane.theme.bgHover : pane.theme.bgSurface)
                    border.width: on ? 2 : 1
                    border.color: on ? pane.theme.accentPrimary : pane.theme.bgBorder

                    // a little screen showing where Atelier opens
                    Rectangle {
                        id: screen
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.topMargin: 12
                        width: 132; height: 74
                        radius: 6
                        color: pane.theme.bgBase
                        border.color: pane.theme.bgBorder
                        Rectangle {   // the bar
                            x: 3; y: 3; width: parent.width - 6; height: 7; radius: 2
                            color: Qt.rgba(card.ink.r, card.ink.g, card.ink.b, 0.25)
                            Rectangle { x: parent.width - 30; y: 1.5; width: 12; height: 4; radius: 2; color: card.ink }
                        }
                        Rectangle {   // where it opens
                            readonly property string mode: card.modelData[0]
                            x: mode === "panel" ? parent.width - 74 : mode === "window" ? 26 : 3
                            y: mode === "panel" ? 11 : mode === "window" ? 18 : 3
                            width: mode === "panel" ? 62 : mode === "window" ? 80 : parent.width - 6
                            height: mode === "panel" ? 46 : mode === "window" ? 46 : parent.height - 6
                            radius: 3
                            color: Qt.rgba(card.ink.r, card.ink.g, card.ink.b, 0.35)
                            border.color: card.ink
                        }
                    }
                    Text {
                        anchors.top: screen.bottom
                        anchors.topMargin: 10
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: card.modelData[1]
                        color: pane.theme.textPrimary
                        font.family: pane.font
                        font.pixelSize: 12
                        font.bold: card.on
                    }
                    Text {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 10
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        horizontalAlignment: Text.AlignHCenter
                        text: card.modelData[2]
                        color: pane.theme.textMuted
                        font.family: pane.font
                        font.pixelSize: 9
                        elide: Text.ElideRight
                    }
                    MouseArea {
                        id: cardArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pane.set("openAs", card.modelData[0])
                    }
                }
            }
        }

        SectionHeader {
            theme: pane.theme; font: pane.font
            text: "Size"
            sub: "The panel and the popped out window. Full screen always fits the screen."
        }
        RowLayout {
            spacing: 28
            Stepper {
                theme: pane.theme; font: pane.font
                label: "Width"; suffix: " px"; from: 760; to: 1800; step: 40
                value: pane.cfg.panelWidth || 1180
                onStepped: v => pane.set("panelWidth", v)
            }
            Stepper {
                theme: pane.theme; font: pane.font
                label: "Height"; suffix: " px"; from: 520; to: 1200; step: 40
                value: pane.cfg.panelHeight || 780
                onStepped: v => pane.set("panelHeight", v)
            }
        }

        // ---- the two bar buttons ------------------------------------------
        Repeater {
            model: [
                { key: "atelier", title: "Atelier button", icon: "󰉦", sub: "Opens Themes. Shows the active theme next to the icon." },
                { key: "layouts", title: "Layouts button", icon: "󰕰", sub: "Opens Layouts. Shows the focused workspace's layout next to the icon." }
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
                    sub: buttonCfg.modelData.sub + " Add, move or hide it in Settings → Top bar."
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

        SectionHeader {
            theme: pane.theme; font: pane.font
            text: "Browsing"
        }
        Toggle {
            theme: pane.theme; font: pane.font
            label: "Preview themes on the whole desktop"
            sublabel: "The bar, dock and every panel take the colours of the theme you are on, until you pick one or close Atelier."
            checked: pane.cfg.livePreview !== false
            onToggled: v => pane.set("livePreview", v)
        }
    }
}
