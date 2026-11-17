// Key hints (Super + /): every key binding Hyprland has right now, searchable, in
// plain words: what to press and what it does.
import QtQuick
import Quickshell
import Quickshell.Io
import "root:/plugins/kit"

Scope {
    id: root
    property var theme: null
    property var binds: []

    // The bindings, read from the config files themselves: Hyprland only reports a Lua
    // binding by a number, while the files say what it does (a comment, a description,
    // or the command it runs).
    readonly property var names: ({
        launcher: "App launcher", programs: "Programs menu", defaults: "Default apps", aequalyn: "Control center",
        atelier: "Themes and wallpapers", monitors: "Screens", idle: "Keep awake", notifications: "Notifications",
        power: "Power menu", clipboard: "Clipboard history", clipscape: "Clipboard", altscape: "Window switcher",
        plume: "Cursor effects", media: "Media", calculator: "Calculator", colorPicker: "Color picker", emoji: "Emoji",
        notes: "Quick notes", keyHints: "Key hints", palette: "Command palette", sysmon: "System monitor",
        screenText: "Screen text", timer: "Timer", focus: "Focus", nightLight: "Night light", weather: "Weather"
    })
    readonly property var vars: ({ term: "Terminal", files: "Files", browser: "Browser", menu: "Menu" })
    readonly property var appKeys: ({ A: "select all", C: "copy", V: "paste", X: "cut", Z: "undo", S: "save", F: "find" })
    function keysText(raw) {
        const nice = { RETURN: "Enter", ESCAPE: "Esc", SPACE: "Space", SLASH: "/", PERIOD: ".", COMMA: ",", EQUAL: "=",
                       MINUS: "-", TAB: "Tab", PRINT: "Print", GRAVE: "`", SUPER: "Super", SHIFT: "Shift", CTRL: "Ctrl", ALT: "Alt",
                       LEFT: "←", RIGHT: "→", UP: "↑", DOWN: "↓", MOUSE_DOWN: "Wheel down", MOUSE_UP: "Wheel up" }
        return raw.split("+").map(k => k.trim()).filter(k => k !== "").map(k => {
            const u = k.toUpperCase()
            return nice[u] || (k.length === 1 ? k.toUpperCase() : k.charAt(0).toUpperCase() + k.slice(1).toLowerCase())
        }).join(" + ")
    }
    function actionText(rest, comment) {
        const d = rest.match(/description\s*=\s*"([^"]+)"/)
        if (d) return d[1]
        if (comment) return comment
        let m = rest.match(/exec_cmd\(\s*"qs ipc call (\S+)\s*([^"]*)"/)
        if (m) return (root.names[m[1]] || m[1]) + (m[2].trim() ? " · " + m[2].trim() : "")
        m = rest.match(/exec_cmd\(\s*(\w+)\s*\)/)
        if (m) return root.vars[m[1]] || m[1]
        m = rest.match(/exec_cmd\(\s*"([^"]+)"/)
        if (m) return m[1]
        m = rest.match(/(?:send_shortcut_once|universal)\(\s*"(\w+)",\s*"(\w)"/)
        if (m) return root.appKeys[m[2]] ? "In the app: " + root.appKeys[m[2]] : "In the app: " + m[1] + " + " + m[2]
        // the window layouts' own keys (keys.lua)
        m = rest.match(/^K\.(\w+)\(\s*(-?\w*)/)
        if (m) {
            const k = { tab: m[2] === "-1" ? "Previous window in the layout" : "Next window in the layout",
                        promote: "Bring the window to the main place", focus: "Move the focus", swap: "Swap two windows",
                        clicked: "Bring the clicked window forward", grow: "Make the main place bigger", shrink: "Make the main place smaller" }
            return k[m[1]] || m[1]
        }
        m = rest.match(/hl\.dsp\.([\w.]+)\(([^)]*)\)/)
        if (m) return m[1].replace(/\./g, " ").replace(/_/g, " ") + (m[2].trim() && m[2].length < 40 ? " " + m[2].replace(/[{}"]/g, "").trim() : "")
        return rest.replace(/\)+\s*$/, "").trim()
    }
    function parse(text) {
        const out = []
        const seen = {}
        for (const line of String(text).split("\n")) {
            const t = line.trim()
            if (t.indexOf("--") === 0) continue
            const m = t.match(/^(?:hl\.)?bind\(\s*(?:(M|mod)\s*\.\.\s*)?"([^"]+)"\s*,\s*(.*)$/)
            if (!m) continue
            const keys = root.keysText((m[1] ? "SUPER + " : "") + m[2])
            // keys inside a submap (no modifier) and a modifier's own release are not ones to press
            if (keys.indexOf(" + ") < 0 || /_[LR]$/i.test(m[2].trim())) continue
            const c = m[3].match(/\)\s*--\s*(.+)$/)
            const what = root.actionText(m[3], c ? c[1].trim() : "")
            // bound again later in the files: the later one is what Hyprland uses
            seen[keys] = { keys: keys, what: what }
        }
        for (const k in seen) out.push(seen[k])
        return out.sort((a, b) => a.keys.localeCompare(b.keys))
    }
    function load() {
        reader.start(["sh", "-c", 'cd "$HOME/.config/hypr" 2>/dev/null && cat aequalyn/*.lua webapps.lua hyprland.lua 2>/dev/null'])
    }
    KitRun {
        id: reader
        seconds: 5
        maxOut: 600000
        onDone: (code, out) => { root.binds = root.parse(out) }
    }

    KitPanel {
        id: panel
        theme: root.theme
        name: "key_hints"
        icon: "\u{F030C}"
        placeholder: "What to do, or a key"
        panelWidth: 760
        panelHeight: 560
        emptyText: "No key binding matches"
        items: {
            const q = panel.query.trim().toLowerCase()
            return root.binds.filter(b => q === "" || b.keys.toLowerCase().indexOf(q) >= 0 || b.what.toLowerCase().indexOf(q) >= 0)
                .map(b => ({ title: b.what, hint: b.keys }))
        }
        hints: [["↑ ↓", "move"], ["type", "search"], ["Esc", "close"]]
        onOpenChanged: if (open) root.load()
    }
    IpcHandler {
        target: "keyHints"
        function toggle(): void { panel.toggle() }
    }
    Component.onCompleted: KitHost.register("keyHints", root)
    Component.onDestruction: KitHost.unregister("keyHints", root)
}
