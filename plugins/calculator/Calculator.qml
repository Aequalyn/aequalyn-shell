// Calculator (Super + =): type a sum, see the answer as you type, Enter copies it.
// Knows + - * / % ^ ( ), sqrt, sin, cos, tan, log, ln, abs, round, floor, ceil, min,
// max, pi and e. The last twenty answers stay, to copy again.
import QtQuick
import Quickshell
import Quickshell.Io
import "root:/plugins/kit"

Scope {
    id: root
    property var theme: null

    KitStore { id: store; pluginId: "calculator"; defaults: ({ history: [] }) }

    // a sum, made safe: only numbers, operators and the known names get through
    function evaluate(text) {
        const t = String(text).trim().toLowerCase().replace(/,/g, ".").replace(/×/g, "*").replace(/÷/g, "/")
        if (t === "" || t.length > 200) return null
        const names = { sqrt: "Math.sqrt", sin: "Math.sin", cos: "Math.cos", tan: "Math.tan", log: "Math.log10",
                        ln: "Math.log", abs: "Math.abs", round: "Math.round", floor: "Math.floor", ceil: "Math.ceil",
                        min: "Math.min", max: "Math.max", pi: "Math.PI", e: "Math.E" }
        let ok = true
        const code = t.replace(/[a-z]+/g, w => { if (names[w]) return names[w]; ok = false; return "" }).replace(/\^/g, "**")
        // once the known names are out, only numbers, operators, brackets and commas remain
        if (!ok || /[^0-9+\-*/%().\s,]/.test(code.replace(/Math\.[A-Za-z0-9]+/g, ""))) return null
        try {
            const v = Function('"use strict"; return (' + code + ')')()
            if (typeof v !== "number" || !isFinite(v)) return null
            return Math.abs(v) < 1e15 ? String(Math.round(v * 1e10) / 1e10) : v.toExponential(6)
        } catch (e) { return null }
    }
    readonly property string answer: evaluate(panel.query) || ""
    readonly property var history: Array.isArray(store.get("history")) ? store.get("history") : []

    KitPanel {
        id: panel
        theme: root.theme
        name: "calculator"
        icon: "\u{F00EC}"
        placeholder: "A sum, like 12 * (3 + 4) or sqrt(2)"
        panelHeight: 420
        emptyText: "Type a sum"
        items: (root.answer !== "" ? [{ icon: "\u{F0484}", title: "= " + root.answer, sub: panel.query, hint: "Enter copies", value: root.answer, fresh: true }] : [])
            .concat(root.history.map(h => ({ icon: "\u{F02DA}", title: h.value, sub: h.sum, value: h.value })))
        hints: [["Enter", "copy the answer"], ["↑ ↓", "earlier answers"], ["Esc", "close"]]
        onActivated: (item) => {
            if (!item) return
            KitHost.copy(item.value)
            if (item.fresh) {
                const h = [{ sum: item.sub, value: item.value }].concat(root.history.filter(x => x.sum !== item.sub)).slice(0, 20)
                store.set("history", h)
            }
            panel.status = "Copied " + item.value
        }
    }
    IpcHandler {
        target: "calculator"
        function toggle(): void { panel.status = ""; panel.toggle() }
        function calc(sum: string): string { return root.evaluate(sum) || "not a sum" }
    }
    Component.onCompleted: KitHost.register("calculator", root)
    Component.onDestruction: KitHost.unregister("calculator", root)
}
