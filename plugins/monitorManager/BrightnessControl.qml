// Brightness of a built-in screen (laptop panel), through brightnessctl: a slider, a few
// steps and the current percentage. It reads the level when it's shown and every second
// while it stays shown, so the brightness keys are reflected too. Never goes below 1%, so
// the screen can't be turned fully dark by accident.
import QtQuick
import QtQuick.Layouts
import Quickshell.Io

ColumnLayout {
  id: ctl
  property var theme
  property string font: "JetBrainsMono Nerd Font"

  property bool available: false     // a backlight brightnessctl can set
  property int percent: 0
  property bool dragging: false
  spacing: 8

  function read() { if (!readProc.running) readProc.running = true; }
  // a level asked for while the previous one is still being set waits, so only the
  // newest is set next and no step is lost
  property int pending: -1
  function set(p) {
    const v = Math.max(1, Math.min(100, Math.round(p)));
    ctl.percent = v;
    if (setProc.running) { ctl.pending = v; return; }
    setProc.command = ["brightnessctl", "-q", "set", v + "%"];
    setProc.running = true;
  }

  Process {
    id: readProc
    // machine output: device,class,current,percent,max
    command: ["brightnessctl", "-m", "-c", "backlight"]
    stdout: StdioCollector {
      onStreamFinished: {
        const f = text.trim().split("\n")[0].split(",");
        const p = parseInt(f.length >= 4 ? f[3] : "");
        ctl.available = !isNaN(p);
        if (ctl.available && !ctl.dragging && !setProc.running) ctl.percent = p;
      }
    }
  }
  Process {
    id: setProc
    onExited: {
      if (ctl.pending >= 0) { const v = ctl.pending; ctl.pending = -1; ctl.set(v); }
    }
  }
  Timer { interval: 1000; repeat: true; running: ctl.visible; triggeredOnStart: true; onTriggered: ctl.read() }

  RowLayout {
    Layout.fillWidth: true
    Text {
      Layout.fillWidth: true
      text: "Brightness"
      color: ctl.theme.textSecondary
      font { pixelSize: 11; family: ctl.font }
    }
    Text {
      text: ctl.available ? ctl.percent + "%" : ""
      color: ctl.theme.accentPrimary
      font { pixelSize: 11; bold: true; family: ctl.font }
    }
  }

  Text {
    visible: !ctl.available
    Layout.fillWidth: true
    wrapMode: Text.WordWrap
    text: "No backlight found for this screen."
    color: ctl.theme.textMuted
    font { pixelSize: 10; family: ctl.font }
  }

  // the slider: click or drag anywhere on it
  Item {
    visible: ctl.available
    Layout.fillWidth: true
    implicitHeight: 22
    Rectangle {
      id: track
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width; height: 6; radius: 3
      color: ctl.theme.bgSurface
      border.color: ctl.theme.bgBorder
      border.width: 1
      Rectangle {
        width: Math.max(height, parent.width * ctl.percent / 100)
        height: parent.height; radius: 3
        color: ctl.theme.accentPrimary
      }
    }
    Rectangle {
      width: 16; height: 16; radius: 8
      anchors.verticalCenter: parent.verticalCenter
      x: (parent.width - width) * ctl.percent / 100
      color: ctl.theme.textPrimary
      border.color: ctl.theme.accentPrimary
      border.width: 2
    }
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      function at(mx) { return mx / width * 100; }
      onPressed: mouse => { ctl.dragging = true; ctl.set(at(mouse.x)); }
      onPositionChanged: mouse => { if (pressed) ctl.set(at(mouse.x)); }
      onReleased: ctl.dragging = false
      onCanceled: ctl.dragging = false
      onWheel: wheel => ctl.set(ctl.percent + (wheel.angleDelta.y > 0 ? 5 : -5))
    }
  }

  // quick steps
  Flow {
    visible: ctl.available
    Layout.fillWidth: true
    spacing: 4
    Repeater {
      model: [10, 25, 50, 75, 100]
      Rectangle {
        required property int modelData
        readonly property bool on: ctl.percent === modelData
        width: 44; height: 26; radius: 6
        color: on ? ctl.theme.accentPrimary : ctl.theme.bgSurface
        border.color: ctl.theme.bgBorder
        border.width: 1
        Text {
          anchors.centerIn: parent
          text: modelData + "%"
          color: parent.on ? ctl.theme.bgBase : ctl.theme.textPrimary
          font { pixelSize: 10; family: ctl.font }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ctl.set(modelData) }
      }
    }
  }
}
