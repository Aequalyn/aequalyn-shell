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
  color: btHover.containsMouse || btPopup.visible ? bar.theme.bgSelected : bar.chipColor
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
    visible: btHover.containsMouse && !btPopup.visible
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
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: (mouse) => {
      if (mouse.button === Qt.RightButton) {
        bar.openSettingsPage("bluetooth")
      } else {
        const w = btPill.QsWindow.window;
        bar.bluetoothPopupVisible = bar.togglePopup(bar.bluetoothPopupVisible, w ? w.screen : null)
      }
    }
  }

  // ---- the device list --------------------------------------------------------------
  // a scan started here stops again when the popup closes
  property bool startedScan: false
  function scan(on) {
    BluetoothService.setDiscovering(on);
    btPill.startedScan = on;
  }

  // BlueZ icon names -> a glyph
  function glyphFor(d) {
    const i = (d && d.icon) || "";
    if (i.indexOf("headset") >= 0 || i.indexOf("headphone") >= 0) return "󰋋";
    if (i.indexOf("audio") >= 0) return "󰓃";
    if (i.indexOf("keyboard") >= 0) return "󰌌";
    if (i.indexOf("mouse") >= 0) return "󰍽";
    if (i.indexOf("gaming") >= 0) return "󰊴";
    if (i.indexOf("phone") >= 0) return "󰏲";
    if (i.indexOf("computer") >= 0) return "󰟀";
    return "󰂯";
  }
  function statusOf(d) {
    if (d.pairing || BluetoothService.isPending(d)) return "Pairing…";
    if (d.state === 3) return "Connecting…";
    if (d.state === 2) return "Disconnecting…";
    const battery = d.batteryAvailable ? " · " + Math.round(d.battery * 100) + "%" : "";
    if (d.connected) return "Connected" + battery;
    return BluetoothService.isRemembered(d) ? "Remembered" : "Not paired";
  }

  PopupWindow {
    id: btPopup
    visible: bar.bluetoothPopupVisible && !!btPill.QsWindow.window && btPill.QsWindow.window.screen === bar.popupScreen
    implicitWidth: 320
    implicitHeight: Math.min(440, btContent.implicitHeight + 24)
    color: "transparent"

    // anchored to the icon itself, so it follows it wherever the bar places it (a position
    // worked out once, when the widget is made, can be stale by the time it opens)
    anchor.item: btPill
    anchor.rect.x: 0
    anchor.rect.y: 0
    anchor.rect.width: btPill.width
    anchor.rect.height: btPill.height + 8
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.adjustment: PopupAdjustment.Slide

    onVisibleChanged: if (!visible && btPill.startedScan) btPill.scan(false)

    Shortcut {
      sequence: "Escape"
      onActivated: bar.bluetoothPopupVisible = false
    }

    Rectangle {
      anchors.fill: parent
      color: bar.theme.bgBase
      border.color: bar.theme.bgBorder
      border.width: 1
      radius: 12

      ColumnLayout {
        id: btContent
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        // header: state, on / off, scan, close
        RowLayout {
          Layout.fillWidth: true
          Text {
            Layout.fillWidth: true
            text: !BluetoothService.available ? "No Bluetooth adapter"
                : BluetoothService.powered ? "Bluetooth on" : "Bluetooth off"
            color: bar.theme.textPrimary
            font.pixelSize: 12
            font.family: bar.font
          }
          HeaderButton {
            visible: BluetoothService.available
            label: BluetoothService.powered ? "Off" : "On"
            onClicked: BluetoothService.togglePower()
          }
          HeaderButton {
            visible: BluetoothService.powered
            label: BluetoothService.discovering ? "Stop" : "Scan"
            onClicked: btPill.scan(!BluetoothService.discovering)
          }
          HeaderButton {
            label: "✕"
            implicitWidth: 24
            onClicked: bar.bluetoothPopupVisible = false
          }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: bar.theme.bgBorder }

        Text {
          visible: BluetoothService.powered && BluetoothService.remembered.length === 0
                   && BluetoothService.nearby.length === 0
          Layout.fillWidth: true
          wrapMode: Text.WordWrap
          text: BluetoothService.discovering ? "Looking for devices… put yours in pairing mode."
                                             : "No devices yet. Scan to find one nearby."
          color: bar.theme.textMuted
          font.pixelSize: 11
          font.family: bar.font
        }

        ScrollView {
          id: scroller
          visible: BluetoothService.powered
          Layout.fillWidth: true
          // the list is as wide as the popup; left to itself it would be as narrow as its content
          contentWidth: availableWidth
          Layout.fillHeight: true
          Layout.preferredHeight: Math.min(320, list.implicitHeight)
          clip: true
          ColumnLayout {
            id: list
            width: scroller.availableWidth
            spacing: 4

            SectionLabel { text: "Remembered"; visible: BluetoothService.remembered.length > 0 }
            Repeater {
              model: BluetoothService.remembered
              DeviceRow { remembered: true }
            }
            SectionLabel { text: "Nearby"; visible: BluetoothService.nearby.length > 0 }
            Repeater {
              model: BluetoothService.nearby
              DeviceRow { remembered: false }
            }
          }
        }
      }
    }
  }

  component HeaderButton: Rectangle {
    id: hb
    property string label: ""
    signal clicked()
    implicitWidth: 52
    implicitHeight: 24
    radius: 6
    color: hbArea.containsMouse ? bar.theme.bgHover : bar.theme.bgSelected
    border.color: bar.theme.bgBorder
    border.width: 1
    Text {
      anchors.centerIn: parent
      text: hb.label
      color: bar.theme.textPrimary
      font.pixelSize: 10
      font.family: bar.font
    }
    MouseArea { id: hbArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: hb.clicked() }
  }

  component SectionLabel: Text {
    Layout.topMargin: 4
    color: bar.theme.textMuted
    font.pixelSize: 9
    font.family: bar.font
    font.capitalization: Font.AllUppercase
  }

  // one device: icon, name, state; Connect / Disconnect (remembered) or Pair (nearby),
  // and Forget for a remembered one
  component DeviceRow: Rectangle {
    id: row
    required property var modelData
    property bool remembered: false
    readonly property bool busy: modelData.pairing || modelData.state === 2 || modelData.state === 3
                                 || BluetoothService.isPending(modelData)
    Layout.fillWidth: true
    implicitHeight: 40
    radius: 8
    color: bar.theme.bgSurface
    border.color: modelData.connected ? bar.theme.accentPrimary : bar.theme.bgBorder
    border.width: 1
    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: 10
      anchors.rightMargin: 8
      spacing: 8
      Text {
        text: btPill.glyphFor(row.modelData)
        color: row.modelData.connected ? bar.theme.accentCyan : bar.theme.textSecondary
        font.pixelSize: 15
        font.family: bar.font
      }
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        Text {
          Layout.fillWidth: true
          text: BluetoothService.label(row.modelData)
          color: bar.theme.textPrimary
          font.pixelSize: 11
          font.family: bar.font
          elide: Text.ElideRight
        }
        Text {
          Layout.fillWidth: true
          text: btPill.statusOf(row.modelData)
          color: bar.theme.textMuted
          font.pixelSize: 9
          font.family: bar.font
        }
      }
      // the main action
      Rectangle {
        implicitWidth: 72
        implicitHeight: 22
        radius: 6
        opacity: row.busy ? 0.5 : 1
        color: actArea.containsMouse && !row.busy ? bar.theme.accentPrimary : bar.theme.bgSelected
        border.color: bar.theme.bgBorder
        border.width: 1
        Text {
          anchors.centerIn: parent
          text: row.modelData.connected ? "Disconnect" : (row.remembered ? "Connect" : "Pair")
          color: actArea.containsMouse && !row.busy ? bar.theme.bgBase : bar.theme.textPrimary
          font.pixelSize: 9
          font.family: bar.font
        }
        MouseArea {
          id: actArea
          anchors.fill: parent
          hoverEnabled: true
          enabled: !row.busy
          cursorShape: Qt.PointingHandCursor
          // pairing a nearby device remembers it (trusts it) and connects it once paired
          onClicked: row.modelData.connected ? BluetoothService.disconnectDevice(row.modelData)
                                             : BluetoothService.connectDevice(row.modelData)
        }
      }
      // forget: unpair, so it's no longer remembered
      Rectangle {
        visible: row.remembered
        implicitWidth: 22
        implicitHeight: 22
        radius: 6
        color: forgetArea.containsMouse ? bar.theme.accentRed : "transparent"
        Text {
          anchors.centerIn: parent
          text: "󰆴"
          color: forgetArea.containsMouse ? bar.theme.bgBase : bar.theme.textMuted
          font.pixelSize: 12
          font.family: bar.font
        }
        MouseArea {
          id: forgetArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: BluetoothService.forgetDevice(row.modelData)
          ToolTip.visible: containsMouse
          ToolTip.text: "Forget this device"
          ToolTip.delay: 400
        }
      }
    }
  }
}
