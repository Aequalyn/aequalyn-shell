import QtQuick
import Quickshell

Rectangle {
  // the bar this widget sits in: theme, font, shared state and actions (Bar.qml)
  required property var bar
  // the colour the bar gives it (Bar page: the widgets' colours), transparent for its own
  property color ink: "transparent"
  id: brightWidget
  // icon and value side by side; stacked, narrower, on a side bar
  height: bar.vertical ? brightContent.height + 10 : 24
  width: bar.vertical ? bar.chipAcross : brightContent.width + 12
  radius: 12
  color: quick.visible ? bar.theme.bgSelected : bar.chipColor
  // no backlight: the bar hides the whole slot
  readonly property bool wanted: bar.hasBacklight
  visible: wanted
  Grid {
    id: brightContent
    anchors.centerIn: parent
    columns: bar.vertical ? 1 : 99
    columnSpacing: 6
    rowSpacing: 1
    horizontalItemAlignment: Grid.AlignHCenter
    verticalItemAlignment: Grid.AlignVCenter
    Text {
      text: "󰃠"
      color: bar.inked(ink, bar.theme.accentOrange)
      font.pixelSize: 14
      font.family: bar.font
    }
    Text {
      readonly property string full: Math.round(bar.brightnessValue * 100) + "%"
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
      const role = brightWidget.bar.clickRole("brightness", mouse.button);
      if (role === "quick") brightWidget.toggleQuick();
      else if (role !== "middle") brightWidget.bar.openPage("screens");
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
