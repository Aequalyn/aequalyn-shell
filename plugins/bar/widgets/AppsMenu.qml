import QtQuick
import QtQuick.Effects
import Quickshell
import QtQuick.Controls

// Aequalyn mark: opens the app launcher (Super + D); the click you choose (Bar page, a
// right click unless you change it), its quick panel. Not on the bar while the app
// launcher is off.
Rectangle {
  // the bar this widget sits in: theme, font, shared state and actions (Bar.qml)
  required property var bar
  // the colour the bar gives it (Bar page: the widgets' colours), transparent for its own
  property color ink: "transparent"
  id: appsMenu
  objectName: "apps-menu"
  Accessible.role: Accessible.Button
  Accessible.name: "apps-menu"
  width: 28; height: 24
  radius: 8
  color: appsMenuHover.containsMouse || quick.visible ? bar.theme.bgSelected : "transparent"
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
      colorizationColor: bar.inked(ink, bar.theme.accentPrimary)
    }
  }
  MouseArea {
    id: appsMenuHover
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    onClicked: (mouse) => {
      const role = appsMenu.bar.clickRole("appsmenu", mouse.button);
      if (role === "quick") appsMenu.toggleQuick();
      else if (role === "main") appsMenu.bar.openLauncher();
    }
  }

  // its quick panel (AppsQuick.qml), on the click you chose (Bar page)
  function toggleQuick() {
    const w = appsMenu.QsWindow.window;
    appsMenu.bar.toggleWidgetPopup("appsmenu", w ? w.screen : null);
  }
  AppsQuick {
    id: quick
    bar: appsMenu.bar
    anchorItem: appsMenu
    open: appsMenu.bar.widgetPopup === "appsmenu" && !!appsMenu.QsWindow.window
          && appsMenu.QsWindow.window.screen === appsMenu.bar.popupScreen
    onDismissed: appsMenu.bar.widgetPopup = ""
  }
}
