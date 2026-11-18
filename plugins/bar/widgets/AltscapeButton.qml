import QtQuick
import Quickshell
import "root:/plugins/altscape"

// Altscape's button: the window switcher.
//   left click    the control center's Window switcher page (its layouts)
//   right click   its quick panel (AltscapeQuick.qml), or another click you choose
//                 (Bar page)
//   middle click  open the switcher
// Not on the bar while the Altscape plugin is turned off.
Rectangle {
  // the bar this widget sits in: theme, font, shared state and actions (Bar.qml)
  required property var bar
  // the colour the bar gives it (Bar page: the widgets' colours), transparent for its own
  property color ink: "transparent"
  id: altscapeButton
  objectName: "aequalyn-altscape-button"
  readonly property var svc: AltscapeHost.svc
  readonly property bool wanted: !!svc
  Accessible.role: Accessible.Button
  Accessible.name: "Window switcher"
  height: 24
  width: 26
  radius: 12
  color: altscapeArea.containsMouse || quick.visible ? bar.theme.bgSelected : bar.chipColor
  Text {
    anchors.centerIn: parent
    text: "\u{F05B1}"
    color: bar.inked(ink, bar.theme.accentPrimary)
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
      const role = altscapeButton.bar.clickRole("altscape", mouse.button);
      if (role === "quick") altscapeButton.toggleQuick();
      else if (role === "middle") s.openSwitcher("open");
      else AltscapeHost.openSettings(role === "right" ? "settings" : "visualisers");
    }
  }

  // its quick panel (AltscapeQuick.qml), on the click you chose (Bar page)
  function toggleQuick() {
    const w = altscapeButton.QsWindow.window;
    altscapeButton.bar.toggleWidgetPopup("altscape", w ? w.screen : null);
  }
  AltscapeQuick {
    id: quick
    bar: altscapeButton.bar
    anchorItem: altscapeButton
    open: altscapeButton.wanted && altscapeButton.bar.widgetPopup === "altscape" && !!altscapeButton.QsWindow.window
          && altscapeButton.QsWindow.window.screen === altscapeButton.bar.popupScreen
    onDismissed: altscapeButton.bar.widgetPopup = ""
  }
}
