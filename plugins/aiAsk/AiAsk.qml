// AI ask (Super + Alt + Space): a question, answered by the AI agent you have
// installed, without opening a terminal. Enter asks; Enter on the answer copies it.
// Nothing leaves the computer until you press Enter, and only what you typed does.
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
        onAnswered: (t) => { root.answer = t; panel.status = "Answered by " + ai.labels[ai.found] + ". Enter copies it." }
        onFailed: (why) => { panel.status = why }
    }
    property string answer: ""
    property string asked: ""

    KitPanel {
        id: panel
        theme: root.theme
        name: "ai_ask"
        icon: "\u{F0B79}"
        placeholder: ai.found !== "" ? "Ask " + ai.labels[ai.found] + " anything" : "Ask anything"
        panelWidth: 760
        panelHeight: 540
        hints: [["Enter", root.answer !== "" && panel.query === root.asked ? "copy the answer" : "ask"], ["Esc", "close"]]
        body: Component {
            Flickable {
                contentWidth: width
                contentHeight: answerText.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Text {
                    id: answerText
                    width: parent.width
                    text: ai.busy ? "Thinking…" : (root.answer !== "" ? root.answer : "Ask a question and press Enter.")
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    color: root.answer !== "" && !ai.busy ? panel.c_text : panel.c_muted
                    font.family: "sans-serif"
                    font.pixelSize: 13
                    lineHeight: 1.15
                }
            }
        }
        onActivated: () => {
            const q = panel.query.trim()
            if (q === "" || ai.busy) return
            if (q === root.asked && root.answer !== "") { KitHost.copy(root.answer); panel.status = "Copied"; return }
            root.asked = q
            root.answer = ""
            panel.status = ""
            ai.ask("Answer this briefly and plainly, in plain text without markdown:\n\n" + q)
        }
    }
    IpcHandler {
        target: "aiAsk"
        function toggle(): void { panel.toggle() }
    }
    Component.onCompleted: KitHost.register("aiAsk", root)
    Component.onDestruction: { ai.stop(); KitHost.unregister("aiAsk", root) }
}
