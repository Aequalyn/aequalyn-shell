import QtQuick
import Quickshell
import QtQuick.Controls

Rectangle {
  // the bar this widget sits in: theme, font, shared state and actions (Bar.qml)
  required property var bar
  // the colour the bar gives it (Bar page: the widgets' colours), transparent for its own
  property color ink: "transparent"
  id: shotButton
  objectName: "aequalyn-screenshot-button"
  Accessible.role: Accessible.Button
  Accessible.name: "Take region screenshot"
  height: 24
  width: 26
  radius: 12
  color: shotHover.containsMouse || quick.visible ? bar.theme.bgSelected : bar.chipColor
  Text {
    anchors.centerIn: parent
    text: "󰹑"
    color: bar.inked(ink, bar.theme.textPrimary)
    font.pixelSize: 14
    font.family: bar.font
  }
  MouseArea {
    id: shotHover
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    onClicked: (mouse) => {
      const role = shotButton.bar.clickRole("screenshot", mouse.button);
      if (role === "quick") shotButton.toggleQuick();
      else if (role === "main") shotButton.bar.takeScreenshot();
    }
  }

  // its quick panel (CaptureQuick.qml), on the click you chose (Bar page)
  function toggleQuick() {
    const w = shotButton.QsWindow.window;
    shotButton.bar.toggleWidgetPopup("capture-shot", w ? w.screen : null);
  }
  CaptureQuick {
    id: quick
    bar: shotButton.bar
    anchorItem: shotButton
    open: shotButton.bar.widgetPopup === "capture-shot" && !!shotButton.QsWindow.window
          && shotButton.QsWindow.window.screen === shotButton.bar.popupScreen
    onDismissed: shotButton.bar.widgetPopup = ""
  }
}
