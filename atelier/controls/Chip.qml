// A pill button; `selected` draws it in the accent colour.
import QtQuick

Rectangle {
    id: chip
    property var theme
    property string font: "JetBrainsMono Nerd Font"
    property string text: ""
    property string icon: ""
    property bool selected: false
    property bool compact: false
    signal clicked()

    implicitWidth: row.implicitWidth + (compact ? 16 : 22)
    implicitHeight: compact ? 24 : 30
    radius: height / 2
    color: selected ? theme.accentPrimary : (area.containsMouse ? theme.bgHover : theme.bgSurface)
    border.color: selected ? theme.accentPrimary : theme.bgBorder
    border.width: 1
    Behavior on color { ColorAnimation { duration: 120 } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Text {
            visible: chip.icon !== ""
            text: chip.icon
            color: chip.selected ? chip.theme.bgBase : chip.theme.textSecondary
            font.family: chip.font
            font.pixelSize: chip.compact ? 11 : 13
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: chip.text
            color: chip.selected ? chip.theme.bgBase : chip.theme.textPrimary
            font.family: chip.font
            font.pixelSize: chip.compact ? 10 : 12
            font.bold: chip.selected
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.clicked()
    }
}
