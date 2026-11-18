import QtQuick
import Quickshell
import QtQuick.Layouts
import Quickshell.Io
import ".."

Rectangle {
  // the bar this widget sits in: theme, font, shared state and actions (Bar.qml)
  required property var bar
  // the colour the bar gives it (Bar page: the widgets' colours), transparent for its own
  property color ink: "transparent"
  id: battPill
  height: 24
  width: battContent.width + 12
  radius: 12
  color: quick.visible ? bar.theme.bgSelected : bar.chipColor
  readonly property color batteryColor: {
    if (SystemInfo.batteryCharging) return bar.inked(ink, bar.theme.accentGreen);
    if (SystemInfo.batteryLevelRaw > 20) return bar.inked(ink, bar.theme.batteryGood);
    if (SystemInfo.batteryLevelRaw > 10) return bar.theme.batteryWarning;
    return bar.theme.batteryCritical;
  }

  Row {
    id: battContent
    anchors.centerIn: parent
    spacing: 6
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: SystemInfo.batteryIcon
      color: parent.parent.batteryColor
      font.pixelSize: 14
      font.family: bar.font
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: SystemInfo.batteryLevel
      color: bar.theme.textPrimary
      font.pixelSize: 11
      font.family: bar.font
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    onClicked: (mouse) => {
      const role = battPill.bar.clickRole("battery", mouse.button);
      if (role === "quick") battPill.toggleQuick();
      else if (role !== "middle") battPill.bar.openPage("sleep");
    }
  }

  // its quick panel (BatteryQuick.qml), on the click you chose (Bar page)
  function toggleQuick() {
    const w = battPill.QsWindow.window;
    battPill.bar.toggleWidgetPopup("battery", w ? w.screen : null);
  }
  BatteryQuick {
    id: quick
    bar: battPill.bar
    anchorItem: battPill
    open: battPill.bar.widgetPopup === "battery" && !!battPill.QsWindow.window
          && battPill.QsWindow.window.screen === battPill.bar.popupScreen
    onDismissed: battPill.bar.widgetPopup = ""
  }
}
