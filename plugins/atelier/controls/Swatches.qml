// "Label   ● ● ● ●": a color out of a set of swatches.
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: sw
    property var theme
    property string font: "JetBrainsMono Nerd Font"
    property string label: ""
    property var colors: []
    property string value: ""
    signal picked(string value)

    Layout.fillWidth: true
    spacing: 10

    Text {
        text: sw.label
        color: sw.theme.textSecondary
        font.family: sw.font
        font.pixelSize: 11
        Layout.preferredWidth: 96
    }
    Flow {
        Layout.fillWidth: true
        spacing: 5
        Repeater {
            model: sw.colors
            delegate: Rectangle {
                required property string modelData
                readonly property bool on: sw.value.toLowerCase() === modelData.toLowerCase()
                width: 20; height: 20; radius: 10
                color: modelData
                border.width: on ? 2 : 1
                border.color: on ? sw.theme.accentPrimary : sw.theme.bgBorder
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: sw.picked(parent.modelData)
                }
            }
        }
    }
}
