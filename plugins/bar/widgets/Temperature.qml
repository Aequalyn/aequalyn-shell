import QtQuick
import Quickshell
import ".."

Rectangle {
  // the bar this widget sits in: theme, font, shared state and actions (Bar.qml)
  required property var bar
  id: tempWidget
  height: 24
  width: tempContent.width + 12
  radius: 12
  color: area.containsMouse || quick.visible ? bar.theme.bgSelected : bar.chipColor
  Row {
    id: tempContent
    anchors.centerIn: parent
    spacing: 6
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: "󰔏"
      color: bar.theme.accentRed
      font.pixelSize: 14
      font.family: bar.font
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: SystemInfo.temperature
      color: bar.theme.textPrimary
      font.pixelSize: 11
      font.family: bar.font
    }
  }
  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    onClicked: (mouse) => {
      const role = tempWidget.bar.clickRole("temperature", mouse.button);
      if (role === "quick") tempWidget.toggleQuick();
      else if (role !== "middle") Quickshell.execDetached(["qs", "ipc", "call", "sysmon", "toggle"]);
    }
  }

  // its quick panel (SystemQuick.qml), on the click you chose (Bar page)
  function toggleQuick() {
    const w = tempWidget.QsWindow.window;
    tempWidget.bar.toggleWidgetPopup("system-temperature", w ? w.screen : null);
  }
  SystemQuick {
    id: quick
    bar: tempWidget.bar
    anchorItem: tempWidget
    open: tempWidget.bar.widgetPopup === "system-temperature" && !!tempWidget.QsWindow.window
          && tempWidget.QsWindow.window.screen === tempWidget.bar.popupScreen
    onDismissed: tempWidget.bar.widgetPopup = ""
  }
}
