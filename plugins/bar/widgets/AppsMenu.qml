import QtQuick
import Quickshell
import QtQuick.Controls

// Arch logo: opens the app launcher (SUPER+D).
Rectangle {
  // the bar this widget sits in: theme, font, shared state and actions (Bar.qml)
  required property var bar
  id: appsMenu
  objectName: "apps-menu"
  Accessible.role: Accessible.Button
  Accessible.name: "apps-menu"
  width: 28; height: 24
  radius: 8
  color: appsMenuHover.containsMouse ? bar.theme.bgSelected : "transparent"
  Image {
    anchors.centerIn: parent
    source: "root:/assets/apps-menu.svg"
    sourceSize.width: 16; sourceSize.height: 16
    width: 16; height: 16
    fillMode: Image.PreserveAspectFit
    smooth: true
  }
  MouseArea {
    id: appsMenuHover
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: bar.openLauncher()
  }
}
