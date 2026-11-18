import QtQuick
import Quickshell
import "root:/plugins/plume"
import "root:/style/Wheel.js" as Wheel

// Plume's button: a pointer, lit while its trails and halos are on.
//   left click    effects on / off            right click   its quick panel (PlumeQuick.qml)
//   middle click  find the pointer            scroll        the next or the previous ready made look
// The quick panel can take another click instead (Bar page); the Cursor page is in it.
// Not on the bar while the Plume plugin is turned off.
Rectangle {
  // the bar this widget sits in: theme, font, shared state and actions (Bar.qml)
  required property var bar
  // the colour the bar gives it (Bar page: the widgets' colours), transparent for its own
  property color ink: "transparent"
  id: plumeButton
  // the wheel does this widget's own thing, so its bar region doesn't slide under it
  readonly property bool usesWheel: true
  objectName: "aequalyn-plume-button"
  readonly property var svc: PlumeHost.svc
  readonly property bool wanted: !!svc
  readonly property bool on: !!svc && svc.cfg.enabled === true
  Accessible.role: Accessible.Button
  Accessible.name: on ? "Pointer effects on" : "Pointer effects off"
  height: 24
  width: 26
  radius: 12
  color: plumeArea.containsMouse || quick.visible ? bar.theme.bgSelected : bar.chipColor
  Text {
    anchors.centerIn: parent
    text: "\u{F01C0}"
    color: plumeButton.on ? bar.inked(ink, bar.theme.accentPrimary) : bar.theme.textMuted
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
      const role = plumeButton.bar.clickRole("plume", mouse.button);
      if (role === "quick") plumeButton.toggleQuick();
      else if (role === "right") PlumeHost.openSettings();
      else if (role === "middle") s.find();
      else s.setSetting("enabled", !plumeButton.on);
    }
    onWheel: (wheel) => {
      const s = Wheel.step(wheel, bar.wheelAcc);
      if (plumeButton.svc && s !== 0) plumeButton.svc.stepLook(-s);
    }
  }

  // its quick panel (PlumeQuick.qml), on the click you chose (Bar page)
  function toggleQuick() {
    const w = plumeButton.QsWindow.window;
    plumeButton.bar.toggleWidgetPopup("plume", w ? w.screen : null);
  }
  PlumeQuick {
    id: quick
    bar: plumeButton.bar
    anchorItem: plumeButton
    open: plumeButton.wanted && plumeButton.bar.widgetPopup === "plume" && !!plumeButton.QsWindow.window
          && plumeButton.QsWindow.window.screen === plumeButton.bar.popupScreen
    onDismissed: plumeButton.bar.widgetPopup = ""
  }
}
