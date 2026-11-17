// Timer (Super + Alt + T): a countdown, a pomodoro (25 minutes of work, then 5 of
// rest, on and on) or a stopwatch. Type a number of minutes and Enter, or pick one.
// The bar's timer widget shows it while it runs, and a message comes when it ends.
import QtQuick
import Quickshell
import Quickshell.Io
import "root:/plugins/kit"

Scope {
    id: root
    property var theme: null
    // "" (stopped) | "timer" | "work" | "rest" | "stopwatch"
    property string mode: ""
    property double endsAt: 0
    property double startedAt: 0
    property int remaining: 0           // seconds, or elapsed for the stopwatch
    property int lengthMin: 0
    property bool paused: false
    property int heldAt: 0              // the seconds shown when it was paused

    function start(kind, minutes) {
        root.paused = false
        root.mode = kind
        root.lengthMin = minutes
        root.startedAt = Date.now()
        root.endsAt = kind === "stopwatch" ? 0 : Date.now() + minutes * 60000
        tick()
    }
    function stop() { root.mode = ""; root.remaining = 0; root.paused = false }
    // held where it is, and on from there (the bar widget's quick panel)
    function pause() {
        if (root.mode === "" || root.paused) return
        tick()
        root.heldAt = root.remaining
        root.paused = true
    }
    function resume() {
        if (!root.paused) return
        if (root.mode === "stopwatch") root.startedAt = Date.now() - root.heldAt * 1000
        else root.endsAt = Date.now() + root.heldAt * 1000
        root.paused = false
        tick()
    }
    // a few more minutes on a countdown
    function extend(minutes) {
        if (root.mode === "" || root.mode === "stopwatch") return
        if (root.paused) { root.heldAt += minutes * 60; root.remaining = root.heldAt }
        else { root.endsAt += minutes * 60000; tick() }
        root.lengthMin += minutes
    }
    // how much of a countdown has gone, 0 to 1
    readonly property real progress: root.mode === "" || root.mode === "stopwatch" || root.lengthMin <= 0 ? 0
        : Math.max(0, Math.min(1, 1 - root.remaining / (root.lengthMin * 60)))
    function tick() {
        if (root.mode === "" || root.paused) return
        if (root.mode === "stopwatch") { root.remaining = Math.floor((Date.now() - root.startedAt) / 1000); return }
        root.remaining = Math.max(0, Math.ceil((root.endsAt - Date.now()) / 1000))
        if (root.remaining > 0) return
        if (root.mode === "work") { KitHost.notify("Time for a break", "Five minutes away from the screen."); start("rest", 5) }
        else if (root.mode === "rest") { KitHost.notify("Back to it", "Another 25 minutes."); start("work", 25) }
        else { KitHost.notify("Time is up", root.lengthMin + (root.lengthMin === 1 ? " minute" : " minutes") + " have passed."); stop() }
    }
    Timer { interval: 1000; repeat: true; running: root.mode !== "" && !root.paused; onTriggered: root.tick() }
    function clock(s) { const m = Math.floor(s / 60), r = s % 60; return (m >= 60 ? Math.floor(m / 60) + ":" + String(m % 60).padStart(2, "0") : m) + ":" + String(r).padStart(2, "0") }
    readonly property string label: root.mode === "" ? "" : root.clock(root.remaining)
    readonly property string modeName: ({ timer: "Timer", work: "Pomodoro: work", rest: "Pomodoro: rest", stopwatch: "Stopwatch" })[root.mode] || ""

    KitPanel {
        id: panel
        theme: root.theme
        name: "timer"
        icon: "\u{F051B}"
        placeholder: "Minutes, like 10, then Enter"
        panelHeight: 430
        items: {
            const n = parseFloat(panel.query)
            const typed = isFinite(n) && n > 0 && n <= 600 ? [{ icon: "\u{F051B}", title: "Count down " + n + (n === 1 ? " minute" : " minutes"), act: "timer", min: n }] : []
            const running = root.mode !== "" ? [{ icon: "\u{F04DB}", title: "Stop the " + root.modeName.toLowerCase(), sub: root.label + (root.mode === "stopwatch" ? " so far" : " left"), act: "stop" }] : []
            return typed.concat(running, [
                { icon: "\u{F0130}", title: "Pomodoro", sub: "25 minutes of work, then 5 of rest, until you stop it", act: "work", min: 25 },
                { icon: "\u{F051B}", title: "5 minutes", act: "timer", min: 5 },
                { icon: "\u{F051B}", title: "15 minutes", act: "timer", min: 15 },
                { icon: "\u{F051B}", title: "30 minutes", act: "timer", min: 30 },
                { icon: "\u{F051B}", title: "1 hour", act: "timer", min: 60 },
                { icon: "\u{F0954}", title: "Stopwatch", sub: "Counts up until you stop it", act: "stopwatch", min: 0 }
            ])
        }
        hints: [["Enter", "start"], ["↑ ↓", "move"], ["Esc", "close"]]
        onActivated: (item) => {
            if (!item) return
            if (item.act === "stop") root.stop()
            else root.start(item.act, item.min)
            panel.open = false
        }
    }
    // its panel, opened or closed (the bar widget's click)
    function toggle() { panel.toggle() }
    IpcHandler {
        target: "timer"
        function toggle(): void { panel.toggle() }
        function start(minutes: int): void { root.start("timer", minutes) }
        function pomodoro(): void { root.start("work", 25) }
        function stop(): void { root.stop() }
        function status(): string { return root.mode === "" ? "stopped" : root.modeName + " " + root.label }
    }
    Component.onCompleted: KitHost.register("timer", root)
    Component.onDestruction: KitHost.unregister("timer", root)
}
