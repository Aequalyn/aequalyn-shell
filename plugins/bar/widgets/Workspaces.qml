import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "root:/settings"

Item {
  required property var bar
  property var screen
  implicitWidth: wsRow.implicitWidth
  implicitHeight: 24
  Process { id: wsScrollProc; running: false }
  function labelFor(index) {
    const style = AequalynSettings.workspaceLabelStyle;
    if (style === "roman") {
      const ones = ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"];
      return ones[index] || String(index);
    }
    if (style === "japanese") return ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十"][index - 1] || String(index);
    if (style === "symbols") return ["●", "◆", "▲", "■", "★", "✦", "⬟", "⬢", "✿", "✚"][index - 1] || String(index);
    return String(index);
  }
  readonly property var visibleWorkspaces: {
    const m = Hyprland.workspaces;
    let list = [];
    try { list = Array.from(m.values || []); } catch (e) { console.log('ARRFROMERR', e); }
    const monName = (screen && screen.name) ? screen.name : ((bar && bar.screen && bar.screen.name) ? bar.screen.name : "");
    const out = [];
    const count = Math.max(1, Math.min(10, Number(AequalynSettings.workspaceCount) || 5));
    const slots = new Array(count);
    for (let i = 0; i < count; i++) {
      const id = i + 1;
      slots[i] = { id: id, active: false, focused: false, urgent: false, toplevels: { values: [] },
        activate: function() { Hyprland.dispatch('hl.dsp.focus({ workspace = "m~' + id + '" })'); } };
    }
    for (let i = 0; i < list.length; i++) {
      const w = list[i];
      if (!w) continue;
      const wm = (typeof w.monitor === "string") ? w.monitor : (w.monitor && w.monitor.name ? w.monitor.name : "");
      if (monName && wm && wm !== monName) continue;
      const id = Number(w.id);
      if (id >= 1 && id <= count) slots[id - 1] = w;
    }
    for (let i = 0; i < slots.length; i++) {
      const w = slots[i];
      const hasWins = (w.toplevels && w.toplevels.values && w.toplevels.values.length > 0) || w.active;
      if (AequalynSettings.workspaceShowEmpty || w.focused || w.urgent || hasWins) out.push(w);
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
        required property int index
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
          text: labelFor(Number(modelData.id))
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
