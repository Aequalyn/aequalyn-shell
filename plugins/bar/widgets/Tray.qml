import QtQuick
import Quickshell
import QtQuick.Layouts
import Quickshell.Widgets
import Quickshell.Services.SystemTray

Rectangle {
  // the bar this widget sits in: theme, font, shared state and actions (Bar.qml)
  required property var bar
  // no tray icons: the bar hides the whole slot
  readonly property bool wanted: SystemTray.items.values.length > 0
  implicitHeight: 24
  implicitWidth: trayIcons.implicitWidth + 8
  radius: 12
  color: bar.chipColor
  RowLayout {
    id: trayIcons
    anchors.centerIn: parent
    spacing: 2
    Repeater {
      model: SystemTray.items
      MouseArea {
        id: trayDelegate
        required property SystemTrayItem modelData
        Layout.preferredWidth: 24
        Layout.preferredHeight: 24
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: (mouse) => {
          if (mouse.button === Qt.LeftButton) modelData.activate()
          else if (mouse.button === Qt.RightButton && modelData.hasMenu) menuAnchor.open()
          else if (mouse.button === Qt.MiddleButton) modelData.secondaryActivate()
        }
        IconImage {
          anchors.centerIn: parent
          source: trayDelegate.modelData.icon
          implicitSize: 16
        }
        QsMenuAnchor {
          id: menuAnchor
          menu: trayDelegate.modelData.menu
          anchor.window: trayDelegate.QsWindow.window
          anchor.adjustment: PopupAdjustment.Flip
          anchor.onAnchoring: {
            const window = trayDelegate.QsWindow.window;
            const widgetRect = window.contentItem.mapFromItem(
              trayDelegate, 0, trayDelegate.height,
              trayDelegate.width, trayDelegate.height);
            menuAnchor.anchor.rect = widgetRect;
          }
        }
      }
    }
  }
}
