// AI tidy (Super + Alt + D): a messy Downloads folder, sorted into a few folders. The
// AI agent you have installed sees only the file names (never what is in them) and
// suggests where each goes; you see the plan before anything moves. Files only move
// inside Downloads, never over another file, and nothing is ever deleted. Undo puts
// the last tidy back.
import QtQuick
import Quickshell
import Quickshell.Io
import "root:/plugins/kit"

Scope {
    id: root
    property var theme: null
    readonly property string dir: (Quickshell.env("HOME") || "") + "/Downloads"
    KitStore { id: shared; pluginId: "ai"; defaults: ({ agent: "auto" }) }
    KitStore { id: store; pluginId: "aiTidy"; defaults: ({ last: [] }) }
    property var files: []
    property var plan: []                 // [{ folder, files: [] }]
    readonly property var last: Array.isArray(store.get("last")) ? store.get("last") : []

    KitRun {
        id: lister
        seconds: 5
        onDone: (code, out) => { root.files = String(out).split("\n").filter(f => f !== "").slice(0, 300) }
    }
    function list() { lister.start(["find", root.dir, "-maxdepth", "1", "-type", "f", "!", "-name", ".*", "-printf", "%f\\n"]) }

    KitAi {
        id: ai
        agent: String(shared.get("agent"))
        seconds: 180
        onAnswered: (t) => {
            const m = t.match(/\{[\s\S]*\}/)
            let j = null
            try { j = m ? JSON.parse(m[0]) : null } catch (e) { j = null }
            if (!j || typeof j !== "object") { panel.status = "The plan came back in a form it can't read; ask again."; return }
            const seen = {}
            const plan = []
            for (const folder of Object.keys(j)) {
                if (!/^[A-Za-z0-9][A-Za-z0-9 _\-.()&]{0,39}$/.test(folder) || folder === "." || folder === "..") continue
                const fs = (Array.isArray(j[folder]) ? j[folder] : []).filter(f => typeof f === "string" && root.files.indexOf(f) >= 0 && !seen[f])
                fs.forEach(f => seen[f] = true)
                if (fs.length > 0) plan.push({ folder: folder, files: fs })
            }
            root.plan = plan
            panel.status = plan.length ? "Look it over. Move them puts each file in its folder." : "Nothing to sort."
        }
        onFailed: (why) => { panel.status = why }
    }
    function ask() {
        if (root.files.length === 0) { panel.status = "Downloads has no files to sort."; return }
        root.plan = []
        panel.status = ""
        ai.ask("Sort these file names from a Downloads folder into a few clearly named folders (like Documents, Images, Installers, Archives, Music, Video, Code). " +
               "Reply with JSON only, no other text: an object whose keys are folder names and whose values are arrays of the exact file names. " +
               "Leave out files that fit nowhere.\n\n" + JSON.stringify(root.files))
    }

    // moves, logged first so they can be undone; mv -n never writes over a file
    KitRun { id: mover; seconds: 60; onDone: (code) => { panel.status = code === 0 ? "Done. Undo puts them back." : "Some files could not be moved."; root.plan = []; root.list() } }
    function apply() {
        const pairs = []
        const log = []
        for (const p of root.plan) for (const f of p.files) { pairs.push(p.folder, f); log.push({ folder: p.folder, file: f }) }
        if (pairs.length === 0) return
        store.set("last", log)
        mover.start(["sh", "-c", 'cd "$1" || exit 1; shift; s=0; while [ $# -ge 2 ]; do mkdir -p -- "$1" && mv -n -- "$2" "$1/" || s=1; shift 2; done; exit $s', "sh", root.dir].concat(pairs))
    }
    function undo() {
        const pairs = []
        for (const m of root.last) pairs.push(m.folder, m.file)
        if (pairs.length === 0) return
        store.set("last", [])
        mover.start(["sh", "-c", 'cd "$1" || exit 1; shift; s=0; while [ $# -ge 2 ]; do mv -n -- "$1/$2" . || s=1; rmdir -- "$1" 2>/dev/null; shift 2; done; exit $s', "sh", root.dir].concat(pairs))
    }

    KitPanel {
        id: panel
        theme: root.theme
        name: "ai_tidy"
        icon: "\u{F0257}"
        title: "Tidy Downloads · " + root.files.length + (root.files.length === 1 ? " file" : " files")
        input: false
        panelWidth: 760
        panelHeight: 560
        items: {
            const out = []
            if (root.plan.length) {
                out.push({ icon: "\u{F0770}", title: "Move them", sub: root.plan.reduce((n, p) => n + p.files.length, 0) + " files into " + root.plan.length + " folders", act: "apply" })
                for (const p of root.plan) out.push({ icon: "\u{F024B}", title: p.folder, sub: p.files.slice(0, 4).join(", ") + (p.files.length > 4 ? ", …" : ""), hint: p.files.length + "" })
            } else {
                out.push({ icon: "\u{F0B79}", title: ai.busy ? "Thinking…" : "Suggest a tidy", sub: "Only the file names are sent, never what is in them", act: "ask" })
            }
            if (root.last.length) out.push({ icon: "\u{F054D}", title: "Undo the last tidy", sub: root.last.length + " files back where they were", act: "undo" })
            return out
        }
        hints: [["Enter", "do it"], ["↑ ↓", "move"], ["Esc", "close"]]
        onOpenChanged: if (open) { root.list(); root.plan = []; panel.status = "" }
        onActivated: (item) => {
            if (!item || ai.busy || mover.running) return
            if (item.act === "ask") root.ask()
            else if (item.act === "apply") root.apply()
            else if (item.act === "undo") root.undo()
        }
    }
    IpcHandler {
        target: "aiTidy"
        function toggle(): void { panel.toggle() }
    }
    Component.onCompleted: KitHost.register("aiTidy", root)
    Component.onDestruction: { ai.stop(); KitHost.unregister("aiTidy", root) }
}
