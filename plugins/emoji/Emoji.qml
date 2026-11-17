// Emoji (Super + .): find one by name, Enter copies it, ready to paste. The ones you
// used last come first.
import QtQuick
import Quickshell
import Quickshell.Io
import "root:/plugins/kit"
import "Emojis.js" as Emojis

Scope {
    id: root
    property var theme: null
    KitStore { id: store; pluginId: "emoji"; defaults: ({ recent: [] }) }
    readonly property var recent: Array.isArray(store.get("recent")) ? store.get("recent") : []

    KitPanel {
        id: panel
        theme: root.theme
        name: "emoji"
        icon: "\u{F0785}"
        placeholder: "A name, like smile, heart or rocket"
        panelHeight: 460
        emptyText: "No emoji by that name"
        items: {
            const q = panel.query.trim().toLowerCase()
            const all = Emojis.list
            const hit = q === "" ? root.recent.map(c => all.find(e => e[0] === c)).filter(x => !!x).concat(all.filter(e => root.recent.indexOf(e[0]) < 0))
                : all.filter(e => e[1].indexOf(q) >= 0)
            return hit.slice(0, 80).map(e => ({ title: e[0] + "   " + e[1].split(" ")[0], sub: e[1], value: e[0] }))
        }
        hints: [["Enter", "copy"], ["↑ ↓", "move"], ["Esc", "close"]]
        onActivated: (item) => {
            if (!item) return
            KitHost.copy(item.value)
            store.set("recent", [item.value].concat(root.recent.filter(c => c !== item.value)).slice(0, 16))
            panel.open = false
        }
    }
    IpcHandler {
        target: "emoji"
        function toggle(): void { panel.toggle() }
    }
    Component.onCompleted: KitHost.register("emoji", root)
    Component.onDestruction: KitHost.unregister("emoji", root)
}
