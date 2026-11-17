// The built-in pack's link to its running plugins: each one registers here while it
// runs, so the control center's Everyday tools page and the bar widgets find it
// (`KitHost.get("weather")`), and nothing has to search. A plugin that is off is not
// here: everything that asks checks for null.
pragma Singleton

import QtQuick
import Quickshell
import "root:/settings/center"

Singleton {
    id: host
    property var running: ({})

    function register(id, svc) {
        const n = Object.assign({}, host.running)
        n[id] = svc
        host.running = n
    }
    function unregister(id, svc) {
        if (host.running[id] !== svc) return
        const n = Object.assign({}, host.running)
        delete n[id]
        host.running = n
    }
    function get(id) { return host.running[id] || null }
    function openSettings() { Cc.go("tools") }

    // a short message in the corner, through the shell's notifications
    function notify(title, body) { Quickshell.execDetached(["notify-send", "-a", "Aequalyn", String(title), String(body || "")]) }
    // something into the clipboard
    function copy(text) { Quickshell.execDetached(["wl-copy", "--", String(text)]) }
}
