// Battery guard: a message when the battery runs low, again when it is nearly empty,
// and, if you like, when it is full while charging. Once each time, not over and over.
import QtQuick
import Quickshell
import Quickshell.Io
import "root:/plugins/kit"

Scope {
    id: root
    property var theme: null
    KitStore { id: store; pluginId: "batteryGuard"; defaults: ({ low: 20, critical: 10, full: true }) }
    readonly property var settingsStore: store      // for its settings on the Plugins page
    property string told: ""             // the last thing it told: "", "low", "critical", "full"
    property int level: -1
    property string status: ""
    KitRun {
        id: reader
        seconds: 3
        onDone: (code, out) => {
            const l = String(out).trim().split("\n")
            if (code !== 0 || l.length < 2) { root.level = -1; return }
            root.level = parseInt(l[0]); root.status = l[1]
            const charging = root.status === "Charging" || root.status === "Full"
            const low = Number(store.get("low")), crit = Number(store.get("critical"))
            if (!charging && root.level <= crit && root.told !== "critical") { root.told = "critical"; KitHost.notify("Battery nearly empty", root.level + "% left. Plug in now.") }
            else if (!charging && root.level <= low && root.level > crit && root.told === "") { root.told = "low"; KitHost.notify("Battery low", root.level + "% left.") }
            else if (charging && root.level >= 100 && store.get("full") && root.told !== "full") { root.told = "full"; KitHost.notify("Battery full", "You can unplug the charger.") }
            else if (charging && root.level < 100 && root.told !== "") root.told = ""
            else if (!charging && root.level > low && root.told === "full") root.told = ""
        }
    }
    Timer {
        interval: 60000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: reader.start(["sh", "-c", 'for b in /sys/class/power_supply/BAT*; do [ -r "$b/capacity" ] && cat "$b/capacity" "$b/status" && exit 0; done; exit 1'])
    }
    IpcHandler {
        target: "batteryGuard"
        function status(): string { return root.level < 0 ? "no battery" : root.level + "% " + root.status }
    }
    Component.onCompleted: KitHost.register("batteryGuard", root)
    Component.onDestruction: KitHost.unregister("batteryGuard", root)
}
