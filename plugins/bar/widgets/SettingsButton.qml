import QtQuick
import Quickshell
import QtQuick.Controls
import ".."
import "root:/plugins/bar/quick"

// The gear at the right of the bar: a left click opens the quick panel under it (Wi-Fi,
// Bluetooth, brightness, volume, what is playing...), a right click the whole control
// center (also Super + comma).
Rectangle {
  // the bar this widget sits in: theme, font, shared state and actions (Bar.qml)
  required property var bar
  // the colour the bar gives it (Bar page: the widgets' colours), transparent for its own
  property color ink: "transparent"
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
    color: bar.inked(ink, bar.theme.accentPrimary)
    font.pixelSize: 14
    font.family: bar.iconFont
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
        Quick.byKey = false;
        bar.quickPanelVisible = bar.togglePopup(bar.quickPanelVisible, w ? w.screen : null);
      }
    }
  }

  QuickPanel {
    id: quick
    bar: settingsButton.bar
    anchorItem: settingsButton
    open: settingsButton.bar.quickPanelVisible && !!settingsButton.QsWindow.window
             && settingsButton.QsWindow.window.screen === settingsButton.bar.popupScreen
  }
}
