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
  // on a side bar: hours over minutes, without the date
  height: bar.vertical ? timeDate.height + 10 : 24
  width: bar.vertical ? bar.chipAcross : timeDate.width + 16
  radius: 12
  color: quick.visible ? bar.theme.bgSelected : bar.chipColor
  Grid {
    id: timeDate
    anchors.centerIn: parent
    columns: bar.vertical ? 1 : 99
    columnSpacing: 8
    verticalItemAlignment: Grid.AlignVCenter
    horizontalItemAlignment: Grid.AlignHCenter
    Text {
      text: bar.vertical ? Time.timeString.replace(/[: ]+/g, "\n") : Time.timeString
      horizontalAlignment: Text.AlignHCenter
      lineHeight: bar.vertical ? 0.9 : 1
      color: bar.inked(ink, bar.theme.textPrimary)
      font.pixelSize: 12
      font.family: bar.iconFont
    }
    Text {
      text: Time.dateString
      visible: AequalynSettings.showBarDate && !bar.vertical
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
