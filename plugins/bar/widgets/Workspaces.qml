import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Item {
  // the bar this widget sits in: theme, font, shared state and actions (Bar.qml)
  required property var bar
  implicitWidth: wsRow.implicitWidth
  implicitHeight: 24
  Process { id: wsScrollProc; running: false }
  Row {
    id: wsRow
    anchors.fill: parent
    spacing: 4
    Repeater {
      model: Hyprland.workspaces
      Rectangle {
        id: wsPill
        required property var modelData
        property bool urgentBlink: false
        width: modelData.focused ? 32 : 24
        height: 24
        radius: 12
        color: modelData.focused ? bar.theme.accentPrimary :
               modelData.urgent && urgentBlink ? bar.theme.accentRed : bar.chipColor
        Behavior on color { ColorAnimation { duration: 150 } }
        SequentialAnimation {
          loops: Animation.Infinite
          running: wsPill.modelData.urgent && !wsPill.modelData.focused
          PropertyAction { target: wsPill; property: "urgentBlink"; value: true }
          PauseAnimation { duration: 500 }
          PropertyAction { target: wsPill; property: "urgentBlink"; value: false }
          PauseAnimation { duration: 500 }
          onStopped: wsPill.urgentBlink = false
        }
        Text {
          anchors.centerIn: parent
          text: wsPill.modelData.id
          color: wsPill.modelData.focused ? bar.theme.bgBase : bar.theme.textPrimary
          font.pixelSize: 11
          font.family: bar.font
          font.bold: wsPill.modelData.focused
        }
        MouseArea {
          anchors.fill: parent
          onClicked: wsPill.modelData.activate()
          onWheel: (wheel) => {
            const dir = wheel.angleDelta.y > 0 ? "e-1" : "e+1";
            wsScrollProc.command = ["hyprctl", "dispatch",
              "hl.dsp.focus({ workspace = \"" + dir + "\" })"];
            wsScrollProc.running = true;
          }
        }
        Behavior on width { NumberAnimation { duration: 150 } }
      }
    }
  }
}
