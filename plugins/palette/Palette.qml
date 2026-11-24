// Command palette (Super + Shift + Space): everything in one search. Every control
// center page and what it sets, every plugin to switch on or off, and things to do
// now (lock, a new wallpaper, do not disturb...). Type a few letters, Enter.
import QtQuick
import Quickshell
import Quickshell.Io
import "root:/plugins/kit"
import "root:/settings"
import "root:/settings/center"
import "../../settings/center/Pages.js" as Pages
import "../../Plugins.js" as PluginRegistry
import "../../PluginInfo.js" as PluginInfo

Scope {
    id: root
    property var theme: null

    readonly property var actions: [
        { icon: "\u{F033E}", title: "Lock the screen", sub: "Action", cmd: ["aequalyn-lock", "lock"] },
        { icon: "\u{F0E09}", title: "Next wallpaper", sub: "Action", cmd: ["aequalyn-wallpaper", "next"] },
        { icon: "\u{F009B}", title: "Do not disturb on or off", sub: "Action", cmd: ["qs", "ipc", "call", "notifications", "dnd_toggle"] },
        { icon: "\u{F0A20}", title: "Clear notifications", sub: "Action", cmd: ["qs", "ipc", "call", "notifications", "dismiss_all"] },
        { icon: "\u{F018D}", title: "Open a terminal", sub: "Action", cmd: ["kitty"] },
        { icon: "\u{F03D8}", title: "Pick a theme", sub: "Action", cmd: ["qs", "ipc", "call", "atelier", "open", "themes"] },
        { icon: "\u{F0E09}", title: "Pick a wallpaper", sub: "Action", cmd: ["qs", "ipc", "call", "atelier", "open", "wallpapers"] },
        { icon: "\u{F0570}", title: "Next window layout", sub: "Action", cmd: ["aequalyn-layout", "next"] },
        { icon: "\u{F0425}", title: "Power menu", sub: "Action", cmd: ["qs", "ipc", "call", "power", "toggle"] }
    ]
    // every page, and each thing it sets
    readonly property var pageItems: {
        const out = []
        for (const id of Pages.order) {
            const p = Pages.pages[id]
            if (!p) continue
            out.push({ icon: p.icon, title: p.label, sub: "Settings", page: id, words: (p.also || "") })
            for (const w of (p.words || [])) out.push({ icon: p.icon, title: w, sub: "Settings › " + p.label, page: id, words: "" })
        }
        return out
    }
    readonly property var pluginItems: PluginRegistry.list.filter(p => p.id !== "settings").map(p => {
        const on = AequalynSettings.enabledPlugins.indexOf(p.id) >= 0
        return { icon: PluginInfo.of(p.id).icon, title: (on ? "Turn off " : "Turn on ") + p.label, sub: "Plugin · " + (on ? "on" : "off"),
                 plugin: p.id, on: on, words: PluginInfo.of(p.id).about }
    })
    function score(item, q) {
        const t = item.title.toLowerCase()
        if (t.indexOf(q) === 0) return 3
        if (t.indexOf(q) >= 0) return 2
        if ((item.words + " " + item.sub).toLowerCase().indexOf(q) >= 0) return 1
        return 0
    }

    KitPanel {
        id: panel
        theme: root.theme
        name: "palette"
        icon: "\u{F0349}"
        placeholder: "A setting, a plugin, or something to do"
        panelWidth: 700
        panelHeight: 520
        emptyText: "Nothing matches"
        items: {
            const q = panel.query.trim().toLowerCase()
            const all = root.actions.map(a => Object.assign({ words: "" }, a)).concat(root.pluginItems, root.pageItems)
            if (q === "") return root.actions.concat(root.pageItems.filter(p => p.sub === "Settings")).slice(0, 40)
            return all.map(it => ({ it: it, s: root.score(it, q) })).filter(x => x.s > 0)
                .sort((a, b) => b.s - a.s).slice(0, 40).map(x => x.it)
        }
        hints: [["Enter", "do it"], ["↑ ↓", "move"], ["Esc", "close"]]
        onActivated: (item) => {
            if (!item) return
            panel.open = false
            if (item.cmd) Quickshell.execDetached(item.cmd)
            else if (item.plugin) AequalynSettings.togglePlugin(item.plugin, !item.on)
            else if (item.page) Cc.go(item.page)
        }
    }
    IpcHandler {
        target: "palette"
        function toggle(): void { panel.toggle() }
    }
    Component.onCompleted: KitHost.register("palette", root)
    Component.onDestruction: KitHost.unregister("palette", root)
}
