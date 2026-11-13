import QtQuick
import Quickshell

Rectangle {
  // the bar this widget sits in: theme, font, shared state and actions (Bar.qml)
  required property var bar
  height: 24
  width: brightContent.width + 12
  radius: 12
  color: bar.chipColor
  // no backlight: the bar hides the whole slot
  readonly property bool wanted: bar.hasBacklight
  visible: wanted
  Row {
    id: brightContent
    anchors.centerIn: parent
    spacing: 6
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: "󰃠"
      color: bar.theme.accentOrange
      font.pixelSize: 14
      font.family: bar.font
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: Math.round(bar.brightnessValue * 100) + "%"
      color: bar.theme.textPrimary
      font.pixelSize: 11
      font.family: bar.font
    }
  }
  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onWheel: (wheel) => {
      bar.stepBrightness(wheel.angleDelta.y > 0);
    }
  }
}
