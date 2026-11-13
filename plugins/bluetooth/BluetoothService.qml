// Bluetooth state/service integration for the shell.
// Wraps Quickshell Bluetooth APIs to expose adapter/device state, scanning,
// connect/disconnect/pair/trust actions, and audio profile helpers for UI
// components (bar, settings). Centralizes device management logic in one place.

pragma Singleton

// Aequalyn Bluetooth service -- thin, reactive wrapper over Quickshell's native
// Quickshell.Bluetooth (BlueZ over D-Bus). No external commands needed.
import Quickshell
import Quickshell.Bluetooth
import QtQuick

QtObject {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null && adapter !== undefined
    readonly property bool powered: available ? adapter.enabled : false
    readonly property bool discovering: available ? adapter.discovering : false
    readonly property var devices: Bluetooth.devices

    readonly property string connectedName: {
        let devs = []
        try { devs = Bluetooth.devices.values || [] } catch (e) { return "" }
        for (const d of devs) {
            if (d.connected) return d.deviceName || d.name || "Connected"
        }
        return ""
    }

    readonly property int connectedCount: {
        let n = 0
        let devs = []
        try { devs = Bluetooth.devices.values || [] } catch (e) { return 0 }
        for (const d of devs) if (d.connected) n++
        return n
    }

    // Remembered: paired or trusted, so BlueZ keeps them across reboots and they can
    // reconnect on their own. Nearby: everything else found by a scan.
    function isRemembered(d) { return !!d && (d.paired || d.trusted || d.bonded) }
    readonly property var remembered: {
        let devs = []
        try { devs = Bluetooth.devices.values || [] } catch (e) { return [] }
        return devs.filter(d => root.isRemembered(d))
            .sort((a, b) => (b.connected - a.connected) || root.label(a).localeCompare(root.label(b)))
    }
    readonly property var nearby: {
        let devs = []
        try { devs = Bluetooth.devices.values || [] } catch (e) { return [] }
        // unnamed devices (only an address) are mostly beacons nobody wants to pair with
        return devs.filter(d => !root.isRemembered(d) && (d.deviceName || d.name))
            .sort((a, b) => root.label(a).localeCompare(root.label(b)))
    }
    function label(d) { return d ? (d.deviceName || d.name || d.address || "Device") : "" }

    readonly property int deviceCount: {
        let devs = []
        try { devs = Bluetooth.devices.values || [] } catch (e) { return 0 }
        return devs.length
    }

    // Remember a device so BlueZ keeps it across reboots and can auto-connect:
    // trust it (and pair it first when it is not paired yet). Make the adapter
    // pairable first so a fresh pairing is actually allowed.
    function rememberDevice(device) {
        if (!device) return
        try { if (root.available) root.adapter.pairable = true } catch (e) {}
        try { device.trusted = true } catch (e) {}
        if (!device.paired) {
            try { device.cancelPairing() } catch (e) {}
            try { device.pair() } catch (e) {}
        }
    }

    // Connecting a device that isn't paired yet pairs it first; pairing finishes later
    // (the device may ask to confirm), so it's connected once BlueZ says it's paired.
    property var pendingConnect: ({})      // address -> time asked
    function connectDevice(device) {
        if (!device) return
        root.rememberDevice(device)
        if (device.paired) { root._connect(device); return }
        const p = Object.assign({}, root.pendingConnect)
        p[device.address] = Date.now()
        root.pendingConnect = p
    }
    function _connect(device) {
        try { device.connect() } catch (e) {
            try { device.connected = true } catch (e2) {}
        }
    }
    property Timer pendingTimer: Timer {
        interval: 500; repeat: true
        running: Object.keys(root.pendingConnect).length > 0
        onTriggered: {
            const p = Object.assign({}, root.pendingConnect)
            let devs = []
            try { devs = Bluetooth.devices.values || [] } catch (e) {}
            for (const addr of Object.keys(p)) {
                const d = devs.find(x => x.address === addr)
                // gone, or still not paired after 45 s (declined, out of range): give up
                if (!d || Date.now() - p[addr] > 45000) { delete p[addr]; continue }
                if (d.paired) { root.trustDevice(d, true); root._connect(d); delete p[addr] }
            }
            root.pendingConnect = p
        }
    }
    function isPending(device) { return !!device && root.pendingConnect[device.address] !== undefined }

    function disconnectDevice(device) {
        if (!device) return
        try { device.disconnect() } catch (e) {}
        try { device.connected = false } catch (e) {}
    }

    function pairDevice(device) {
        if (!device) return
        try { device.pair() } catch (e) {}
        root.rememberDevice(device)
    }

    function trustDevice(device, on) {
        if (!device) return
        try { device.trusted = (on === undefined ? true : !!on) } catch (e) {}
    }

    function forgetDevice(device) {
        if (!device) return
        const p = Object.assign({}, root.pendingConnect)
        delete p[device.address]
        root.pendingConnect = p
        try { device.forget() } catch (e) {}
    }

    function setPowered(on) {
        if (root.available) root.adapter.enabled = on
    }
    function togglePower() { root.setPowered(!root.powered) }
    function setDiscovering(on) {
        if (root.available) {
            try { root.adapter.pairable = true } catch (e) {}
            root.adapter.discovering = on
        }
    }
    function toggleDiscovering() { root.setDiscovering(!root.discovering) }
}
