import QtQuick
import Quickshell
import "root:/plugins/plume"

// Plume's button: a pointer, lit while its trails and halos are on.
//   left click    effects on / off            right click   the control center's Cursor page
//   middle click  find the pointer            scroll        the next or the previous ready made look
// Hidden while the Plume plugin is turned off.
Rectangle {
  // the bar this widget sits in: theme, font, shared state and actions (Bar.qml)
  required property var bar
  id: plumeButton
  objectName: "aequalyn-plume-button"
  readonly property var svc: PlumeHost.svc
  readonly property bool wanted: !!svc
  readonly property bool on: !!svc && svc.cfg.enabled === true
  Accessible.role: Accessible.Button
  Accessible.name: on ? "Pointer effects on" : "Pointer effects off"
  height: 24
  width: 26
  radius: 12
  color: plumeArea.containsMouse ? bar.theme.bgSelected : bar.chipColor
  Text {
    anchors.centerIn: parent
    text: "\u{F01C0}"
    color: plumeButton.on ? bar.theme.accentPrimary : bar.theme.textMuted
    font.pixelSize: 14
    font.family: bar.font
  }
  MouseArea {
    id: plumeArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    onClicked: (mouse) => {
      const s = plumeButton.svc;
      if (!s) return;
      if (mouse.button === Qt.RightButton) PlumeHost.openSettings();
      else if (mouse.button === Qt.MiddleButton) s.find();
      else s.setSetting("enabled", !plumeButton.on);
    }
    onWheel: (wheel) => {
      if (plumeButton.svc && wheel.angleDelta.y !== 0) plumeButton.svc.stepLook(wheel.angleDelta.y < 0 ? 1 : -1);
    }
  }
}
