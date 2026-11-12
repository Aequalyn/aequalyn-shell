// A titled card that holds a few related settings, Atelier's way of grouping.
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: group
    property var theme
    property string font: "JetBrainsMono Nerd Font"
    property string icon: ""
    property string title: ""
    property string sub: ""
    default property alias content: body.data

    Layout.fillWidth: true
    implicitHeight: col.implicitHeight + 28
    radius: 12
    color: Qt.rgba(theme.textPrimary.r, theme.textPrimary.g, theme.textPrimary.b, 0.03)
    border.color: theme.bgBorder

    ColumnLayout {
        id: col
        x: 14; y: 14
        width: parent.width - 28
        spacing: 10
        RowLayout {
            spacing: 10
            Layout.fillWidth: true
            Rectangle {
                visible: group.icon !== ""
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                radius: 9
                color: group.theme.bgBase
                Text {
                    anchors.centerIn: parent
                    text: group.icon
                    color: group.theme.accentPrimary
                    font.family: group.font
                    font.pixelSize: 15
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    text: group.title
                    color: group.theme.textPrimary
                    font.family: group.font
                    font.pixelSize: 13
                    font.bold: true
                }
                Text {
                    visible: group.sub !== ""
                    text: group.sub
                    color: group.theme.textMuted
                    font.family: group.font
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }
        }
        ColumnLayout {
            id: body
            Layout.fillWidth: true
            spacing: 8
        }
    }
}
