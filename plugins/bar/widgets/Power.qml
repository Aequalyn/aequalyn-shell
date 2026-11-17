import QtQuick
import Quickshell
import QtQuick.Controls

// Power: a click opens the power menu; the click you choose (Bar page, a right click
// unless you change it), its quick panel. Not on the bar while the power menu is off.

Rectangle {
  // the bar this widget sits in: theme, font, shared state and actions (Bar.qml)
  required property var bar
  id: powerButton
  objectName: "aequalyn-power-button"
  Accessible.role: Accessible.Button
  Accessible.name: "Power menu"
  height: 24
  width: 26
  radius: 12
  color: powerHover.containsMouse || quick.visible ? bar.theme.bgSelected : bar.chipColor
  Text {
    anchors.centerIn: parent
    text: "󰐥"
    color: powerHover.containsMouse ? bar.theme.accentRed : bar.theme.textPrimary
    font.pixelSize: 14
    font.family: bar.font
  }
  MouseArea {
    id: powerHover
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    onClicked: (mouse) => {
      const role = powerButton.bar.clickRole("power", mouse.button);
      if (role === "quick") powerButton.toggleQuick();
      else if (role === "main") powerButton.bar.openPowerMenu();
    }
  }

  // its quick panel (PowerQuick.qml), on the click you chose (Bar page)
  function toggleQuick() {
    const w = powerButton.QsWindow.window;
    powerButton.bar.toggleWidgetPopup("power", w ? w.screen : null);
  }
  PowerQuick {
    id: quick
    bar: powerButton.bar
    anchorItem: powerButton
    open: powerButton.bar.widgetPopup === "power" && !!powerButton.QsWindow.window
          && powerButton.QsWindow.window.screen === powerButton.bar.popupScreen
    onDismissed: powerButton.bar.widgetPopup = ""
  }
}
