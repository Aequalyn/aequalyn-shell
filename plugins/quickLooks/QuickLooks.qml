// Quick looks: one small panel for the bar (Super + Ctrl + B), the docks (Super + Ctrl + D),
// the lock screen (Super + Ctrl + K) and the login screen (Super + Ctrl + G), to switch how
// each one looks without opening Settings. Tab goes through what can be changed, typing
// finds it, Enter puts it on at once and the panel stays, so several can be tried; Esc
// closes. Alt + 1 to 4 go to the other three. The login screen is the system's: it asks first.
import QtQuick
import Quickshell
import Quickshell.Io
import "root:/plugins/kit"
import "root:/plugins/atelier"
import "root:/settings"
import "../../style/AequalynLooks.js" as Looks
import "../../style/BarLooks.js" as BarLooks
import "../../settings/center/LockDesigns.js" as LockDesigns

Scope {
    id: root
    property var theme: null
    property string mode: "bar"                  // bar | dock | lock | login
    property var parts: ({ bar: "looks", dock: "looks", lock: "designs", login: "themes" })
    readonly property string part: root.parts[root.mode]
    property int dock: 0                         // which dock the choices go to; -1 for all
    property var loginThemes: []
    property string loginNow: ""

    readonly property var modes: ["bar", "dock", "lock", "login"]
    readonly property var titles: ({ bar: "Bar", dock: "Docks", lock: "Lock screen", login: "Login screen" })
    readonly property var icons: ({ bar: "\u{F10AB}", dock: "\u{F10A9}", lock: "\u{F033E}", login: "\u{F0343}" })
    readonly property var svc: AtelierHost.docks
    readonly property var docks: root.svc ? root.svc.docks : []
    readonly property int dockIndex: root.dock < 0 ? 0 : Math.min(root.dock, Math.max(0, root.docks.length - 1))

    readonly property var chips: {
        if (root.mode === "bar") return [{ key: "looks", label: "Look" }, { key: "position", label: "Position" },
            { key: "sets", label: "Bar and docks" }, { key: "colours", label: "Colours" }]
        if (root.mode === "dock") return [{ key: "looks", label: "Look" }, { key: "position", label: "Position" },
            { key: "which", label: "Which dock" }, { key: "colours", label: "Colours" }]
        if (root.mode === "lock") return [{ key: "designs", label: "Design" }, { key: "colours", label: "Colours" }]
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
        emptyText: root.mode === "dock" && root.docks.length === 0 ? "No dock to change" : "Nothing by that name"
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
        hints: [["↑ ↓", "move"], ["Tab", "part"], ["Enter", "use"], ["Alt 1-4", "bar, dock, lock, login"], ["Esc", "close"]]
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
        function close(): void { panel.open = false }
    }
    Component.onCompleted: KitHost.register("quickLooks", root)
    Component.onDestruction: KitHost.unregister("quickLooks", root)
}
