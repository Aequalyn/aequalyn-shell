// Emoji (Super + .): a grid of emoji; type a name to narrow it, the arrows move, Enter
// copies it, ready to paste. The ones you used last come first; the line under the
// grid names the one you are on.
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
        // wide and tall enough to show most of them at once; the rest scroll
        panelWidth: 800
        panelHeight: 700
        columns: 14
        emptyText: "No emoji by that name"
        countText: panel.items.length + " emoji"
        items: {
            const q = panel.query.trim().toLowerCase()
            const all = Emojis.list
            const hit = q === "" ? root.recent.map(c => all.find(e => e[0] === c)).filter(x => !!x).concat(all.filter(e => root.recent.indexOf(e[0]) < 0))
                : all.filter(e => e[1].indexOf(q) >= 0)
            return hit.map(e => ({ glyph: e[0], title: e[1].split(" ")[0], sub: e[1].split(" ").slice(1).join(" "), value: e[0] }))
        }
        hints: [["← ↑ ↓ →", "move"], ["Enter", "copy"], ["Esc", "close"]]
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
