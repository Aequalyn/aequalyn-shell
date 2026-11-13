pragma Singleton

// Aequalyn Wi-Fi service -- thin, reactive wrapper over Quickshell's native
// Quickshell.Networking (NetworkManager). Exposes adapter/device state, scanning,
// connect/disconnect/forget actions and helpers for UI components (settings).
import Quickshell
import Quickshell.Networking
import QtQuick

QtObject {
    id: root

    readonly property bool available: {
        try { return Networking.backend === NetworkBackendType.NetworkManager } catch (e) { return false }
    }

    readonly property bool wifiHardwareEnabled: {
        try { return Networking.wifiHardwareEnabled } catch (e) { return true }
    }

    readonly property bool wifiEnabled: {
        try { return Networking.wifiEnabled } catch (e) { return false }
    }

    function setWifiEnabled(on) {
        try { Networking.wifiEnabled = on } catch (e) {}
    }

    function toggleWifi() {
        root.setWifiEnabled(!root.wifiEnabled)
    }

    readonly property var devices: {
        try {
            const v = Networking.devices
            return (v && v.values) ? v.values : (v || [])
        } catch (e) { return [] }
    }

    readonly property var wifiDevice: {
        for (const d of root.devices) {
            if (d && d.type === DeviceType.Wifi) return d
        }
        return null
    }

    readonly property var networks: {
        const d = root.wifiDevice
        if (!d || !d.networks) return []
        try {
            const v = d.networks
            return (v && v.values) ? v.values : (v || [])
        } catch (e) { return [] }
    }

    readonly property var connectedNetwork: {
        for (const n of root.networks) {
            if (n && n.connected) return n
        }
        return null
    }

    readonly property string connectedName: {
        const n = root.connectedNetwork
        return n ? (n.name || "") : ""
    }

    readonly property int networkCount: root.networks.length

    // Scanning is driven by the device's scannerEnabled flag.
    readonly property bool scanning: {
        const d = root.wifiDevice
        if (!d) return false
        try { return !!d.scannerEnabled } catch (e) { return false }
    }

    property var scannerDevice: null

    function setScanning(on) {
        const d = root.wifiDevice
        if (root.scannerDevice && root.scannerDevice !== d) {
            try { root.scannerDevice.scannerEnabled = false } catch (e) {}
        }
        root.scannerDevice = on ? d : null
        if (d) {
            try { d.scannerEnabled = on } catch (e) {}
        }
    }

    function scan() {
        root.setScanning(true)
    }

    function networkForSsid(ssid) {
        for (const n of root.networks) {
            if (n && n.name === ssid) return n
        }
        return null
    }

    function requiresCredentials(security) {
        return security !== WifiSecurityType.Open &&
               security !== WifiSecurityType.Owe &&
               security !== WifiSecurityType.Unknown
    }

    function securityText(security) {
        try { return WifiSecurityType.toString(security) } catch (e) { return "Secured" }
    }

    function connectNetwork(network) {
        if (!network) return
        if (root.requiresCredentials(network.security) && !network.known) return false
        try { network.connect() } catch (e) {}
        return true
    }

    function connectWithPsk(network, psk) {
        if (!network) return
        try { network.connectWithPsk(psk || "") } catch (e) {}
    }

    function disconnectNetwork(network) {
        const target = network || root.connectedNetwork
        if (!target) return
        try { target.disconnect() } catch (e) {}
    }

    function forgetNetwork(network) {
        const target = network ? root.networkForSsid(network.name || "") : null
        if (!target) return
        try { target.forget() } catch (e) {}
    }
}
