import QtQuick
import Quickshell
import QtQuick.Controls

Rectangle {
  // the bar this widget sits in: theme, font, shared state and actions (Bar.qml)
  required property var bar
  id: shotButton
  objectName: "aequalyn-screenshot-button"
  Accessible.role: Accessible.Button
  Accessible.name: "Take region screenshot"
  height: 24
  width: 26
  radius: 12
  color: shotHover.containsMouse ? bar.theme.bgSelected : bar.chipColor
  Text {
    anchors.centerIn: parent
    text: "󰹑"
    color: bar.theme.textPrimary
    font.pixelSize: 14
    font.family: bar.font
  }
  MouseArea {
    id: shotHover
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: bar.takeScreenshot()
  }
}
