import QtQuick
import QtQuick.Effects
import Quickshell
import QtQuick.Controls

// Aequalyn mark: opens the app launcher (SUPER+D).
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
    id: logo
    anchors.centerIn: parent
    source: "root:/assets/ae-mark.svg"
    sourceSize.width: 24; sourceSize.height: 16
    width: 24; height: 16
    fillMode: Image.PreserveAspectFit
    smooth: true
    layer.enabled: true
    layer.effect: MultiEffect {
      colorization: 1.0
      colorizationColor: bar.theme.accentPrimary
    }
  }
  MouseArea {
    id: appsMenuHover
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: bar.openLauncher()
  }
}
