// Disk watch: a message when a disk is nearly full (less than a tenth free at first),
// before apps start failing to save. Once, until it has room again.
import QtQuick
import Quickshell
import Quickshell.Io
import "root:/plugins/kit"

Scope {
    id: root
    property var theme: null
    KitStore { id: store; pluginId: "diskWatch"; defaults: ({ percent: 10 }) }
    readonly property var settingsStore: store      // for the Everyday tools page
    property var told: ({})
    property var disks: []
    KitRun {
        id: reader
        seconds: 10
        onDone: (code, out) => {
            const lim = Number(store.get("percent"))
            const list = String(out).trim().split("\n").slice(1).map(l => l.trim().split(/\s+/))
                .filter(f => f.length >= 6 && /^\/($|home$|boot$|var$)/.test(f[5]))
                .map(f => ({ mount: f[5], free: 100 - parseInt(f[4]), avail: Number(f[3]) }))
            root.disks = list
            const t = Object.assign({}, root.told)
            for (const d of list) {
                if (d.free < lim && !t[d.mount]) {
                    t[d.mount] = true
                    KitHost.notify("Disk nearly full", d.mount + " has " + d.free + "% free (" + Math.round(d.avail / 1048576 * 10) / 10 + " GB).")
                } else if (d.free >= lim + 2) t[d.mount] = false
            }
            root.told = t
        }
    }
    Timer { interval: 10 * 60000; repeat: true; running: true; triggeredOnStart: true; onTriggered: reader.start(["df", "-P", "-k"]) }
    IpcHandler {
        target: "diskWatch"
        function status(): string { return root.disks.map(d => d.mount + " " + d.free + "% free").join(", ") }
    }
    Component.onCompleted: KitHost.register("diskWatch", root)
    Component.onDestruction: KitHost.unregister("diskWatch", root)
}
