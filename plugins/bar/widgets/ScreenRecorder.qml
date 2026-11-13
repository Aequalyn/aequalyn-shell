import QtQuick
import Quickshell
import QtQuick.Controls

Rectangle {
  // the bar this widget sits in: theme, font, shared state and actions (Bar.qml)
  required property var bar
  id: recButton
  objectName: "aequalyn-screenrecorder-button"
  Accessible.role: Accessible.Button
  Accessible.name: bar.recordingActive ? "Stop recording" : "Start recording"
  height: 24
  width: 26
  radius: 12
  color: bar.recordingActive ? bar.theme.accentRed
       : (recHover.containsMouse ? bar.theme.bgSelected : bar.chipColor)
  Text {
    anchors.centerIn: parent
    text: bar.recordingActive ? "󰑊" : "󰻂"
    color: bar.recordingActive ? bar.theme.bgBase : bar.theme.textPrimary
    font.pixelSize: 14
    font.family: bar.font
  }
  Rectangle {
    visible: bar.recordingActive
    anchors.centerIn: parent
    width: 20; height: 20; radius: 10
    color: "transparent"
    border.color: bar.theme.bgBase
    border.width: 0
  }
  MouseArea {
    id: recHover
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: bar.toggleRecording()
  }
}
