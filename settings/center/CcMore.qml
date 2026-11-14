// "More options": the settings most people never need, folded away.
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: m
    property string title: "More options"
    property bool open: false
    default property alias content: body.data

    Layout.fillWidth: true
    spacing: 10

    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Cc.theme.bgBorder }
    Item {
        Layout.fillWidth: true
        implicitHeight: 26
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Text {
                text: m.open ? "▾" : "▸"
                color: Cc.theme.textMuted
                font.family: Cc.mono
                font.pixelSize: 12
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: m.title
                color: area.containsMouse ? Cc.theme.textPrimary : Cc.theme.textSecondary
                font.family: Cc.sans
                font.pixelSize: 13
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: m.open = !m.open
        }
    }
    ColumnLayout {
        id: body
        visible: m.open
        Layout.fillWidth: true
        spacing: 8
    }
}
