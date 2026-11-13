import QtQuick
import Quickshell
import ".."

Rectangle {
  // the bar this widget sits in: theme, font, shared state and actions (Bar.qml)
  required property var bar
  height: 24
  width: tempContent.width + 12
  radius: 12
  color: bar.chipColor
  Row {
    id: tempContent
    anchors.centerIn: parent
    spacing: 6
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: "󰔏"
      color: bar.theme.accentRed
      font.pixelSize: 14
      font.family: bar.font
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: SystemInfo.temperature
      color: bar.theme.textPrimary
      font.pixelSize: 11
      font.family: bar.font
    }
  }
}
