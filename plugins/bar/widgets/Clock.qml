import QtQuick
import Quickshell
import "root:/settings"
import ".."

Rectangle {
  // the bar this widget sits in: theme, font, shared state and actions (Bar.qml)
  required property var bar
  id: clockWidget
  height: 24
  width: timeDate.width + 16
  radius: 12
  color: bar.chipColor
  property bool calendarVisible: false
  Row {
    id: timeDate
    anchors.centerIn: parent
    spacing: 8
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: Time.timeString
      color: bar.theme.textPrimary
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
      if (action === "calendar") clockWidget.calendarVisible = !clockWidget.calendarVisible;
      else if (action === "clock-settings") bar.openPage("clock");
    }
  }
  CalendarPopup {
    bar: clockWidget.bar
    anchorItem: clockWidget
    visible: clockWidget.calendarVisible
    onVisibleChanged: if (!visible) clockWidget.calendarVisible = false
    onDismissed: clockWidget.calendarVisible = false
  }
}
