// rootTest -- the root gate, staged on itself the way watchdogTest stages
// the failure policy. Turned on (it is sandboxed, so that is a process of
// its own), it asks for its one declared root action through the gate at
// once: the approval window opens with the exact command, the answer (the
// password feeds sudo on a pipe) decides, and a notification says what
// became of it. Allow it and /usr/bin/id -u answers 0 -- it really ran as
// root; deny it or let it time out and the command never runs. Either
// answer is the demo.
//
// The action it asks for is pinned on its line in Plugins.js (needsRoot):
// the command lives in the manifest, never in code, and aequalyn-watchdog
// runs nothing else no matter what this file says.
import QtQuick
import Quickshell
import Quickshell.Io
import "root:/plugins/kit"

Item {
    id: root

    // Nothing can run in-process: the gate pins the caller by its process,
    // and the demo must never ask from inside the shell it demonstrates.
    readonly property bool inSandbox: Quickshell.env("AEQUALYN_PLUGIN_ID") === "rootTest"

    Process {
        id: gate
        running: false
        stdout: StdioCollector { onStreamFinished: root.answered(text) }
        stderr: StdioCollector { onStreamFinished: if (text) console.warn("rootTest: exec-root stderr: " + text) }
    }

    function ask() {
        if (!root.inSandbox) {
            console.warn("rootTest: this demo refuses to run in-process; "
                       + "it belongs in the sandbox (it does nothing here).")
            return
        }
        console.info("rootTest: asking for its root action")
        KitHost.notify("Root gate test", "It asks for its one declared root action now -- "
            + "the approval window is up. Allow it, deny it, or let it time out: "
            + "each answer is part of the demo.")
        gate.command = ["aequalyn-watchdog", "exec-root", "who-am-i"]
        gate.running = true
    }

    // what became of the request, said out loud: a demo you have to read
    // logs for is not a demo
    function answered(raw) {
        let d = {}
        try { d = JSON.parse(raw) } catch (e) {
            console.warn("rootTest: could not parse the reply: " + raw)
            KitHost.notify("Root gate test", "The gate answered something unexpected "
                + "(see the plugin's log in ~/.local/state/aequalyn/watchdog/logs/).")
            return
        }
        if (d.ok) {
            KitHost.notify("Root gate test: it ran as root",
                "You allowed it, so /usr/bin/id -u ran through sudo with the "
                + "password you typed -- and answered " + (d.out || "").trim() + ". "
                + "That is the whole trip: window, pipe, sudo, back.")
        } else if (String(d.error || "").indexOf("denied") >= 0) {
            KitHost.notify("Root gate test: denied",
                "The command never ran. A denial (a click, Escape, or the "
                + "two-minute timeout) is the answer a plugin gets when "
                + "the person at the keyboard says no.")
        } else {
            KitHost.notify("Root gate test", "The gate refused: " + (d.error || "unknown error")
                + ". Nothing ran as root.")
        }
    }

    IpcHandler {
        target: "rootTest"
        function ask(): string {
            root.ask()
            return root.inSandbox ? "asked" : "refused: in-process"
        }
    }

    // the demo is the activation: enabling the plugin is asking for root,
    // and a restart by the watchdog asks again, which for a demo is right
    Component.onCompleted: root.ask()
}
