// Focus (Super + Alt + F): do not disturb for a while: messages wait quietly, and a
// message says when the time is up. Pick how long; Enter again ends it early.
import QtQuick
import Quickshell
import Quickshell.Io
import "root:/plugins/kit"
import "root:/plugins/notifications"

Scope {
    id: root
    property var theme: null
    property double until: 0
    property bool wasQuiet: false
    property int left: 0
    readonly property bool on: until > 0

    function begin(minutes) {
        if (!root.on) root.wasQuiet = NotificationService.doNotDisturb
        NotificationService.doNotDisturb = true
        root.until = Date.now() + minutes * 60000
        tick()
    }
    function end(timeUp) {
        if (!root.on) return
        root.until = 0
        NotificationService.doNotDisturb = root.wasQuiet
        if (timeUp) KitHost.notify("Focus time is over", "Messages that came meanwhile are in the corner.")
    }
    // a few more minutes (the bar widget's quick panel)
    function extend(minutes) {
        if (!root.on) return
        root.until += minutes * 60000
        tick()
    }
    function tick() {
        if (!root.on) return
        root.left = Math.max(0, Math.ceil((root.until - Date.now()) / 60000))
        if (Date.now() >= root.until) root.end(true)
    }
    Timer { interval: 15000; repeat: true; running: root.on; onTriggered: root.tick() }

    KitPanel {
        id: panel
        theme: root.theme
        name: "focus"
        icon: "\u{F0F6E}"
        title: root.on ? "Focusing: " + root.left + " min left" : "Focus"
        input: false
        panelHeight: 380
        items: (root.on ? [{ icon: "\u{F04DB}", title: "End focus now", sub: "Messages show again", act: "end" }] : []).concat([
            { icon: "\u{F0F6E}", title: "25 minutes", sub: "Do not disturb until then", min: 25 },
            { icon: "\u{F0F6E}", title: "50 minutes", min: 50 },
            { icon: "\u{F0F6E}", title: "90 minutes", min: 90 },
            { icon: "\u{F0F6E}", title: "2 hours", min: 120 }
        ])
        hints: [["Enter", "start"], ["↑ ↓", "move"], ["Esc", "close"]]
        onActivated: (item) => {
            if (!item) return
            if (item.act === "end") root.end(false)
            else root.begin(item.min)
            panel.open = false
        }
    }
    // its panel, opened or closed (the bar widget's click)
    function toggle() { panel.toggle() }
    IpcHandler {
        target: "focus"
        function toggle(): void { panel.toggle() }
        function start(minutes: int): void { root.begin(minutes) }
        function stop(): void { root.end(false) }
    }
    Component.onCompleted: KitHost.register("focus", root)
    Component.onDestruction: { root.end(false); KitHost.unregister("focus", root) }
}
