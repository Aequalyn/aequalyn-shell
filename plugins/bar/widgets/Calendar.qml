import QtQuick
import Quickshell

Item {
  required property var bar
  // the colour the bar gives it (Bar page: the widgets' colours), transparent for its own
  property color ink: "transparent"
  id: calendarButton
  implicitWidth: 28
  implicitHeight: 24

  Rectangle {
    anchors.fill: parent
    radius: 8
    color: calendarMouse.containsMouse || quick.visible ? bar.theme.bgSelected : bar.chipColor
    Text {
      anchors.centerIn: parent
      text: "\u{F0ED7}"
      color: bar.inked(ink, bar.theme.accentPrimary)
      font.family: bar.font
      font.pixelSize: 16
    }
    MouseArea {
      id: calendarMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      onClicked: (mouse) => {
        const role = calendarButton.bar.clickRole("calendar", mouse.button);
        if (role === "quick") calendarButton.toggleQuick();
        else if (role !== "middle") calendarButton.bar.openPage("clock");
      }
    }
  }

  // its quick panel (CalendarQuick.qml), on the click you chose (Bar page)
  function toggleQuick() {
    const w = calendarButton.QsWindow.window;
    calendarButton.bar.toggleWidgetPopup("calendar", w ? w.screen : null);
  }
  CalendarQuick {
    id: quick
    bar: calendarButton.bar
    anchorItem: calendarButton
    open: calendarButton.bar.widgetPopup === "calendar" && !!calendarButton.QsWindow.window
          && calendarButton.QsWindow.window.screen === calendarButton.bar.popupScreen
    onDismissed: calendarButton.bar.widgetPopup = ""
  }
}
