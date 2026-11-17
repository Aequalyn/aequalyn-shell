// Bluetooth's quick panel: on or off, your devices (a click connects or disconnects),
// and the ones nearby while it looks (a click pairs and connects); last, the page.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/plugins/bar/quick"
import "root:/plugins/bluetooth"

QuickPopup {
    id: q
    required property var bar
    // a look started here stops when the panel closes
    property bool startedScan: false
    function scan(on) { BluetoothService.setDiscovering(on); q.startedScan = on }
    onVisibleChanged: if (!visible && q.startedScan) q.scan(false)

    function glyphFor(d) {
        const i = (d && d.icon) || "";
        if (i.indexOf("headset") >= 0 || i.indexOf("headphone") >= 0) return "\u{F02CB}";
        if (i.indexOf("audio") >= 0) return "\u{F04C3}";
        if (i.indexOf("keyboard") >= 0) return "\u{F030C}";
        if (i.indexOf("mouse") >= 0) return "\u{F037D}";
        if (i.indexOf("gaming") >= 0) return "\u{F02B4}";
        if (i.indexOf("phone") >= 0) return "\u{F03F2}";
        if (i.indexOf("computer") >= 0) return "\u{F07C0}";
        return "\u{F00AF}";
    }
    function statusOf(d) {
        if (d.pairing || BluetoothService.isPending(d)) return "Pairing…";
        if (d.state === 3) return "Connecting…";
        if (d.state === 2) return "Disconnecting…";
        const battery = d.batteryAvailable ? " · " + Math.round(d.battery * 100) + "%" : "";
        if (d.connected) return "Connected" + battery;
        return BluetoothService.isRemembered(d) ? "Not connected" : "Not paired";
    }

    glyph: "\u{F00AF}"
    title: "Bluetooth"
    sub: !BluetoothService.available ? "No Bluetooth here" : !BluetoothService.powered ? "Off"
        : BluetoothService.connectedName !== "" ? "Connected to " + BluetoothService.connectedName : "On"
    settingsLabel: "Bluetooth settings"
    onSettingsClicked: { q.dismissed(); q.bar.openPage("bluetooth") }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        QuickTile {
            glyph: "\u{F00AF}"; title: "Bluetooth"
            sub: BluetoothService.powered ? BluetoothService.connectedCount + " connected" : "Off"
            on: BluetoothService.powered
            enabled: BluetoothService.available
            onToggled: BluetoothService.togglePower()
        }
        QuickTile {
            glyph: "\u{F0349}"; title: "Look for devices"
            sub: BluetoothService.discovering ? "Looking…" : "Pairing mode on yours"
            on: BluetoothService.discovering
            enabled: BluetoothService.powered
            onToggled: q.scan(!BluetoothService.discovering)
        }
    }

    Flickable {
        visible: BluetoothService.powered && (BluetoothService.remembered.length + BluetoothService.nearby.length) > 0
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(devCol.implicitHeight, 320)
        contentHeight: devCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: devCol
            width: parent.width
            spacing: 6
            QuickLabel { visible: BluetoothService.remembered.length > 0; text: "Your devices" }
            Repeater {
                model: BluetoothService.remembered
                delegate: QuickTile {
                    required property var modelData
                    glyph: q.glyphFor(modelData)
                    title: BluetoothService.label(modelData)
                    sub: q.statusOf(modelData)
                    on: !!modelData.connected
                    onToggled: modelData.connected ? BluetoothService.disconnectDevice(modelData) : BluetoothService.connectDevice(modelData)
                }
            }
            QuickLabel { visible: BluetoothService.nearby.length > 0; text: "Nearby" }
            Repeater {
                model: BluetoothService.nearby
                delegate: QuickTile {
                    required property var modelData
                    glyph: q.glyphFor(modelData)
                    title: BluetoothService.label(modelData)
                    sub: q.statusOf(modelData)
                    onToggled: BluetoothService.connectDevice(modelData)
                }
            }
        }
    }
    Text {
        visible: BluetoothService.powered && BluetoothService.remembered.length === 0 && BluetoothService.nearby.length === 0
        Layout.fillWidth: true
        text: BluetoothService.discovering ? "Looking for devices… put yours in pairing mode." : "No devices yet. Look for devices to pair one."
        color: Quick.theme.textMuted
        font.family: Quick.mono
        font.pixelSize: 11
        wrapMode: Text.WordWrap
    }
}
