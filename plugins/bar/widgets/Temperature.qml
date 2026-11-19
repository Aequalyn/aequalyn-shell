import QtQuick
import Quickshell
import ".."

Rectangle {
  // the bar this widget sits in: theme, font, shared state and actions (Bar.qml)
  required property var bar
  // the colour the bar gives it (Bar page: the widgets' colours), transparent for its own
  property color ink: "transparent"
  id: tempWidget
  // icon and value side by side; stacked, narrower, on a side bar
  height: bar.vertical ? tempContent.height + 10 : 24
  width: bar.vertical ? bar.chipAcross : tempContent.width + 12
  radius: 12
  color: area.containsMouse || quick.visible ? bar.theme.bgSelected : bar.chipColor
  Grid {
    id: tempContent
    anchors.centerIn: parent
    columns: bar.vertical ? 1 : 99
    columnSpacing: 6
    rowSpacing: 1
    horizontalItemAlignment: Grid.AlignHCenter
    verticalItemAlignment: Grid.AlignVCenter
    Text {
      text: "󰔏"
      color: bar.inked(ink, bar.theme.accentRed)
      font.pixelSize: 14
      font.family: bar.font
    }
    Text {
      readonly property string full: SystemInfo.temperature
      color: bar.theme.textPrimary
      font.pixelSize: bar.vertical ? 9 : 11
      font.family: bar.font
      // on a side bar: shorter (no %%, no decimals), centred under the icon
      text: bar.vertical ? bar.compact(full) : full
      horizontalAlignment: Text.AlignHCenter
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
