// "More options": the settings most people never need, folded away behind a
// hairline and small fold header.
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: m
    property string title: "More options"
    property bool open: false
    // the search opens a fold to show a setting inside it (CcPage.reveal)
    readonly property bool ccMore: true
    default property alias content: body.data

    Layout.fillWidth: true
    spacing: 8

    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Cc.alpha(Cc.theme.textPrimary, 0.07) }
    Item {
        Layout.fillWidth: true
        implicitHeight: 24
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Text {
                text: m.open ? "▾" : "▸"
                color: Cc.theme.textMuted
                font.family: Cc.mono
                font.pixelSize: 10
                opacity: 0.7
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: m.title
                color: area.containsMouse ? Cc.theme.textPrimary : Cc.theme.textSecondary
                font.family: Cc.sans
                font.pixelSize: 11
                opacity: 0.75
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
        spacing: 6
    }
}
