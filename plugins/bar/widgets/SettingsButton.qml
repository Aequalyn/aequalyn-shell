import QtQuick
import Quickshell
import QtQuick.Controls

// Fixed right button: opens Aequalyn settings (SUPER+,).
Rectangle {
  // the bar this widget sits in: theme, font, shared state and actions (Bar.qml)
  required property var bar
  id: settingsButton
  objectName: "aequalyn-settings-button"
  Accessible.role: Accessible.Button
  Accessible.name: "Aequalyn settings"
  width: 28; height: 24
  radius: 8
  color: settingsHover.containsMouse ? bar.theme.bgSelected : bar.chipColor
  Text {
    anchors.centerIn: parent
    text: "⚙"
    color: bar.theme.accentPrimary
    font.pixelSize: 14
    font.family: bar.font
  }
  MouseArea {
    id: settingsHover
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: bar.openSettings()
  }
}
