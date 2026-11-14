import QtQuick
import Quickshell
import QtQuick.Controls
import ".."

// The gear at the right of the bar: a left click opens the quick panel under it (Wi-Fi,
// Bluetooth, brightness, volume, what is playing...), a right click the whole control
// center (also Super + comma).
Rectangle {
  // the bar this widget sits in: theme, font, shared state and actions (Bar.qml)
  required property var bar
  id: settingsButton
  objectName: "aequalyn-settings-button"
  Accessible.role: Accessible.Button
  Accessible.name: "Quick settings"
  width: 28; height: 24
  radius: 8
  color: settingsHover.containsMouse || quick.visible ? bar.theme.bgSelected : bar.chipColor
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
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: (mouse) => {
      if (mouse.button === Qt.RightButton) {
        bar.quickPanelVisible = false;
        bar.openSettings();
      } else {
        const w = settingsButton.QsWindow.window;
        bar.quickPanelVisible = bar.togglePopup(bar.quickPanelVisible, w ? w.screen : null);
      }
    }
  }

  QuickPanel {
    id: quick
    bar: settingsButton.bar
    anchorItem: settingsButton
    visible: settingsButton.bar.quickPanelVisible && !!settingsButton.QsWindow.window
             && settingsButton.QsWindow.window.screen === settingsButton.bar.popupScreen
  }
}
