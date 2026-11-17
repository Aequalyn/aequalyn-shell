import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "root:/style/Wheel.js" as Wheel

Rectangle {
  // the bar this widget sits in: theme, font, shared state and actions (Bar.qml)
  required property var bar
  id: volWidget
  height: 24
  width: volContent.width + 12
  radius: 12
  color: quick.visible ? bar.theme.bgSelected : bar.chipColor
  Row {
    id: volContent
    anchors.centerIn: parent
    spacing: 6
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: {
        const sink = Pipewire.defaultAudioSink;
        if (!sink || !sink.audio || sink.audio.muted || sink.audio.volume <= 0) return "󰖁";
        if (sink.audio.volume < 0.33) return "󰕿";
        if (sink.audio.volume < 0.66) return "󰖀";
        return "󰕾";
      }
      color: {
        const sink = Pipewire.defaultAudioSink;
        if (!sink || !sink.audio || sink.audio.muted) return bar.theme.textMuted;
        return bar.theme.accentPrimary;
      }
      font.pixelSize: 14
      font.family: bar.font
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: {
        const sink = Pipewire.defaultAudioSink;
        if (!sink || !sink.audio) return "–";
        if (sink.audio.muted) return "Mute";
        return Math.round(sink.audio.volume * 100) + "%";
      }
      color: bar.theme.textPrimary
      font.pixelSize: 11
      font.family: bar.font
    }
  }
  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    onClicked: (mouse) => {
      const role = volWidget.bar.clickRole("volume", mouse.button);
      if (role === "quick") { volWidget.toggleQuick(); return; }
      if (role === "right") { volWidget.bar.openPage("sound"); return; }
      if (role !== "main") return;
      const sink = Pipewire.defaultAudioSink;
      if (sink && sink.audio) sink.audio.muted = !sink.audio.muted;
    }
    onWheel: (wheel) => {
      const sink = Pipewire.defaultAudioSink;
      if (!sink || !sink.audio) return;
      const s = Wheel.step(wheel, bar.wheelAcc);
      if (s === 0) return;
      const delta = s * 0.05;
      sink.audio.volume = Math.max(0, Math.min(1.5, sink.audio.volume + delta));
    }
  }

  // its quick panel (SoundQuick.qml), on the click you chose (Bar page)
  function toggleQuick() {
    const w = volWidget.QsWindow.window;
    volWidget.bar.toggleWidgetPopup("volume", w ? w.screen : null);
  }
  SoundQuick {
    id: quick
    bar: volWidget.bar
    anchorItem: volWidget
    open: volWidget.bar.widgetPopup === "volume" && !!volWidget.QsWindow.window
          && volWidget.QsWindow.window.screen === volWidget.bar.popupScreen
    onDismissed: volWidget.bar.widgetPopup = ""
  }
}
