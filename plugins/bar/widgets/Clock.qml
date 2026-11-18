import QtQuick
import Quickshell
import "root:/settings"
import ".."

Rectangle {
  // the bar this widget sits in: theme, font, shared state and actions (Bar.qml)
  required property var bar
  // the colour the bar gives it (Bar page: the widgets' colours), transparent for its own
  property color ink: "transparent"
  id: clockWidget
  height: 24
  width: timeDate.width + 16
  radius: 12
  color: quick.visible ? bar.theme.bgSelected : bar.chipColor
  Row {
    id: timeDate
    anchors.centerIn: parent
    spacing: 8
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: Time.timeString
      color: bar.inked(ink, bar.theme.textPrimary)
      font.pixelSize: 12
      font.family: bar.font
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: Time.dateString
      visible: AequalynSettings.showBarDate
      color: bar.theme.textSecondary
      font.pixelSize: 12
      font.family: bar.font
    }
  }
  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onClicked: mouse => {
      const action = mouse.button === Qt.RightButton
        ? AequalynSettings.clockRightClick : AequalynSettings.clockLeftClick;
      if (action === "calendar") clockWidget.toggleQuick();
      else if (action === "clock-settings") bar.openPage("clock");
    }
  }

  // its quick panel (CalendarQuick.qml), on the click you chose (Bar page)
  function toggleQuick() {
    const w = clockWidget.QsWindow.window;
    clockWidget.bar.toggleWidgetPopup("clock", w ? w.screen : null);
  }
  CalendarQuick {
    id: quick
    bar: clockWidget.bar
    anchorItem: clockWidget
    open: clockWidget.bar.widgetPopup === "clock" && !!clockWidget.QsWindow.window
          && clockWidget.QsWindow.window.screen === clockWidget.bar.popupScreen
    onDismissed: clockWidget.bar.widgetPopup = ""
  }
}
