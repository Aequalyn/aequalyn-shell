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
      model: [1, 2, 3, 4, 5, 6, 7, 8, 9, 0]
      Rectangle {
        id: wsPill
        required property int modelData
        readonly property int wsId: modelData
        readonly property var ws: {
          const list = Hyprland.workspaces.values || Hyprland.workspaces;
          for (let i = 0; i < list.length; i++) if (list[i].id === wsId) return list[i];
          return null;
        }
        property bool urgentBlink: false
        readonly property bool focused: ws !== null && ws.focused
        readonly property bool urgent: ws !== null && ws.urgent
        width: focused ? 32 : 24
        height: 24
        radius: 12
        color: focused ? bar.theme.accentPrimary :
               urgent && urgentBlink ? bar.theme.accentRed : bar.chipColor
        Behavior on color { ColorAnimation { duration: 150 } }
        SequentialAnimation {
          loops: Animation.Infinite
          running: urgent && !focused
          PropertyAction { target: wsPill; property: "urgentBlink"; value: true }
          PauseAnimation { duration: 500 }
          PropertyAction { target: wsPill; property: "urgentBlink"; value: false }
          PauseAnimation { duration: 500 }
          onStopped: wsPill.urgentBlink = false
        }
        Text {
          anchors.centerIn: parent
          text: wsPill.wsId === 0 ? "10" : String(wsPill.wsId)
          color: focused ? bar.theme.bgBase : bar.theme.textPrimary
          font.pixelSize: 11
          font.family: bar.font
          font.bold: focused
        }
        MouseArea {
          anchors.fill: parent
          onClicked: {
            if (wsPill.ws) wsPill.ws.activate();
            else Hyprland.dispatch("workspace " + wsPill.wsId);
          }
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
