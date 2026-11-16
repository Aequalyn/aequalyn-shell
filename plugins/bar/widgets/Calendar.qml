import QtQuick
import Quickshell

Item {
  required property var bar
  id: calendarButton
  implicitWidth: 28
  implicitHeight: 24
  property bool open: false

  Rectangle {
    anchors.fill: parent
    radius: 8
    color: calendarMouse.containsMouse || calendarButton.open ? bar.theme.bgSelected : bar.chipColor
    Text {
      anchors.centerIn: parent
      text: "\u{F0ED7}"
      color: bar.theme.accentPrimary
      font.family: bar.font
      font.pixelSize: 16
    }
    MouseArea {
      id: calendarMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: calendarButton.open = !calendarButton.open
    }
  }

  CalendarPopup {
    id: popup
    bar: calendarButton.bar
    anchorItem: calendarButton
    visible: calendarButton.open
    onVisibleChanged: if (!visible) calendarButton.open = false
    onDismissed: calendarButton.open = false
  }
}
