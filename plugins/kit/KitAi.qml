// Asks an AI coding agent's command line tool a question and hands back its answer:
// whichever of these is installed (the control center's AI tools page installs them),
// or the one `agent` names. Nothing runs until `ask` is called, and the prompt is
// handed over as an argument, never through a shell.
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: ai
    property string agent: "auto"                // auto | claude | codex | gemini | opencode | qwen
    property int seconds: 120
    readonly property bool busy: runner.running
    property string found: ""                    // the agent that will answer
    signal answered(string text)
    signal failed(string why)

    // how each one is asked once, without a conversation
    readonly property var commands: ({
        claude:   p => ["claude", "-p", p],
        codex:    p => ["codex", "exec", "--skip-git-repo-check", p],
        gemini:   p => ["gemini", "-p", p],
        opencode: p => ["opencode", "run", p],
        qwen:     p => ["qwen", "-p", p]
    })
    readonly property var order: ["claude", "codex", "gemini", "opencode", "qwen"]
    readonly property var labels: ({ claude: "Claude Code", codex: "Codex", gemini: "Gemini CLI", opencode: "OpenCode", qwen: "Qwen Code" })

    function look() {
        finder.command = ["sh", "-c", 'for a in "$@"; do command -v "$a" >/dev/null 2>&1 && echo "$a"; done', "sh"].concat(ai.order)
        finder.running = true
    }
    property var installed: []
    Component.onCompleted: look()
    Process {
        id: finder
        stdout: StdioCollector {
            onStreamFinished: {
                ai.installed = String(text || "").split("\n").filter(x => ai.order.indexOf(x) >= 0)
                ai.found = ai.agent !== "auto" && ai.installed.indexOf(ai.agent) >= 0 ? ai.agent : (ai.installed[0] || "")
            }
        }
    }
    onAgentChanged: found = agent !== "auto" && installed.indexOf(agent) >= 0 ? agent : (installed[0] || "")

    function ask(prompt) {
        if (runner.running) return false
        if (ai.found === "") { ai.failed("No AI agent is installed. Install one on the control center's AI tools page."); return false }
        return runner.start(ai.commands[ai.found](String(prompt)))
    }
    function stop() { runner.stop() }

    KitRun {
        id: runner
        seconds: ai.seconds
        maxOut: 200000
        onDone: (code, out, err) => {
            if (code === 0 && out.trim() !== "") ai.answered(out.trim())
            else ai.failed(code === 124 ? "It took too long; try a shorter question."
                         : (err.trim().split("\n").slice(-1)[0] || "The agent did not answer."))
        }
    }
}
