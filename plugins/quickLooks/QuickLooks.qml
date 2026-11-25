// Quick looks: one small panel for the bar (Super + Ctrl + B), the docks (Super + Ctrl + D),
// the lock screen (Super + Ctrl + K), the login screen (Super + Ctrl + G), the cursor
// (Super + Ctrl + C), Showcase's widgets (Super + Ctrl + W) and one look for all of them
// (Super + Ctrl + M), to switch how each one looks without opening Settings. Tab goes through what can be changed, typing
// finds it, Enter puts it on at once and the panel stays, so several can be tried; Esc
// closes. Alt + 1 to 7 go from one to another. The login screen is the system's: it asks first.
import QtQuick
import Quickshell
import Quickshell.Io
import "root:/plugins/kit"
import "root:/plugins/atelier"
import "root:/plugins/plume"
import "root:/plugins/plume/js/Schema.js" as PlumeSchema
import "root:/plugins/showcase/qml/js/Schema.js" as ShowSchema
import "root:/settings"
import "../../style/AequalynLooks.js" as Looks
import "../../style/BarLooks.js" as BarLooks
import "../../settings/center/LockDesigns.js" as LockDesigns

Scope {
    id: root
    property var theme: null
    property string mode: "bar"                  // bar | dock | lock | login | cursor | showcase | all
    property var parts: ({ bar: "looks", dock: "looks", lock: "designs", login: "themes", cursor: "looks", showcase: "looks", all: "lead" })
    readonly property string part: root.parts[root.mode]
    property int dock: 0                         // which dock the choices go to; -1 for all
    property var loginThemes: []
    property string loginNow: ""

    readonly property var modes: ["bar", "dock", "lock", "login", "cursor", "showcase", "all"]
    readonly property var titles: ({ bar: "Bar", dock: "Docks", lock: "Lock screen", login: "Login screen", cursor: "Cursor", showcase: "Showcase", all: "One look everywhere" })
    readonly property var icons: ({ bar: "\u{F10AB}", dock: "\u{F10A9}", lock: "\u{F033E}", login: "\u{F0343}", cursor: "\u{F01C0}", showcase: "\u{F0E6B}", all: "\u{F03D8}" })
    readonly property var svc: AtelierHost.docks
    readonly property var plume: PlumeHost.svc
    readonly property var showcase: KitHost.get("showcase")
    // what the cursor and Showcase can follow, as their own settings have it
    function sameRows(cfg) {
        return [{ key: "bar", title: "Same as the bar" }, { key: "dock", title: "Same as the dock" }].map(x => ({ icon: root.icons[x.key],
            title: x.title, sub: "Shape, surface, lines and colours of the " + x.key + ", live", key: "follow:" + x.key,
            now: cfg.followStyle === x.key && cfg.followColors === x.key }))
    }
    function followRows(schema, key, cfg) {
        const it = schema[key]
        return it.options.map(o => ({ icon: root.icons[root.mode], title: it.labels[o],
            sub: o === "own" ? "What you set yourself" : (key === "followColors" ? (o === "theme" ? "The theme's colours, live" : "The colours the " + o + " has, live")
                                                                                 : "The shape, surface, lines and ornaments of the " + o + ", live"),
            key: o, now: cfg[key] === o }))
    }
    readonly property var docks: root.svc ? root.svc.docks : []
    readonly property int dockIndex: root.dock < 0 ? 0 : Math.min(root.dock, Math.max(0, root.docks.length - 1))

    readonly property var chips: {
        if (root.mode === "bar") return [{ key: "looks", label: "Look" }, { key: "position", label: "Position" },
            { key: "sets", label: "Bar and docks" }, { key: "colours", label: "Colours" }]
        if (root.mode === "dock") return [{ key: "looks", label: "Look" }, { key: "position", label: "Position" },
            { key: "which", label: "Which dock" }, { key: "colours", label: "Colours" }]
        if (root.mode === "lock") return [{ key: "designs", label: "Design" }, { key: "colours", label: "Colours" }]
        if (root.mode === "cursor") return [{ key: "looks", label: "Cursor" }, { key: "trail", label: "Trail and halo" },
            { key: "followStyle", label: "Follow shape" }, { key: "followColors", label: "Follow colours" }]
        if (root.mode === "showcase") return [{ key: "looks", label: "Look" }, { key: "font", label: "Font" },
            { key: "followStyle", label: "Follow shape" }, { key: "followColors", label: "Follow colours" }]
        if (root.mode === "all") return [{ key: "lead", label: "Follow" }, { key: "parts", label: "What joins" }, { key: "perTheme", label: "Each theme" }]
        return [{ key: "themes", label: "Theme" }]
    }
    readonly property var edges: [
        { key: "top", label: "Top", icon: "\u{F0143}" }, { key: "bottom", label: "Bottom", icon: "\u{F0140}" },
        { key: "left", label: "Left", icon: "\u{F0141}" }, { key: "right", label: "Right", icon: "\u{F0142}" }
    ]
    readonly property var rows: {
        const look = (x, now) => ({ icon: root.icons[root.mode], title: x.label, sub: x.about || "", key: x.key, now: x.key === now })
        switch (root.mode + "." + root.part) {
        case "bar.looks": {
            const now = BarLooks.lookOf(AequalynSettings.barStyleCfg)
            return Looks.bar.map(x => look(x, now))
        }
        case "bar.position":
            return root.edges.map(e => ({ icon: e.icon, title: e.label, sub: "The bar at the " + e.key + " of the screen", key: e.key,
                                          now: e.key === AequalynSettings.barPosition }))
        case "bar.sets": {
            const now = root.svc ? root.svc.ensembleOf() : ""
            return Looks.ensembles.map(x => look(x, now))
        }
        case "dock.looks": {
            const d = root.docks[root.dockIndex]
            const now = d && !d.followBar ? Looks.dockLookOf(d) : ""
            return (d ? [{ icon: root.icons.bar, title: "Same as the bar", sub: "Follows whatever the bar wears", key: "", now: d.followBar }] : [])
                .concat(d ? Looks.dock.map(x => look(x, now)) : [])
        }
        case "dock.position": {
            const d = root.docks[root.dockIndex]
            return d ? root.edges.map(e => ({ icon: e.icon, title: e.label, sub: "The dock at the " + e.key + " of the screen", key: e.key, now: e.key === d.edge })) : []
        }
        case "dock.which":
            return root.docks.length === 0 ? []
                : [{ icon: root.icons.dock, title: "All docks", sub: "Looks go to every dock", key: -1, now: root.dock < 0 }]
                    .concat(root.docks.map((d, i) => ({ icon: root.icons.dock, title: "Dock " + (i + 1),
                        sub: d.edge + (d.monitor ? " of " + d.monitor : "") + ", " + d.apps.length + " apps", key: i, now: i === root.dock })))
        case "lock.designs":
            return LockDesigns.list.map(x => look(x, AequalynSettings.lockStyle))
        case "login.themes":
            return root.loginThemes.map(n => ({ icon: root.icons.login, title: n, sub: "", key: n, now: n === root.loginNow }))
        }
        if (root.mode === "cursor") {
            if (!root.plume) return []
            if (root.part === "followStyle" || root.part === "followColors") return root.followRows(PlumeSchema.byKey, root.part, root.plume.cfg)
            if (root.part === "trail") {
                const now = PlumeSchema.lookNow(root.plume.cfg)
                return PlumeSchema.looks.map(x => look(x, now))
            }
            const now = root.plume.cfg.followStyle === "own" && KitFollow.ledBy("cursor") === "" ? PlumeSchema.cursorLookNow(root.plume.cfg) : ""
            return root.sameRows(root.plume.cfg).concat(PlumeSchema.cursorLooks.map(x => look(x, now)))
        }
        if (root.mode === "showcase") {
            if (!root.showcase) return []
            const cfg = root.showcase.cfg
            if (root.part === "followStyle" || root.part === "followColors") return root.followRows(ShowSchema.itemByKey, root.part, cfg)
            if (root.part === "font") {
                const it = ShowSchema.itemByKey.font
                const all = it.options.indexOf(cfg.font) >= 0 ? it.options : it.options.concat([cfg.font])
                return all.map(f => ({ icon: "\u{F031C}", title: it.labels[f] || f, key: f, now: cfg.font === f,
                    sub: f === "" ? AequalynSettings.uiFont + ", from the Text page" : (f === ShowSchema.MONO_FONT ? AequalynSettings.monoFont + ", from the Text page" : "") }))
            }
            return root.sameRows(cfg).concat(ShowSchema.presets.map(x => look(x, cfg.lastLook)))
        }
        if (root.mode === "all") {
            const m = AequalynSettings.matchCfg
            const row = (key, title, sub, now) => ({ icon: root.icons[key] || root.icons.all, title: title, sub: sub, key: key, now: now })
            if (root.part === "lead") return [row("off", "Everyone their own look", "The bar, docks, Showcase and cursor as you set each one", !m.on),
                row("last", "Whichever I change last", "Pick a look for any of them and the others take it", m.on && m.lead === "last")]
                .concat([["bar", "The bar"], ["dock", "The dock"], ["showcase", "Showcase's cards"], ["cursor", "The cursor"]].map(x =>
                    row(x[0], x[1], "The others always take their look from it", m.on && m.lead === x[0])))
            if (root.part === "parts") return [["bar", "Bar", "Its shape, surface, lines and ornaments"], ["dock", "Docks", "Every dock"],
                ["showcase", "Showcase", "The cards of its widgets"], ["cursor", "Cursor", "The cursor made in Plume"],
                ["text", "Text", "One font: Showcase in the UI font, or the UI font in Showcase's"], ["colors", "Colours", "Their colours too, not only their look"]]
                .map(x => row(x[0], x[1], x[2], m[x[0]]))
            return [row("off", "The same look with every theme", "A theme brings its colours and wallpapers only", m.perTheme === "off"),
                row("remember", "Each theme its own look", "A theme brings back the look you last wore with it", m.perTheme === "remember"),
                row("auto", "Each theme its own, picked for new ones", "And a ready-made look the first time a theme is worn", m.perTheme === "auto")]
        }
        // colours: the wallpaper's, or a theme's, for the bar, the docks and the lock alike
        const t = root.theme
        const wall = !!t && t.currentFolderId === ""
        return [{ icon: "\u{F02E9}", title: "The wallpaper's", sub: "Colours made from your wallpaper", key: "", now: wall }]
            .concat((t && t.folderThemes ? t.folderThemes : []).map(x => ({ icon: "\u{F03D8}", title: x.name || x.id, sub: "Theme",
                key: x.id, swatch: x.accent || "", now: t.currentFolderId === x.id })))
    }

    function show(m) {
        root.mode = m
        panel.query = ""
        panel.open = true
        if (m === "login") loginProc.running = true
        Qt.callLater(root.toCurrent)
    }
    function toggle(m) {
        if (panel.open && root.mode === m) panel.open = false
        else root.show(m)
    }
    function toCurrent() { panel.current = Math.max(0, panel.items.findIndex(x => x.now)) }
    function setPart(key) {
        const p = Object.assign({}, root.parts)
        p[root.mode] = key
        root.parts = p
        panel.query = ""
        Qt.callLater(root.toCurrent)
    }
    // the bar's or the dock's look and colours in one, and off again
    function follow(svc, set, which) {
        const off = svc.cfg.followStyle === which && svc.cfg.followColors === which
        svc[set]("followStyle", off ? "own" : which)
        svc[set]("followColors", off ? "own" : which)
    }
    function use(it) {
        if (!it) return
        switch (root.mode + "." + root.part) {
        case "bar.looks":
            AequalynSettings.setBarStyle(Object.assign(BarLooks.withLook(AequalynSettings.barStyleCfg, it.key),
                { enabled: true, chips: AequalynSettings.barStyleCfg.chips }))
            return
        case "bar.position":
            AequalynSettings.barPosition = it.key
            AequalynSettings.save()
            return
        case "bar.sets": if (root.svc) root.svc.applyEnsemble(it.key); return
        case "dock.looks":
            if (!root.svc) return
            if (it.key === "") root.svc.setFollow(root.dockIndex, true, root.dock < 0 ? "all" : "one")
            else root.svc.applyLook(root.dockIndex, it.key, root.dock < 0 ? "all" : "one")
            return
        case "dock.position": if (root.svc) root.svc.patch(root.dockIndex, "edge", it.key); return
        case "dock.which": root.dock = it.key; return
        case "lock.designs": AequalynSettings.setLockStyle(it.key); return
        case "login.themes":
            panel.open = false                   // the approval window comes up in its place
            Quickshell.execDetached(["setsid", "aequalyn-sddm", "apply", it.key])
            return
        }
        if (root.mode === "cursor") {
            if (!root.plume) return
            if (String(it.key).indexOf("follow:") === 0) root.follow(root.plume, "setSetting", it.key.slice(7))
            else if (root.part === "looks") root.plume.wearCursor(it.key)
            else if (root.part === "trail") root.plume.applyLook(it.key)
            else root.plume.setSetting(root.part, it.key)
            return
        }
        if (root.mode === "showcase") {
            if (!root.showcase) return
            if (String(it.key).indexOf("follow:") === 0) root.follow(root.showcase, "setValue", it.key.slice(7))
            else if (root.part === "looks") root.showcase.applyPreset(it.key)
            else root.showcase.setValue(root.part, it.key)
            return
        }
        if (root.mode === "all") {
            const m = AequalynSettings.matchCfg
            if (root.part === "lead") AequalynSettings.setMatch(it.key === "off" ? { on: false } : { on: true, lead: it.key })
            else if (root.part === "parts") AequalynSettings.setMatch({ [it.key]: !m[it.key] })
            else AequalynSettings.setMatch({ perTheme: it.key })
            return
        }
        if (!root.theme) return
        if (it.key === "") root.theme.setWallpaperMode()
        else root.theme.setByKey(it.key)
    }

    Process {
        id: loginProc
        command: ["sh", "-c", "aequalyn-sddm current; echo '#'; aequalyn-sddm list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.split("#\n")
                root.loginNow = (t[0] || "").trim()
                root.loginThemes = (t[1] || "").split("\n").map(x => x.trim()).filter(x => /^[A-Za-z0-9._-]+$/.test(x))
                if (root.mode === "login") Qt.callLater(root.toCurrent)
            }
        }
    }

    KitPanel {
        id: panel
        theme: root.theme
        name: "quickLooks"
        icon: root.icons[root.mode]
        title: root.titles[root.mode]
        placeholder: "Search " + root.titles[root.mode].toLowerCase() + " choices"
        panelWidth: 620
        panelHeight: 560
        emptyText: root.mode === "dock" && root.docks.length === 0 ? "No dock to change"
            : root.mode === "cursor" && !root.plume || root.mode === "showcase" && !root.showcase ? root.titles[root.mode] + " is turned off"
            : "Nothing by that name"
        chips: root.chips
        chip: root.part
        onChipChosen: key => root.setPart(key)
        countText: panel.items.length + (panel.items.length === 1 ? " choice" : " choices")
            + (root.mode === "dock" && root.docks.length > 1 ? " · " + (root.dock < 0 ? "all docks" : "dock " + (root.dockIndex + 1)) : "")
        items: {
            const q = panel.query.trim().toLowerCase()
            return root.rows.filter(x => q === "" || (x.title + " " + x.sub).toLowerCase().indexOf(q) >= 0)
                .map(x => Object.assign({ hint: x.now ? "on" : "" }, x))
        }
        hints: [["↑ ↓", "move"], ["Tab", "part"], ["Enter", "use"], ["Alt 1-7", "bar to everything"], ["Esc", "close"]]
        status: {
            const by = KitFollow.ledBy(root.mode)
            return by === "" || AequalynSettings.matchCfg.lead === "last" ? "" : "One look everywhere is on: this takes its look from " + by + " (Super + Ctrl + M)"
        }
        onActivated: item => root.use(item)
        onKeyPressed: event => {
            const n = event.key - Qt.Key_1
            if ((event.modifiers & Qt.AltModifier) && n >= 0 && n < root.modes.length) {
                root.show(root.modes[n])
                event.accepted = true
            }
        }
    }

    IpcHandler {
        target: "quickLooks"
        function bar(): void { root.toggle("bar") }
        function dock(): void { root.toggle("dock") }
        function lock(): void { root.toggle("lock") }
        function login(): void { root.toggle("login") }
        function cursor(): void { root.toggle("cursor") }
        function showcase(): void { root.toggle("showcase") }
        function all(): void { root.toggle("all") }
        function close(): void { panel.open = false }
    }
    Component.onCompleted: KitHost.register("quickLooks", root)
    Component.onDestruction: KitHost.unregister("quickLooks", root)
}
