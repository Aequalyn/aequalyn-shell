// A small heading over a group in a quick panel ("Players", "Start").
import QtQuick
import QtQuick.Layouts
import Quickshell

Text {
    Layout.fillWidth: true
    Layout.topMargin: 2
    Layout.bottomMargin: -4
    color: Quick.theme.textMuted
    font.family: Quick.sans
    font.pixelSize: 10
    font.weight: Font.DemiBold
    font.letterSpacing: 1.1
    font.capitalization: Font.AllUppercase
}
