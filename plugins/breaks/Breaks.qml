// Break reminder: every so often (20 minutes at first), a message to look away for
// twenty seconds at something far off: the 20-20-20 rule against tired eyes. Quiet
// while the screen is locked or you are away.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "root:/plugins/kit"

Scope {
    id: root
    property var theme: null
    KitStore { id: store; pluginId: "breaks"; defaults: ({ minutes: 20 }) }
    readonly property var settingsStore: store      // for its settings on the Plugins page
    property double next: Date.now() + 20 * 60000
    function reset() { root.next = Date.now() + Math.max(5, Number(store.get("minutes"))) * 60000 }
    Connections { target: store; function onLoadedChanged() { root.reset() } function onValuesChanged() { root.reset() } }
    // away: nothing typed or moved for two minutes starts the count again
    IdleMonitor {
        id: idle
        timeout: 120
        onIsIdleChanged: if (!isIdle) root.reset()
    }
    Timer {
        interval: 30000
        repeat: true
        running: true
        onTriggered: {
            if (idle.isIdle) return
            if (Date.now() >= root.next) {
                KitHost.notify("Rest your eyes", "Look at something far away for twenty seconds.")
                root.reset()
            }
        }
    }
    IpcHandler {
        target: "breaks"
        function next(): string { return Math.max(0, Math.round((root.next - Date.now()) / 60000)) + " min" }
    }
    Component.onCompleted: KitHost.register("breaks", root)
    Component.onDestruction: KitHost.unregister("breaks", root)
}
