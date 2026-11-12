// Six layout buttons, each a small drawing of the layout itself.
// Ctrl+1..6 picks one, Ctrl+L cycles.
import QtQuick

Row {
    id: picker
    property var theme
    property string font: "JetBrainsMono Nerd Font"
    property string current: "grid"
    property string hoveredName: ""
    signal chosen(string name)

    readonly property var layouts: [
        { key: "grid", name: "Grid" },
        { key: "carousel", name: "Carousel" },
        { key: "filmstrip", name: "Filmstrip" },
        { key: "radial", name: "Radial" },
        { key: "list", name: "List" },
        { key: "spotlight", name: "Spotlight" }
    ]

    spacing: 4

    Repeater {
        model: picker.layouts
        delegate: Rectangle {
            id: btn
            required property var modelData
            required property int index
            readonly property bool on: picker.current === modelData.key
            readonly property color ink: on ? picker.theme.bgBase : picker.theme.textSecondary

            width: 40; height: 28; radius: 7
            color: on ? picker.theme.accentPrimary : (area.containsMouse ? picker.theme.bgHover : picker.theme.bgSurface)
            border.color: on ? picker.theme.accentPrimary : picker.theme.bgBorder
            Behavior on color { ColorAnimation { duration: 120 } }

            Item {
                id: art
                anchors.centerIn: parent
                width: 26; height: 16

                // grid
                Grid {
                    visible: btn.modelData.key === "grid"
                    columns: 3; spacing: 2
                    Repeater { model: 6; Rectangle { width: 7.3; height: 7; radius: 1.5; color: btn.ink } }
                }
                // carousel
                Item {
                    visible: btn.modelData.key === "carousel"
                    anchors.fill: parent
                    Rectangle { x: 0; y: 4; width: 6; height: 8; radius: 1.5; color: btn.ink; opacity: 0.55 }
                    Rectangle { x: 7; y: 1; width: 12; height: 14; radius: 2; color: btn.ink }
                    Rectangle { x: 20; y: 4; width: 6; height: 8; radius: 1.5; color: btn.ink; opacity: 0.55 }
                }
                // filmstrip
                Item {
                    visible: btn.modelData.key === "filmstrip"
                    anchors.fill: parent
                    Rectangle { x: 0; y: 0; width: 26; height: 10; radius: 2; color: btn.ink }
                    Row {
                        y: 12; spacing: 2
                        Repeater { model: 4; Rectangle { width: 5; height: 4; radius: 1; color: btn.ink; opacity: 0.7 } }
                    }
                }
                // radial
                Item {
                    visible: btn.modelData.key === "radial"
                    anchors.fill: parent
                    Rectangle { anchors.centerIn: parent; width: 7; height: 7; radius: 3.5; color: btn.ink }
                    Repeater {
                        model: 8
                        Rectangle {
                            required property int index
                            width: 3.2; height: 3.2; radius: 1.6; color: btn.ink
                            x: art.width / 2 - 1.6 + Math.cos(index / 8 * 2 * Math.PI) * 7.5
                            y: art.height / 2 - 1.6 + Math.sin(index / 8 * 2 * Math.PI) * 7.5
                        }
                    }
                }
                // list
                Item {
                    visible: btn.modelData.key === "list"
                    anchors.fill: parent
                    Column {
                        spacing: 2
                        Repeater { model: 4; Rectangle { width: 9; height: 2.5; radius: 1; color: btn.ink } }
                    }
                    Rectangle { x: 12; y: 0; width: 14; height: 16; radius: 2; color: btn.ink; opacity: 0.8 }
                }
                // spotlight
                Item {
                    visible: btn.modelData.key === "spotlight"
                    anchors.fill: parent
                    Rectangle { anchors.fill: parent; radius: 2; color: btn.ink; opacity: 0.55 }
                    Rectangle { x: 5; y: 11; width: 16; height: 3; radius: 1.5; color: btn.ink }
                }
            }

            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: picker.hoveredName = btn.modelData.name + "  ·  Ctrl+" + (btn.index + 1)
                onExited: picker.hoveredName = ""
                onClicked: picker.chosen(btn.modelData.key)
            }
        }
    }
}
