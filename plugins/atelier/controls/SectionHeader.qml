// Small caps title with an optional explanation underneath.
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: header
    property var theme
    property string font: "JetBrainsMono Nerd Font"
    property string text: ""
    property string sub: ""

    Layout.fillWidth: true
    Layout.topMargin: 6
    spacing: 3

    Text {
        text: header.text.toUpperCase()
        color: header.theme.textMuted
        font.family: header.font
        font.pixelSize: 10
        font.bold: true
        font.letterSpacing: 1.4
    }
    Text {
        visible: header.sub !== ""
        text: header.sub
        color: header.theme.textSecondary
        font.family: header.font
        font.pixelSize: 11
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }
}
