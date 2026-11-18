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
  height: 24
  width: wanted ? label.implicitWidth + 18 : 0
  radius: 12
  color: area.containsMouse || quick.visible ? bar.theme.bgSelected : bar.chipColor
  Text {
    id: label
    anchors.centerIn: parent
    text: root.wanted ? root.svc.label : ""
    color: bar.inked(ink, bar.theme.textPrimary)
    font.pixelSize: 12
    font.family: bar.font
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
