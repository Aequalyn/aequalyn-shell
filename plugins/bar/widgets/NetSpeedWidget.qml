import QtQuick
import Quickshell
import "root:/plugins/kit"

// Network speed: what comes in and goes out right now. Any click but the middle one
// opens its quick panel. Not on the bar while its plugin is off.
Rectangle {
  id: root
  // the bar this widget sits in: theme, font, shared state and actions (Bar.qml)
  required property var bar
  // the colour the bar gives it (Bar page: the widgets' colours), transparent for its own
  property color ink: "transparent"
  readonly property var svc: KitHost.get("netSpeed")
  readonly property bool wanted: !!svc && (true)
  visible: wanted
  // one line; on a side bar its icon over its value, as wide as the bar allows
  height: bar.vertical ? (wanted ? label.implicitHeight + 10 : 0) : 24
  width: wanted ? (bar.vertical ? bar.chipAcross : label.implicitWidth + 18) : 0
  radius: 12
  color: area.containsMouse || quick.visible ? bar.theme.bgSelected : bar.chipColor
  Text {
    id: label
    anchors.centerIn: parent
    readonly property string full: root.wanted ? root.svc.label : ""
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
    // it has nothing else to do: any click but the middle one opens its quick panel
    onClicked: (mouse) => { if (root.bar.clickRole("netspeed", mouse.button) !== "middle") root.toggleQuick(); }
  }

  // its quick panel (NetSpeedQuick.qml)
  // gone from the bar: it closes too
  onWantedChanged: if (!wanted && root.bar.widgetPopup === "netSpeed") root.bar.widgetPopup = ""
  function toggleQuick() {
    const w = root.QsWindow.window;
    root.bar.toggleWidgetPopup("netSpeed", w ? w.screen : null);
  }
  NetSpeedQuick {
    id: quick
    bar: root.bar
    anchorItem: root
    open: root.wanted && root.bar.widgetPopup === "netSpeed" && !!root.QsWindow.window
          && root.QsWindow.window.screen === root.bar.popupScreen
    onDismissed: root.bar.widgetPopup = ""
  }
}
