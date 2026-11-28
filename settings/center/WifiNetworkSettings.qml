// A saved network's own settings, under its details on the Wi-Fi page, as KDE's network
// settings have them: join it by itself and how eagerly, metered, every account or only
// yours, its addresses and DNS, and (under More) the band, the MAC address the network
// sees, IPv6 and the MTU; while connected, what it has now. Read and written by
// tools/wifi/aequalyn-wifi-profile (nmcli, as you), which checks every value first.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "root:/settings"

CcSection {
    id: box
    property string ssid: ""
    title: "Settings for this network"
    hint: "Kept with the network on this machine. Addresses, the band and the MAC address count from the next connection: it reconnects at once."

    property var info: ({})
    property string status: ""
    readonly property bool ready: box.info.saved === true
    readonly property var live: box.info.live || null
    readonly property string tool: Quickshell.env("HOME") + "/.config/quickshell/tools/wifi/aequalyn-wifi-profile"

    function load() {
        if (box.ssid === "") return
        reader.exec({ command: ["python3", box.tool, "show", box.ssid] })
    }
    function put(key, values) {
        box.status = "Saving…"
        writer.exec({ command: ["python3", box.tool, "set", box.ssid, key].concat(values) })
    }
    onSsidChanged: { box.info = ({}); box.status = ""; box.load() }
    Component.onCompleted: box.load()
    // the live part (signal, rate) moves: read it again now and then while it shows
    Timer { interval: 8000; repeat: true; running: box.visible && !!box.live; onTriggered: box.load() }

    Process {
        id: reader
        stdout: StdioCollector {
            onStreamFinished: {
                try { box.info = JSON.parse(text) } catch (e) { box.info = ({}) }
                // the fields show what is saved, unless something is being typed there
                if (!address.activeFocus) address.text = box.info.address || ""
                if (!gateway.activeFocus) gateway.text = box.info.gateway || ""
                if (!dns.activeFocus) dns.text = box.info.dns || ""
                if (!priority.activeFocus) priority.text = box.info.priority !== undefined ? String(box.info.priority) : ""
                if (!mtu.activeFocus) mtu.text = box.info.mtu && box.info.mtu !== "auto" && box.info.mtu !== "0" ? box.info.mtu : ""
            }
        }
    }
    Process {
        id: writer
        stdout: StdioCollector {
            onStreamFinished: {
                let r = {}
                try { r = JSON.parse(text) } catch (e) { r = { ok: false, error: "no answer" } }
                box.status = r.ok ? "Saved." : (r.error || "Not saved.")
                box.load()
            }
        }
    }

    component Label: Text {
        Layout.preferredWidth: 150
        color: Cc.theme.textPrimary
        font.family: Cc.sans
        font.pixelSize: 12
        elide: Text.ElideRight
    }
    component Line: RowLayout {
        Layout.fillWidth: true
        spacing: 10
    }

    CcNote { visible: !box.ready; text: box.info.ok === false ? (box.info.error || "Could not read it.") : "Reading…" }

    // what it has now
    CcNote {
        visible: box.ready && !!box.live
        text: !box.live ? "" : [
            "Connected now",
            box.live.ip4 && box.live.ip4.length ? "IPv4 " + box.live.ip4.join(", ") : "",
            box.live.gateway4 ? "gateway " + box.live.gateway4 : "",
            box.live.dns4 && box.live.dns4.length ? "DNS " + box.live.dns4.join(", ") : "",
            box.live.ip6 && box.live.ip6.length ? "IPv6 " + box.live.ip6[0] : "",
            box.live.freq ? box.live.freq + (box.live.channel ? ", channel " + box.live.channel : "") : "",
            box.live.rate ? box.live.rate : "",
            box.live.signal ? "signal " + box.live.signal + "%" : "",
            box.live.security ? box.live.security : "",
            box.live.bssid ? "access point " + box.live.bssid : "",
            box.live.hwaddr ? "this machine " + box.live.hwaddr : ""
        ].filter(s => s !== "").join("  ·  ")
    }

    CcToggle {
        visible: box.ready
        title: "Connect automatically"
        sub: "Join it by itself whenever it is near."
        checked: !!box.info.autoconnect
        onToggled: v => box.put("autoconnect", [v ? "yes" : "no"])
    }
    CcToggle {
        visible: box.ready
        title: "Every account on this machine"
        sub: "Off: only yours may use it."
        checked: !!box.info.allUsers
        onToggled: v => box.put("all-users", [v ? "yes" : "no"])
    }
    CcToggle {
        visible: box.ready
        title: "It hides its name"
        sub: "A network that does not announce itself; it is looked for by name."
        checked: !!box.info.hidden
        onToggled: v => box.put("hidden", [v ? "yes" : "no"])
    }
    Line {
        visible: box.ready
        Label { text: "Metered" }
        CcChoice {
            Layout.fillWidth: true
            options: [{ key: "unknown", label: "Find out" }, { key: "yes", label: "Yes" }, { key: "no", label: "No" }]
            current: box.info.metered || "unknown"
            onChosen: k => box.put("metered", [k])
        }
    }
    Line {
        visible: box.ready
        Label { text: "Priority" }
        CcField { id: priority; Layout.fillWidth: true; placeholder: "0: higher wins when several are near"; onAccepted: box.put("priority", [priority.text]) }
        CcButton { text: "Set"; onClicked: box.put("priority", [priority.text]) }
    }
    Line {
        visible: box.ready
        Label { text: "IPv4 address" }
        CcChoice {
            Layout.fillWidth: true
            options: [{ key: "auto", label: "Automatic (DHCP)" }, { key: "manual", label: "Fixed" }]
            current: box.info.ipv4 || "auto"
            onChosen: k => { if (k === "auto") box.put("ipv4", ["auto"]); else box.info = Object.assign({}, box.info, { ipv4: "manual" }) }
        }
    }
    Line {
        visible: box.ready && box.info.ipv4 === "manual"
        CcField { id: address; Layout.fillWidth: true; placeholder: "Address, like 192.168.1.20/24" }
        CcField { id: gateway; Layout.fillWidth: true; placeholder: "Gateway, like 192.168.1.1" }
        CcButton { text: "Apply"; primary: true; onClicked: box.put("ipv4", [address.text.trim(), gateway.text.trim()]) }
    }
    Line {
        visible: box.ready
        Label { text: "DNS servers" }
        CcField { id: dns; Layout.fillWidth: true; placeholder: "Automatic, or like 1.1.1.1, 9.9.9.9"; onAccepted: box.put("dns", [dns.text.trim() || "auto"]) }
        CcButton { text: "Apply"; onClicked: box.put("dns", [dns.text.trim() || "auto"]) }
    }
    CcMore {
        visible: box.ready
        title: "Band, MAC address, IPv6 and MTU"
        Line {
            Label { text: "Band" }
            CcChoice {
                Layout.fillWidth: true
                options: [{ key: "any", label: "Any" }, { key: "2.4", label: "2.4 GHz" }, { key: "5", label: "5 GHz" }]
                current: box.info.band || "any"
                onChosen: k => box.put("band", [k])
            }
        }
        Line {
            Label { text: "MAC address" }
            CcChoice {
                Layout.fillWidth: true
                options: [{ key: "default", label: "System" }, { key: "permanent", label: "The card's own" },
                          { key: "random", label: "New each time" }, { key: "stable", label: "Its own for this network" }]
                current: box.info.mac || "default"
                onChosen: k => box.put("mac", [k])
            }
        }
        Line {
            Label { text: "IPv6" }
            CcChoice {
                Layout.fillWidth: true
                options: [{ key: "auto", label: "Automatic" }, { key: "off", label: "Off" }]
                current: box.info.ipv6 || "auto"
                onChosen: k => box.put("ipv6", [k])
            }
        }
        Line {
            Label { text: "MTU" }
            CcField { id: mtu; Layout.fillWidth: true; placeholder: "Automatic, or 576 to 9000"; onAccepted: box.put("mtu", [mtu.text.trim() || "auto"]) }
            CcButton { text: "Set"; onClicked: box.put("mtu", [mtu.text.trim() || "auto"]) }
        }
    }
    CcNote { visible: box.status !== ""; text: box.status }
}
