import QtQuick
import Quickshell
import "root:/plugins/kit"

// Weather: the temperature and the sky where you are. A click shows the next days;
// the click you choose on the Bar page (a right click unless you change it), its quick
// panel. Not on the bar while its plugin is off; hidden until it knows the weather.
Rectangle {
  id: root
  // the bar this widget sits in: theme, font, shared state and actions (Bar.qml)
  required property var bar
  // the colour the bar gives it (Bar page: the widgets' colours), transparent for its own
  property color ink: "transparent"
  readonly property var svc: KitHost.get("weather")
  readonly property bool wanted: !!svc && (root.svc.now !== null)
  visible: wanted
  // one line; on a side bar its icon over its value, as wide as the bar allows
  height: bar.vertical ? (wanted ? label.implicitHeight + 10 : 0) : 24
  width: wanted ? (bar.vertical ? bar.chipAcross : label.implicitWidth + 18) : 0
  radius: 12
  color: area.containsMouse || quick.visible ? bar.theme.bgSelected : bar.chipColor
  Text {
    id: label
    anchors.centerIn: parent
    readonly property string full: root.wanted ? root.svc.now.icon + " " + root.svc.now.temp : ""
    color: bar.inked(ink, bar.theme.textPrimary)
    font.pixelSize: bar.vertical ? 9 : 12
    font.family: bar.font
    text: bar.vertical ? full.replace(/ +/, "\n") : full
    width: bar.vertical ? bar.chipAcross - 4 : implicitWidth
    wrapMode: bar.vertical ? Text.WrapAnywhere : Text.NoWrap
    horizontalAlignment: Text.AlignHCenter
  }
  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    // the click you chose (Bar page) opens its quick panel, the left one its own panel
    onClicked: (mouse) => {
      const role = root.bar.clickRole("weather", mouse.button);
      if (role === "quick") root.toggleQuick();
      else if (role === "main") if (root.svc) root.svc.toggle();
    }
  }

  // its quick panel (WeatherQuick.qml)
  // gone from the bar: it closes too
  onWantedChanged: if (!wanted && root.bar.widgetPopup === "weather") root.bar.widgetPopup = ""
  function toggleQuick() {
    const w = root.QsWindow.window;
    root.bar.toggleWidgetPopup("weather", w ? w.screen : null);
  }
  WeatherQuick {
    id: quick
    bar: root.bar
    anchorItem: root
    open: root.wanted && root.bar.widgetPopup === "weather" && !!root.QsWindow.window
          && root.QsWindow.window.screen === root.bar.popupScreen
    onDismissed: root.bar.widgetPopup = ""
  }
}
