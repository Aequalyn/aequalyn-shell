import QtQuick
import Quickshell
import "root:/style/Wheel.js" as Wheel

Rectangle {
  // the bar this widget sits in: theme, font, shared state and actions (Bar.qml)
  required property var bar
  // the colour the bar gives it (Bar page: the widgets' colours), transparent for its own
  property color ink: "transparent"
  id: brightWidget
  // the wheel does this widget's own thing, so its bar region doesn't slide under it
  readonly property bool usesWheel: true
  height: 24
  width: brightContent.width + 12
  radius: 12
  color: quick.visible ? bar.theme.bgSelected : bar.chipColor
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
      color: bar.inked(ink, bar.theme.accentOrange)
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
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    onClicked: (mouse) => {
      const role = brightWidget.bar.clickRole("brightness", mouse.button);
      if (role === "quick") brightWidget.toggleQuick();
      else if (role !== "middle") brightWidget.bar.openPage("screens");
    }
    onWheel: (wheel) => {
      const s = Wheel.step(wheel, bar.wheelAcc);
      if (s !== 0) bar.stepBrightness(s > 0);
    }
  }

  // its quick panel (BrightnessQuick.qml), on the click you chose (Bar page)
  function toggleQuick() {
    const w = brightWidget.QsWindow.window;
    brightWidget.bar.toggleWidgetPopup("brightness", w ? w.screen : null);
  }
  BrightnessQuick {
    id: quick
    bar: brightWidget.bar
    anchorItem: brightWidget
    open: brightWidget.wanted && brightWidget.bar.widgetPopup === "brightness" && !!brightWidget.QsWindow.window
          && brightWidget.QsWindow.window.screen === brightWidget.bar.popupScreen
    onDismissed: brightWidget.bar.widgetPopup = ""
  }
}
