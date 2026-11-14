import QtQuick
import Quickshell
import "root:/plugins/atelier"

// Themes and Layouts buttons: a left click opens the theme picker over the blurred
// desktop (Themes) or the control center's Arranging windows page (Layouts). Right and
// middle click do what the control center's Theme picker page says.
Rectangle {
  id: btn
  // the bar this button sits in (Bar.qml)
  required property var bar
  property string tab: "themes"
  property string icon: ""
  property string label: ""
  property bool showName: true
  property string rightAction: "none"
  property string middleAction: "none"
  readonly property bool active: AtelierHost.shown && AtelierHost.shownCollection === tab
  readonly property string screenName: {
    try { return btn.QsWindow.window && btn.QsWindow.window.screen ? btn.QsWindow.window.screen.name : ""; }
    catch (e) { return ""; }
  }
  onScreenNameChanged: if (screenName !== "") AtelierHost.register(screenName + ":" + tab, btn)
  Component.onDestruction: AtelierHost.unregister(screenName + ":" + tab, btn)

  height: 24
  width: row.implicitWidth + 16
  radius: 12
  color: active ? btn.bar.theme.bgSelected : (area.containsMouse ? btn.bar.theme.bgHover : btn.bar.chipColor)
  border.width: active ? 1 : 0
  border.color: btn.bar.theme.accentPrimary
  Behavior on color { ColorAnimation { duration: 120 } }

  Row {
    id: row
    anchors.centerIn: parent
    spacing: 6
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: btn.icon
      color: btn.bar.theme.accentPrimary
      font.pixelSize: 14
      font.family: btn.bar.font
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      visible: btn.showName && btn.label !== ""
      text: btn.label
      color: btn.bar.theme.textPrimary
      font.pixelSize: 11
      font.family: btn.bar.font
    }
  }
  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    onClicked: mouse => {
      if (mouse.button === Qt.LeftButton) AtelierHost.toggle(btn.tab, btn, btn.screenName);
      else if (mouse.button === Qt.RightButton) AtelierHost.act(btn.rightAction);
      else AtelierHost.act(btn.middleAction);
    }
  }
}
