// A small line over a group in a quick panel ("Players", "Start"), as the Applications
// menu says how many there are.
import QtQuick
import QtQuick.Layouts
import Quickshell

Text {
    Layout.fillWidth: true
    Layout.topMargin: 2
    Layout.bottomMargin: -4
    color: Quick.theme.textMuted
    font.family: Quick.sans
    font.pixelSize: 11
}
