import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Rectangle {
  // the bar this widget sits in: theme, font, shared state and actions (Bar.qml)
  required property var bar
  // the colour the bar gives it (Bar page: the widgets' colours), transparent for its own
  property color ink: "transparent"
  id: volWidget
  // icon and value side by side; stacked, narrower, on a side bar
  height: bar.vertical ? volContent.height + 10 : 24
  width: bar.vertical ? bar.chipAcross : volContent.width + 12
  radius: 12
  color: quick.visible ? bar.theme.bgSelected : bar.chipColor
  Grid {
    id: volContent
    anchors.centerIn: parent
    columns: bar.vertical ? 1 : 99
    columnSpacing: 6
    rowSpacing: 1
    horizontalItemAlignment: Grid.AlignHCenter
    verticalItemAlignment: Grid.AlignVCenter
    Text {
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
        return bar.inked(ink, bar.theme.accentPrimary);
      }
      font.pixelSize: 14
      font.family: bar.font
    }
    Text {
      readonly property string full: {
        const sink = Pipewire.defaultAudioSink;
        if (!sink || !sink.audio) return "–";
        if (sink.audio.muted) return "Mute";
        return Math.round(sink.audio.volume * 100) + "%";
      }
      color: bar.theme.textPrimary
      font.pixelSize: bar.vertical ? 9 : 11
      font.family: bar.font
      // on a side bar: shorter (no %%, no decimals), centred under the icon
      text: bar.vertical ? bar.compact(full) : full
      horizontalAlignment: Text.AlignHCenter
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
