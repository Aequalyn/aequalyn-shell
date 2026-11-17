import QtQuick
import Quickshell
import QtQuick.Controls
import "root:/plugins/idleInhibitor"

// Keep awake: a click turns it on or off; the click you choose (Bar page, a right click
// unless you change it), its quick panel. Not on the bar while its plugin is off.

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
  color: caffeineHover.containsMouse || quick.visible ? bar.theme.bgSelected : bar.chipColor
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
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    onClicked: (mouse) => {
      const role = caffeineButton.bar.clickRole("caffeine", mouse.button);
      if (role === "quick") caffeineButton.toggleQuick();
      else if (role === "main") CaffeineService.toggle();
    }
  }

  // its quick panel (CaffeineQuick.qml), on the click you chose (Bar page)
  function toggleQuick() {
    const w = caffeineButton.QsWindow.window;
    caffeineButton.bar.toggleWidgetPopup("caffeine", w ? w.screen : null);
  }
  CaffeineQuick {
    id: quick
    bar: caffeineButton.bar
    anchorItem: caffeineButton
    open: caffeineButton.bar.widgetPopup === "caffeine" && !!caffeineButton.QsWindow.window
          && caffeineButton.QsWindow.window.screen === caffeineButton.bar.popupScreen
    onDismissed: caffeineButton.bar.widgetPopup = ""
  }
}
