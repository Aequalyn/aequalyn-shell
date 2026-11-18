// Emoji (Super + .): every emoji (Emojis.js, made from Unicode's list by
// tools/emoji-list.py), as a grid by category: Recent, Smileys, People, Nature, Food,
// Travel, Activities, Objects, Symbols and Flags. Typing searches them all; the arrows
// move, Tab goes to the next category, Enter copies it, ready to paste. The line under
// the grid names the one you are on.
import QtQuick
import Quickshell
import Quickshell.Io
import "root:/plugins/kit"
import "Emojis.js" as Emojis

Scope {
    id: root
    property var theme: null
    KitStore { id: store; pluginId: "emoji"; defaults: ({ recent: [], category: "" }) }
    readonly property var recent: Array.isArray(store.get("recent")) ? store.get("recent") : []
    // the category shown: the one you chose last; Recent while you have some, else Smileys
    readonly property string category: {
        const c = String(store.get("category") || "")
        if (c === "recent" && root.recent.length === 0) return "smileys"
        return c !== "" ? c : (root.recent.length > 0 ? "recent" : "smileys")
    }

    function tile(e) { return { glyph: e[0], title: e[1], sub: e[2], value: e[0] } }

    KitPanel {
        id: panel
        theme: root.theme
        name: "emoji"
        icon: "\u{F0785}"
        placeholder: "Search all emoji, like smile, heart or rocket"
        // wide and tall enough to show most of a category at once; the rest scroll
        panelWidth: 800
        panelHeight: 720
        columns: 14
        emptyText: "No emoji by that name"
        chips: (root.recent.length > 0 ? [{ key: "recent", label: "\u{F02DA}  Recent" }] : [])
            .concat(Emojis.categories.map(c => ({ key: c.key, label: c.glyph + "  " + c.label })))
        chip: panel.query.trim() === "" ? root.category : ""
        onChipChosen: key => { panel.query = ""; store.set("category", key); panel.current = 0 }
        countText: panel.query.trim() !== "" ? panel.items.length + " found in every category"
            : panel.items.length + " emoji"
        items: {
            const q = panel.query.trim().toLowerCase()
            const all = Emojis.list
            if (q !== "") {
                // every word somewhere in its name or the words it is known by
                const words = q.split(/\s+/)
                return all.filter(e => {
                    const hay = e[1] + " " + e[2]
                    return words.every(w => hay.indexOf(w) >= 0)
                }).sort((a, b) => (a[1].indexOf(words[0]) === 0 ? 0 : 1) - (b[1].indexOf(words[0]) === 0 ? 0 : 1)).map(root.tile)
            }
            if (root.category === "recent")
                return root.recent.map(c => all.find(e => e[0] === c)).filter(x => !!x).map(root.tile)
            return all.filter(e => e[3] === root.category).map(root.tile)
        }
        hints: [["← ↑ ↓ →", "move"], ["Tab", "category"], ["Enter", "copy"], ["Esc", "close"]]
        onActivated: (item) => {
            if (!item) return
            KitHost.copy(item.value)
            store.set("recent", [item.value].concat(root.recent.filter(c => c !== item.value)).slice(0, 42))
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
