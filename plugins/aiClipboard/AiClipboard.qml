// AI clipboard (Super + Alt + V): do something with the text you copied: sum it up,
// explain it, translate it, fix its spelling, make it shorter. The AI agent you have
// installed does it; Enter on the result copies it back, ready to paste.
import QtQuick
import Quickshell
import Quickshell.Io
import "root:/plugins/kit"

Scope {
    id: root
    property var theme: null
    KitStore { id: shared; pluginId: "ai"; defaults: ({ agent: "auto" }) }
    KitAi {
        id: ai
        agent: String(shared.get("agent"))
        onAnswered: (t) => { root.result = t; panel.status = "Enter copies the result." }
        onFailed: (why) => { panel.status = why }
    }
    property string clip: ""
    property string result: ""
    KitRun {
        id: paste
        seconds: 3
        maxOut: 8192
        onDone: (code, out) => { root.clip = code === 0 ? String(out) : "" }
    }

    readonly property var jobs: [
        { icon: "\u{F0A8C}", title: "Sum it up", ask: "Summarize this in a few short sentences:" },
        { icon: "\u{F02FC}", title: "Explain it", ask: "Explain this simply, as to someone new to the subject:" },
        { icon: "\u{F05CA}", title: "Translate to English", ask: "Translate this to English. Reply with the translation only:" },
        { icon: "\u{F0B5C}", title: "Fix spelling and grammar", ask: "Fix the spelling and grammar. Keep the meaning and tone. Reply with the fixed text only:" },
        { icon: "\u{F0B6F}", title: "Make it shorter", ask: "Rewrite this shorter, keeping what matters. Reply with the text only:" }
    ]

    KitPanel {
        id: panel
        theme: root.theme
        name: "ai_clipboard"
        icon: "\u{F014F}"
        title: root.clip.trim() === "" ? "Copy some text first" : "What you copied: " + root.clip.trim().replace(/\s+/g, " ").slice(0, 60) + (root.clip.length > 60 ? "…" : "")
        input: false
        panelWidth: 760
        panelHeight: 520
        items: root.result !== "" ? [{ icon: "\u{F018F}", title: "Copy the result", sub: root.result.replace(/\s+/g, " ").slice(0, 120), copy: true }].concat(root.jobs) : root.jobs
        status: ai.busy ? "Thinking…" : ""
        hints: [["↑ ↓", "move"], ["Enter", "do it"], ["Esc", "close"]]
        onOpenChanged: if (open) { root.result = ""; paste.start(["wl-paste", "--no-newline", "--type", "text"]) }
        onActivated: (item) => {
            if (!item || ai.busy) return
            if (item.copy) { KitHost.copy(root.result); panel.open = false; return }
            if (root.clip.trim() === "") { panel.status = "The clipboard has no text."; return }
            root.result = ""
            ai.ask(item.ask + "\n\n" + root.clip)
        }
    }
    IpcHandler {
        target: "aiClipboard"
        function toggle(): void { panel.toggle() }
    }
    Component.onCompleted: KitHost.register("aiClipboard", root)
    Component.onDestruction: { ai.stop(); KitHost.unregister("aiClipboard", root) }
}
