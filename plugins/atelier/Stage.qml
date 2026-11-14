// The desktop in miniature: the bar and every dock together, as they are
// right now (or as an ensemble would make them). Shared by the Bar and Docks
// tabs, so you always see the two side by side.
import QtQuick

Item {
    id: stage
    property var theme
    property string font: "JetBrainsMono Nerd Font"
    property var barLook
    property int barSize: 22
    // [{ look, pal, edge, icons }]
    property var docks: []
    property int dockSize: 22
    property int marked: -1         // a dock to point out
    property string caption: ""

    // the wallpaper to show (empty: the theme's colours)
    property string wallpaper: ""

    Desk { anchors.fill: parent; theme: stage.theme; radius: 12; source: stage.wallpaper }

    // two windows, tiled
    Repeater {
        model: [[0.05, 0.27, 0.52, 0.5], [0.59, 0.27, 0.36, 0.5]]
        delegate: Rectangle {
            required property var modelData
            x: modelData[0] * stage.width; y: modelData[1] * stage.height
            width: modelData[2] * stage.width; height: modelData[3] * stage.height
            radius: 6
            color: Qt.rgba(stage.theme.bgBase.r, stage.theme.bgBase.g, stage.theme.bgBase.b, 0.55)
            border.color: Qt.rgba(stage.theme.textPrimary.r, stage.theme.textPrimary.g, stage.theme.textPrimary.b, 0.08)
        }
    }

    BarMini {
        x: 8; y: 6
        width: parent.width - 16
        theme: stage.theme
        look: stage.barLook
        barSize: stage.barSize
    }

    Repeater {
        model: stage.docks
        delegate: Item {
            id: slot
            required property var modelData
            required property int index
            readonly property string edge: modelData.edge || "bottom"
            readonly property bool hz: edge === "top" || edge === "bottom"
            readonly property var mates: stage.docks.filter(d => (d.edge || "bottom") === edge)
            readonly property int pos: stage.docks.slice(0, index).filter(d => (d.edge || "bottom") === edge).length
            readonly property real span: hz ? stage.width : stage.height - 70
            readonly property real mid: (pos + 0.5) * span / mates.length

            DockMini {
                id: dm
                look: slot.modelData.look
                pal: slot.modelData.pal
                size: stage.dockSize
                icons: slot.modelData.icons || 4
                rotation: slot.hz ? 0 : (slot.edge === "left" ? 90 : -90)
                readonly property real cx: slot.hz ? slot.mid : (slot.edge === "left" ? 4 + height / 2 : stage.width - 4 - height / 2)
                readonly property real cy: slot.hz ? (slot.edge === "bottom" ? stage.height - 4 - height / 2 : 40 + height / 2) : 52 + slot.mid
                x: cx - width / 2
                y: cy - height / 2
            }
            Rectangle {   // the dock being edited: a number beside it, on the windows' side
                visible: stage.marked === slot.index
                x: slot.hz ? dm.cx - width / 2
                   : slot.edge === "left" ? dm.cx + dm.height / 2 + 6 : dm.cx - dm.height / 2 - width - 6
                y: !slot.hz ? dm.cy - height / 2
                   : slot.edge === "bottom" ? dm.cy - dm.height / 2 - height - 6 : dm.cy + dm.height / 2 + 6
                width: 22; height: 16; radius: 8
                color: stage.theme.accentPrimary
                Text {
                    anchors.centerIn: parent
                    text: slot.index + 1
                    color: stage.theme.bgBase
                    font.family: stage.font
                    font.pixelSize: 10
                    font.bold: true
                }
            }
        }
    }

    Text {
        visible: stage.caption !== ""
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: stage.barSize + 20
        text: stage.caption
        color: "white"
        opacity: 0.85
        font.family: stage.font
        font.pixelSize: 11
    }
}
