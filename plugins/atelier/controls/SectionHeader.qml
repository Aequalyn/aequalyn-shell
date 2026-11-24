// A short title with an optional explanation underneath, in the control center's words.
import QtQuick
import QtQuick.Layouts
import "root:/settings"

ColumnLayout {
    id: header
    property var theme
    property string font: AequalynSettings.monoFont
    property string text: ""
    property string sub: ""

    Layout.fillWidth: true
    Layout.topMargin: 10
    spacing: 3

    Text {
        text: header.text
        color: header.theme.textSecondary
        font.family: AequalynSettings.uiFont
        font.pixelSize: 14
        font.weight: Font.DemiBold
    }
    Text {
        visible: header.sub !== ""
        text: header.sub
        color: header.theme.textMuted
        font.family: AequalynSettings.uiFont
        font.pixelSize: 12
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }
}
