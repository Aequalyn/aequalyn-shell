import QtQuick
import Quickshell
import "root:/plugins/altscape"

// Altscape's button: the window switcher.
//   left click    the control center's Window switcher page (its layouts)
//   right click   the same page, on Settings
//   middle click  open the switcher
// Hidden while the Altscape plugin is turned off.
Rectangle {
  // the bar this widget sits in: theme, font, shared state and actions (Bar.qml)
  required property var bar
  id: altscapeButton
  objectName: "aequalyn-altscape-button"
  readonly property var svc: AltscapeHost.svc
  readonly property bool wanted: !!svc
  Accessible.role: Accessible.Button
  Accessible.name: "Window switcher"
  height: 24
  width: 26
  radius: 12
  color: altscapeArea.containsMouse ? bar.theme.bgSelected : bar.chipColor
  Text {
    anchors.centerIn: parent
    text: "\u{F05B1}"
    color: bar.theme.accentPrimary
    font.pixelSize: 14
    font.family: bar.font
  }
  MouseArea {
    id: altscapeArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    onClicked: (mouse) => {
      const s = altscapeButton.svc;
      if (!s) return;
      if (mouse.button === Qt.MiddleButton) s.openSwitcher("open");
      else AltscapeHost.openSettings(mouse.button === Qt.RightButton ? "settings" : "visualisers");
    }
  }
}
