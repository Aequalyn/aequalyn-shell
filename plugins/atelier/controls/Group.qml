// A titled card that holds a few related settings. Words are set in the sans the
// control center uses; icons stay in the shell's icon font (`font`).
import QtQuick
import QtQuick.Layouts
import "root:/settings"

Rectangle {
    id: group
    property var theme
    property string font: AequalynSettings.monoFont
    property string icon: ""
    property string title: ""
    property string sub: ""
    default property alias content: body.data

    Layout.fillWidth: true
    implicitHeight: col.implicitHeight + 32
    radius: 14
    color: theme.bgSurface

    ColumnLayout {
        id: col
        x: 16; y: 16
        width: parent.width - 32
        spacing: 12
        RowLayout {
            spacing: 10
            Layout.fillWidth: true
            Rectangle {
                visible: group.icon !== ""
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: 10
                color: group.theme.bgSelected
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
                    font.family: AequalynSettings.uiFont
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }
                Text {
                    visible: group.sub !== ""
                    text: group.sub
                    color: group.theme.textMuted
                    font.family: AequalynSettings.uiFont
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }
        }
        ColumnLayout {
            id: body
            Layout.fillWidth: true
            spacing: 10
        }
    }
}
