import QtQuick
import Quickshell
import QtQuick.Controls
import "root:/plugins/idleInhibitor"

Rectangle {
  // the bar this widget sits in: theme, font, shared state and actions (Bar.qml)
  required property var bar
  id: caffeineButton
  objectName: "aequalyn-caffeine-button"
  Accessible.role: Accessible.Button
  Accessible.name: CaffeineService.active ? "Caffeine on (idle inhibited)" : "Caffeine off"
  height: 24
  width: 26
  radius: 12
  color: caffeineHover.containsMouse ? bar.theme.bgSelected : bar.chipColor
  Text {
    anchors.centerIn: parent
    text: CaffeineService.active ? "" : "󰾪"
    color: CaffeineService.active ? bar.theme.accentOrange : bar.theme.textMuted
    font.pixelSize: 14
    font.family: bar.font
  }
  MouseArea {
    id: caffeineHover
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: CaffeineService.toggle()
  }
}
