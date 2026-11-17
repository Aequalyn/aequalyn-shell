import QtQuick
import Quickshell
import "root:/plugins/kit"

// Timer: a countdown, a pomodoro or a stopwatch, while it runs.
// A click opens it; a right click, its quick panel. Hidden while its plugin
// is off (Plugins), or while there is nothing to show.
Rectangle {
  id: root
  // the bar this widget sits in: theme, font, shared state and actions (Bar.qml)
  required property var bar
  readonly property var svc: KitHost.get("timer")
  readonly property bool wanted: !!svc && (root.svc.mode !== "")
  visible: wanted
  height: 24
  width: wanted ? label.implicitWidth + 18 : 0
  radius: 12
  color: area.containsMouse || quick.visible ? bar.theme.bgSelected : bar.chipColor
  Text {
    id: label
    anchors.centerIn: parent
    text: root.wanted ? (root.svc.paused ? "\u{F03E4} " : root.svc.mode === "rest" ? "\u{F0130} " : "\u{F051B} ") + root.svc.label : ""
    color: bar.theme.textPrimary
    font.pixelSize: 12
    font.family: bar.font
  }
  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: (mouse) => {
      if (mouse.button === Qt.RightButton) root.toggleQuick();
      else if (root.svc) root.svc.toggle();
    }
  }

  // its quick panel (TimerQuick.qml)
  // gone from the bar: it closes too
  onWantedChanged: if (!wanted && root.bar.widgetPopup === "timer") root.bar.widgetPopup = ""
  function toggleQuick() {
    const w = root.QsWindow.window;
    root.bar.toggleWidgetPopup("timer", w ? w.screen : null);
  }
  TimerQuick {
    id: quick
    bar: root.bar
    anchorItem: root
    open: root.wanted && root.bar.widgetPopup === "timer" && !!root.QsWindow.window
          && root.QsWindow.window.screen === root.bar.popupScreen
    onDismissed: root.bar.widgetPopup = ""
  }
}
