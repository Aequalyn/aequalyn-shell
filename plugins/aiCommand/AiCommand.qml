// AI command (Super + Alt + E): say what you want done, in words; the AI agent you
// have installed answers with one command for it. Nothing runs by itself: Enter
// copies the command, Ctrl + Enter opens a terminal that runs it in front of you.
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
        onAnswered: (t) => {
            // the first line that looks like a command, without code fences
            const line = t.split("\n").map(l => l.trim()).filter(l => l !== "" && !/^```/.test(l))[0] || ""
            root.command = line.replace(/^\$\s+/, "")
            panel.status = root.command !== "" ? "Read it before you run it. Enter copies, Ctrl + Enter runs it in a terminal." : "No command came back; try saying it another way."
        }
        onFailed: (why) => { panel.status = why }
    }
    property string command: ""
    property string asked: ""

    KitPanel {
        id: panel
        theme: root.theme
        name: "ai_command"
        icon: "\u{F018D}"
        placeholder: "What to do, like: find the biggest files in Downloads"
        panelWidth: 760
        panelHeight: 360
        hints: [["Enter", root.command !== "" && panel.query === root.asked ? "copy" : "ask"], ["Ctrl + Enter", "run in a terminal"], ["Esc", "close"]]
        body: Component {
            Rectangle {
                radius: 10
                color: panel.c_surface
                border.width: 1
                border.color: panel.c_border
                Text {
                    anchors.fill: parent
                    anchors.margins: 14
                    text: ai.busy ? "Thinking…" : (root.command !== "" ? root.command : "Say what you want done, then Enter.")
                    textFormat: Text.PlainText
                    wrapMode: Text.WrapAnywhere
                    color: root.command !== "" && !ai.busy ? panel.c_text : panel.c_muted
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                }
            }
        }
        onActivated: (item, index, mods) => {
            const q = panel.query.trim()
            if (ai.busy) return
            if (root.command !== "" && q === root.asked) {
                if (mods & Qt.ControlModifier) {
                    Quickshell.execDetached(["kitty", "-e", "bash", "-c", root.command + '; echo; read -n1 -s -r -p "Press a key to close"'])
                    panel.open = false
                } else { KitHost.copy(root.command); panel.status = "Copied" }
                return
            }
            if (q === "") return
            root.asked = q
            root.command = ""
            panel.status = ""
            ai.ask("Reply with exactly one shell command for Arch Linux (bash) that does the following. No explanation, no markdown, no backticks, just the command on one line. Never use sudo rm -rf or anything that destroys data unless asked plainly.\n\n" + q)
        }
    }
    IpcHandler {
        target: "aiCommand"
        function toggle(): void { panel.toggle() }
    }
    Component.onCompleted: KitHost.register("aiCommand", root)
    Component.onDestruction: { ai.stop(); KitHost.unregister("aiCommand", root) }
}
