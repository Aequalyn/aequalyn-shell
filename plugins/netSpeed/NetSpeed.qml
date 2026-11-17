// Network speed: how fast things come in and go out right now, on the bar's network
// speed widget. Read from the kernel's counters every two seconds.
import QtQuick
import Quickshell
import Quickshell.Io
import "root:/plugins/kit"

Scope {
    id: root
    property var theme: null
    property double down: 0              // bytes a second
    property double up: 0
    property var last: null
    function human(b) {
        if (b >= 1048576) return (b / 1048576).toFixed(1) + " MB/s"
        if (b >= 1024) return Math.round(b / 1024) + " KB/s"
        return Math.round(b) + " B/s"
    }
    readonly property string label: "↓ " + human(down) + "  ↑ " + human(up)
    FileView { id: dev; path: "/proc/net/dev"; printErrors: false }
    Timer {
        interval: 2000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            dev.reload()
            let rx = 0, tx = 0
            for (const l of String(dev.text()).split("\n").slice(2)) {
                const m = l.trim().match(/^([^:]+):\s*(.*)$/)
                if (!m || m[1] === "lo") continue
                const f = m[2].trim().split(/\s+/).map(Number)
                rx += f[0] || 0; tx += f[8] || 0
            }
            const t = Date.now()
            if (root.last) {
                const dt = Math.max(0.5, (t - root.last.t) / 1000)
                root.down = Math.max(0, (rx - root.last.rx) / dt)
                root.up = Math.max(0, (tx - root.last.tx) / dt)
            }
            root.last = { rx: rx, tx: tx, t: t }
        }
    }
    IpcHandler {
        target: "netSpeed"
        function now(): string { return root.label }
    }
    Component.onCompleted: KitHost.register("netSpeed", root)
    Component.onDestruction: KitHost.unregister("netSpeed", root)
}
