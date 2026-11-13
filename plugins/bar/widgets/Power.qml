import QtQuick
import Quickshell
import QtQuick.Controls

Rectangle {
  // the bar this widget sits in: theme, font, shared state and actions (Bar.qml)
  required property var bar
  id: powerButton
  objectName: "aequalyn-power-button"
  Accessible.role: Accessible.Button
  Accessible.name: "Power menu"
  height: 24
  width: 26
  radius: 12
  color: powerHover.containsMouse ? bar.theme.bgSelected : bar.chipColor
  Text {
    anchors.centerIn: parent
    text: "󰐥"
    color: powerHover.containsMouse ? bar.theme.accentRed : bar.theme.textPrimary
    font.pixelSize: 14
    font.family: bar.font
  }
  MouseArea {
    id: powerHover
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: bar.openPowerMenu()
  }
}
