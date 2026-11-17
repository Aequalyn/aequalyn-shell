import QtQuick
import Quickshell
import "root:/plugins/kit"

// Network speed: what comes in and goes out right now.
// Hidden while its plugin is off (Plugins), or while there is nothing to show.
Rectangle {
  id: root
  // the bar this widget sits in: theme, font, shared state and actions (Bar.qml)
  required property var bar
  readonly property var svc: KitHost.get("netSpeed")
  readonly property bool wanted: !!svc && (true)
  visible: wanted
  height: 24
  width: wanted ? label.implicitWidth + 18 : 0
  radius: 12
  color: area.containsMouse ? bar.theme.bgSelected : bar.chipColor
  Text {
    id: label
    anchors.centerIn: parent
    text: root.wanted ? root.svc.label : ""
    color: bar.theme.textPrimary
    font.pixelSize: 12
    font.family: bar.font
  }
  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: {}
  }
}
