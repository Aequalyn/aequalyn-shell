pragma Singleton

// Aequalyn Wi-Fi service -- thin, reactive wrapper over Quickshell's native
// Quickshell.Networking (NetworkManager). Exposes adapter/device state, scanning,
// connect/disconnect/forget actions and helpers for UI components (settings).
//
// Restricted networks: NetworkManager's connectivity check reports PORTAL when a
// hotspot is intercepting traffic. Quickshell exposes that state directly, so the
// shell can do what an Arch Linux Wayland dispatcher script does -- open the
// login page in the default browser -- without a root helper or DISPLAY juggling.
// Enterprise (eduroam) profiles are created by tools/wifi/aequalyn-wifi-eap over
// libnm, with the password on stdin rather than in argv.
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import QtQuick
import "root:/settings"

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

    // ---- Restricted networks: captive portals and WPA-Enterprise ----------
    // The Settings page owns the one permission switch for both: no browser is
    // opened and no enterprise profile is made until it is on.
    readonly property bool allowRestricted: !!AequalynSettings.wifiAllowRestricted
    readonly property var connectivity: Networking.connectivity
    readonly property bool portalDetected: root.connectivity === NetworkConnectivity.Portal
    // A plain HTTP address the gateway will redirect to its login page. It is
    // fixed (never taken from an untrusted network) and never contains secrets.
    readonly property string captivePortalUrl: "http://neverssl.com/"

    property bool portalHandled: false
    property string eapStatus: ""
    property string eapPending: ""

    function openCaptivePortal() {
        if (!root.allowRestricted) return false
        Quickshell.execDetached(["xdg-open", root.captivePortalUrl])
        return true
    }

    function recheckConnectivity() {
        try { Networking.checkConnectivity() } catch (e) {}
    }

    function maybeOpenPortal() {
        if (!root.allowRestricted || !root.portalDetected || root.portalHandled) return
        root.portalHandled = true
        root.openCaptivePortal()
    }

    // Open once per portal transition, whether or not the Settings page is
    // visible. The browser inherits the shell's Wayland session environment.
    property Connections portalWatch: Connections {
        target: Networking
        function onConnectivityChanged() {
            if (root.portalDetected) root.maybeOpenPortal()
            else root.portalHandled = false
        }
    }
    Component.onCompleted: root.maybeOpenPortal()

    function isEnterprise(security) {
        return security === WifiSecurityType.WpaEap || security === WifiSecurityType.Wpa2Eap
    }

    function connectWithEap(network, identity, password, caCert) {
        if (!network || !root.allowRestricted) return false
        const ssid = String(network.name || "")
        if (!ssid || !String(identity || "") || !String(password || "")) return false
        root.eapStatus = "Connecting to " + ssid + "…"
        root.eapPending = JSON.stringify({
            ssid: ssid,
            identity: String(identity),
            password: String(password),
            caCert: String(caCert || "")
        })
        root.eapProc.running = false
        root.eapProc.running = true
        return true
    }

    property Process eapProc: Process {
        id: eapProc
        // Prefer the shell's own copy; fall back to an installed helper on PATH.
        command: ["sh", "-c",
            'p="$HOME/.config/quickshell/tools/wifi/aequalyn-wifi-eap"; '
            + '[ -x "$p" ] && exec "$p" || exec aequalyn-wifi-eap']
        stdinEnabled: true
        onStarted: {
            if (root.eapPending !== "") {
                root.eapProc.write(root.eapPending)
                root.eapPending = ""
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                let res
                try { res = JSON.parse(text) } catch (e) { res = null }
                if (res && res.ok) {
                    root.eapStatus = "Connected. Checking internet access…"
                    root.recheckConnectivity()
                } else {
                    root.eapStatus = "Could not join: " + ((res && res.error) || "helper failed")
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim()) console.warn("Wi-Fi EAP:", text.trim())
        }
    }

    // ---- Network details: saved credentials and fast.com speed test -------
    property string revealedPassword: ""
    property string revealStatus: ""
    property string pendingReveal: ""

    function revealPassword(ssid) {
        if (!ssid) return false
        root.revealedPassword = ""
        root.revealStatus = "Asking for permission…"
        root.pendingReveal = JSON.stringify({ ssid: String(ssid) })
        root.revealProc.running = false
        root.revealProc.running = true
        return true
    }

    property Process revealProc: Process {
        id: revealProc
        // Stage the SSID, ask through the one root gate, then drop the staging file.
        command: ["sh", "-c",
            'd="$HOME/.local/state/aequalyn/gate"; mkdir -p "$d" && printf \'%s\' "$1" > "$d/wifi-reveal.json"; '
            + 'out=$(setsid -w aequalyn-watchdog exec-root --as settings wifi-reveal-password 2>&1); r=$?; '
            + 'rm -f "$d/wifi-reveal.json"; printf "%s" "$out"; exit $r',
            "sh", root.pendingReveal]
        stdout: StdioCollector {
            onStreamFinished: {
                let d = null
                try { d = JSON.parse(text) } catch (e) {}
                if (d && d.ok) {
                    root.revealedPassword = d.password || ""
                    root.revealStatus = ""
                } else {
                    root.revealedPassword = ""
                    root.revealStatus = (d && d.error) || "Permission denied or helper failed"
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim()) console.warn("Wi-Fi reveal:", text.trim())
        }
    }

    function updateCredentials(ssid, identity, password, caCert) {
        const net = root.networkForSsid(ssid)
        const list = net ? net.nmSettings : null
        if (!net || !list || !list.length || !password) return false
        const patch = root.isEnterprise(net.security)
            ? { "802-1x": Object.assign({ identity: String(identity || ""), password: String(password) },
                caCert ? { "ca-cert": String(caCert) } : {}) }
            : { "802-11-wireless-security": { psk: String(password) } }
        try {
            list[0].write(patch)
            net.connectWithSettings(list[0])
        } catch (e) { return false }
        return true
    }

    property real speedDownload: 0
    property real speedUpload: 0
    property string speedPhase: ""
    property bool speedRunning: false

    function runSpeedTest() {
        if (root.speedProc.running) return false
        root.speedDownload = 0
        root.speedUpload = 0
        root.speedPhase = "starting…"
        root.speedProc.running = true
        return true
    }

    function stopSpeedTest() {
        root.speedProc.running = false
        root.speedPhase = ""
    }

    property Process speedProc: Process {
        id: speedProc
        command: ["sh", "-c",
            'p="$HOME/.config/quickshell/tools/wifi/aequalyn-wifi-speed"; '
            + '[ -x "$p" ] && exec "$p" || exec aequalyn-wifi-speed']
        stdout: SplitParser {
            onRead: line => {
                let d
                try { d = JSON.parse(line) } catch (e) { return }
                if (d.phase === "download") {
                    root.speedPhase = "download"
                    root.speedDownload = Number(d.mbps) || 0
                } else if (d.phase === "upload") {
                    root.speedPhase = "upload"
                    root.speedUpload = Number(d.mbps) || 0
                } else if (d.ok) {
                    root.speedPhase = "done"
                    root.speedDownload = Number(d.download) || 0
                    root.speedUpload = Number(d.upload) || 0
                } else if (d.error) {
                    root.speedPhase = "error: " + d.error
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim()) console.warn("Wi-Fi speed:", text.trim())
        }
        onRunningChanged: root.speedRunning = running
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
