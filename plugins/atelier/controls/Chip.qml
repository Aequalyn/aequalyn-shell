// A choice button, drawn like the control center's: a soft fill, and the accent
// outline when `selected`. Words in sans, the icon in the icon font.
import QtQuick
import "root:/settings"

Rectangle {
    id: chip
    property var theme
    property string font: AequalynSettings.monoFont
    property string text: ""
    property string icon: ""
    property bool selected: false
    property bool compact: false
    signal clicked()

    implicitWidth: row.implicitWidth + (compact ? 22 : 28)
    implicitHeight: compact ? 30 : 34
    radius: 10
    color: !theme ? "transparent"
         : selected ? Qt.rgba(theme.accentPrimary.r, theme.accentPrimary.g, theme.accentPrimary.b, 0.16)
         : Qt.rgba(theme.textPrimary.r, theme.textPrimary.g, theme.textPrimary.b, area.containsMouse ? 0.11 : 0.06)
    border.color: theme && selected ? theme.accentPrimary : "transparent"
    border.width: 2
    Behavior on color { ColorAnimation { duration: 120 } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Text {
            visible: chip.icon !== ""
            text: chip.icon
            color: chip.theme ? (chip.selected ? chip.theme.accentPrimary : chip.theme.textSecondary) : "white"
            font.family: chip.font
            font.pixelSize: 13
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: chip.text
            color: chip.theme ? (chip.selected ? chip.theme.textPrimary : chip.theme.textSecondary) : "white"
            font.family: AequalynSettings.uiFont
            font.pixelSize: 12
            font.weight: chip.selected ? Font.DemiBold : Font.Normal
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
