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
  readonly property var visibleWorkspaces: {
    const list = (Hyprland.workspaces && Hyprland.workspaces.values) ? Hyprland.workspaces.values : Hyprland.workspaces;
    const monName = (bar.screen && bar.screen.name) ? bar.screen.name : "";
    const out = [];
    for (let i = 0; i < list.length; i++) {
      const w = list[i];
      const wm = (typeof w.monitor === "string") ? w.monitor : (w.monitor && w.monitor.name ? w.monitor.name : "");
      if (monName && wm && wm !== monName) continue;
      if (w.focused || w.urgent || (w.windows && w.windows > 0)) out.push(w);
    }
    if (out.length === 0 && list.length > 0) {
      // fall back to the first workspace on this monitor, if any
      for (let i = 0; i < list.length; i++) {
        const w = list[i];
        const wm = (typeof w.monitor === "string") ? w.monitor : (w.monitor && w.monitor.name ? w.monitor.name : "");
        if (!monName || !wm || wm === monName) { out.push(w); break; }
      }
    }
    return out;
  }
  Row {
    id: wsRow
    anchors.fill: parent
    spacing: 4
    Repeater {
      model: visibleWorkspaces
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
