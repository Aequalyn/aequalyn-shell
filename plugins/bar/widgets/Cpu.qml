import QtQuick
import Quickshell
import ".."

Rectangle {
  // the bar this widget sits in: theme, font, shared state and actions (Bar.qml)
  required property var bar
  id: cpuWidget
  height: 24
  width: cpuContent.width + 12
  radius: 12
  color: area.containsMouse || quick.visible ? bar.theme.bgSelected : bar.chipColor
  Row {
    id: cpuContent
    anchors.centerIn: parent
    spacing: 6
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: "󰻠"
      color: bar.theme.accentOrange
      font.pixelSize: 14
      font.family: bar.font
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: SystemInfo.cpuUsage
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
      const role = cpuWidget.bar.clickRole("cpu", mouse.button);
      if (role === "quick") cpuWidget.toggleQuick();
      else if (role !== "middle") Quickshell.execDetached(["qs", "ipc", "call", "sysmon", "toggle"]);
    }
  }

  // its quick panel (SystemQuick.qml), on the click you chose (Bar page)
  function toggleQuick() {
    const w = cpuWidget.QsWindow.window;
    cpuWidget.bar.toggleWidgetPopup("system-cpu", w ? w.screen : null);
  }
  SystemQuick {
    id: quick
    bar: cpuWidget.bar
    anchorItem: cpuWidget
    open: cpuWidget.bar.widgetPopup === "system-cpu" && !!cpuWidget.QsWindow.window
          && cpuWidget.QsWindow.window.screen === cpuWidget.bar.popupScreen
    onDismissed: cpuWidget.bar.widgetPopup = ""
  }
}
