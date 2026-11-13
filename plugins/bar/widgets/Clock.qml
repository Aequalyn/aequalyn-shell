import QtQuick
import Quickshell
import ".."

Rectangle {
  // the bar this widget sits in: theme, font, shared state and actions (Bar.qml)
  required property var bar
  height: 24
  width: timeDate.width + 16
  radius: 12
  color: bar.chipColor
  Row {
    id: timeDate
    anchors.centerIn: parent
    spacing: 8
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: Time.timeString
      color: bar.theme.textPrimary
      font.pixelSize: 12
      font.family: bar.font
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: Time.dateString
      color: bar.theme.textSecondary
      font.pixelSize: 12
      font.family: bar.font
    }
  }
}
