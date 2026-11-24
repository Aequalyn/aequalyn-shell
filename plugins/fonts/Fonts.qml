// Fonts (Super + Ctrl + .): pick UI and mono fonts for the whole desktop.
import QtQuick
import Quickshell
import Quickshell.Io
import "root:/plugins/kit"
import "root:/settings"

Scope {
    id: root
    property var theme: null
    property var fonts: []
    property string mode: "ui" // ui | mono

    readonly property string current: mode === "mono" ? AequalynSettings.monoFont : AequalynSettings.uiFont
    readonly property var chips: [
        { key: "ui", label: "UI font" },
        { key: "mono", label: "Mono font" }
    ]

    function load() {
        fontProc.start(["sh", "-c", "fc-list --format '%{family[0]}\\n' | sort -u"])
    }

    function pick(name) {
        if (!name) return
        AequalynSettings.setFont(root.mode, name)
        panel.open = false
    }

    KitRun {
        id: fontProc
        seconds: 8
        maxOut: 400000
        onDone: (code, out) => {
            const installed = {}
            for (const n of String(out).split("\n")) { const name = n.trim(); if (name) installed[name.toLowerCase()] = name }
            const curated = ["Aequalyn","Aequalyn Mono","JetBrainsMono Nerd Font","Noto Sans Mono","Adwaita Mono","Liberation Mono","Noto Sans","DejaVu Sans","Adwaita Sans","Figtree"]
            const list = []
            for (const c of curated) { if (installed[c.toLowerCase()] || c === "Aequalyn") list.push(installed[c.toLowerCase()] || c) }
            for (const n of Object.values(installed)) { if (list.indexOf(n) < 0) list.push(n) }
            root.fonts = list
        }
    }


    function adjustSize(delta) {
        AequalynSettings.setFontOption("fontSize", Math.max(8, Math.min(20, AequalynSettings.fontSize + delta)))
    }

    KitPanel {
        id: panel
        theme: root.theme
        name: "fonts"
        icon: "\u{F031C}"
        title: "Fonts"
        placeholder: root.mode === "mono" ? "Search mono fonts" : "Search UI fonts"
        panelWidth: 860
        panelHeight: 640
        emptyText: "No font matches"
        chips: root.chips
        chip: root.mode
        countText: panel.items.length + " fonts · " + (root.mode === "mono" ? "Mono" : "UI") + ": " + root.current + (AequalynSettings.fontSame ? " · both at once" : "")
        hints: [["↑ ↓", "move"], ["Tab", "type"], ["Enter", "apply"], ["Esc", "close"]]
        onChipChosen: key => { root.mode = key; panel.current = 0 }
        onOpenChanged: if (open) { root.load(); panel.current = 0 }
        items: {
            const q = panel.query.trim().toLowerCase()
            return root.fonts.filter(f => q === "" || f.toLowerCase().indexOf(q) >= 0).map(f => ({
                icon: "\u{F031C}",
                title: f,
                sub: (f === root.current ? "Current · " : "") + (f.toLowerCase().indexOf("aequalyn") >= 0 ? "Aequalyn's own font" : (root.mode === "mono" ? "Monospace/UI code" : "Interface font")),
                hint: f === root.current ? "active" : "",
                fontName: f
            }))
        }
        onActivated: (item) => { if (item) root.pick(item.fontName) }
        actions: [
            { key: "size-down", label: "A-" },
            { key: "size-up", label: "A+" },
            { key: "apply-ui", label: "Use for UI" },
            { key: "apply-mono", label: "Use for Mono" }
        ]
        onAction: (key) => {
            if (key === "size-down") { root.adjustSize(-1); return }
            if (key === "size-up") { root.adjustSize(1); return }
            const item = panel.items[panel.current]
            if (!item) return
            if (key === "apply-ui") { root.mode = "ui"; root.pick(item.fontName) }
            if (key === "apply-mono") { root.mode = "mono"; root.pick(item.fontName) }
        }
        onKeyPressed: (event) => {
            if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_BracketLeft) { root.adjustSize(-1); event.accepted = true }
            if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_BracketRight) { root.adjustSize(1); event.accepted = true }
        }
        status: "Aequalyn logo: 󰣇  • Aequalyn and Aequalyn Mono — Aequalyn's own fonts. Size: " + AequalynSettings.fontSize + "pt · Ctrl+[ / Ctrl+] to change"
    }

    IpcHandler {
        target: "fonts"
        function toggle(): void { panel.toggle() }
        function open(mode: string): void { if (mode) root.mode = mode; panel.open = true }
    }

    Component.onCompleted: KitHost.register("fonts", root)
    Component.onDestruction: KitHost.unregister("fonts", root)
}
