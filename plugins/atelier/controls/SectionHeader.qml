// A short title with an optional explanation underneath, in the control center's words.
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: header
    property var theme
    property string font: "JetBrainsMono Nerd Font"
    property string text: ""
    property string sub: ""

    Layout.fillWidth: true
    Layout.topMargin: 10
    spacing: 3

    Text {
        text: header.text
        color: header.theme.textSecondary
        font.family: "sans-serif"
        font.pixelSize: 14
        font.weight: Font.DemiBold
    }
    Text {
        visible: header.sub !== ""
        text: header.sub
        color: header.theme.textMuted
        font.family: "sans-serif"
        font.pixelSize: 12
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }
}
