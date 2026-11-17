import QtQuick
import Quickshell
import QtQuick.Layouts
import QtQuick.Controls
import "root:/plugins/bluetooth"

// Bluetooth pill: icon only, plus a dot when a device is connected. A left click opens
// the Bluetooth popup (like the Wi-Fi one): on / off, a scan, the devices it remembers
// and the ones nearby. A right click opens Settings -> Bluetooth.
Rectangle {
  id: btPill
  // the bar this widget sits in: theme, font, shared state and actions (Bar.qml)
  required property var bar
  height: 24
  width: 26
  radius: 12
  color: btHover.containsMouse || quick.visible ? bar.theme.bgSelected : bar.chipColor
  Accessible.role: Accessible.Button
  Accessible.name: BluetoothService.connectedName !== ""
      ? "Bluetooth: connected to " + BluetoothService.connectedName
      : (BluetoothService.powered ? "Bluetooth on" : "Bluetooth off")

  Text {
    anchors.centerIn: parent
    text: "󰂯"
    color: BluetoothService.powered ? bar.theme.accentCyan : bar.theme.textMuted
    font.pixelSize: 14
    font.family: bar.font
  }
  Rectangle {
    visible: BluetoothService.connectedName !== ""
    width: 6; height: 6; radius: 3
    color: bar.theme.accentGreen
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: 3
  }

  // Hover tooltip with the full state / connected device name. Its own popup window:
  // drawn inside the bar it would be cut off at the bar's bottom edge. Not while the
  // device list is open.
  PopupWindow {
    visible: btHover.containsMouse && !quick.visible
    color: "transparent"
    implicitWidth: btTip.implicitWidth + 16
    implicitHeight: 24
    anchor.item: btPill
    anchor.rect.x: 0
    anchor.rect.y: 0
    anchor.rect.width: btPill.width
    anchor.rect.height: btPill.height + 6
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.adjustment: PopupAdjustment.Slide
    Rectangle {
      anchors.fill: parent
      radius: 6
      color: bar.theme.bgBase
      border.color: bar.theme.bgBorder
      border.width: 1
      Text {
        id: btTip
        anchors.centerIn: parent
        text: !BluetoothService.available ? "No Bluetooth adapter"
            : BluetoothService.connectedName !== "" ? BluetoothService.connectedName
            : BluetoothService.powered ? "Bluetooth on" : "Bluetooth off"
        color: bar.theme.textPrimary
        font.pixelSize: 10
        font.family: bar.font
      }
    }
  }

  MouseArea {
    id: btHover
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    onClicked: (mouse) => {
      const role = btPill.bar.clickRole("bluetooth", mouse.button);
      if (role === "quick") btPill.toggleQuick();
      else if (role !== "middle") btPill.bar.openPage("bluetooth");
    }
  }

  // its quick panel (BluetoothQuick.qml), on the click you chose (Bar page)
  function toggleQuick() {
    const w = btPill.QsWindow.window;
    btPill.bar.toggleWidgetPopup("bluetooth", w ? w.screen : null);
  }
  BluetoothQuick {
    id: quick
    bar: btPill.bar
    anchorItem: btPill
    open: btPill.bar.widgetPopup === "bluetooth" && !!btPill.QsWindow.window
          && btPill.QsWindow.window.screen === btPill.bar.popupScreen
    onDismissed: btPill.bar.widgetPopup = ""
  }
}
