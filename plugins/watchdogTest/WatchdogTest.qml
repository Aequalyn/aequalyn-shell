// The watchdog self-test: a plugin that fails on purpose, so the protection can
// be watched working. It runs in the sandbox (sandbox: true in Plugins.js):
// turned on, it crashes, leaks memory and crashes again -- three failures --
// while the shell it lives beside never so much as blinks, and the watchdog
// restarts it each time and finally turns it off, with a notification saying
// why. A message in the corner narrates every step.
//
// Its life counter is one line in a file, read and written through the shell
// (not KitStore: it writes the moment it loads, inside KitStore's
// mkdir-then-reload window, where a write can be read back over). The counter
// decides which failure comes next, so each restart picks up where the last
// life left off; turning it on again starts the whole run over.
//
// Nothing here can run in-process: without the sandbox's AEQUALYN_PLUGIN_ID it
// refuses, so even a misconfigured copy can never touch the real shell.
//
//   Settings -> Plugins -> Watchdog self-test      the demo, on a switch
//   aequalyn-watchdog status                       its lives, live
//   aequalyn-watchdog test watchdogTest hang       the one failure it does
//                                                  not stage by itself
import QtQuick
import Quickshell
import Quickshell.Io
import "root:/plugins/kit"

Scope {
    id: root
    property var theme: null

    // the state dir falls back the way KitStore's does: XDG_STATE_HOME is not
    // always set in the environment a host inherits
    readonly property string dir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state")
                                  + "/aequalyn/watchdogTest"
    readonly property string file: dir + "/life"
    readonly property bool inSandbox: Quickshell.env("AEQUALYN_PLUGIN_ID") === "watchdogTest"
    property int life: -1          // which failure is next, read from the file
    property bool begun: false

    function persist(n) {
        Quickshell.execDetached(["sh", "-c",
            'mkdir -p "' + root.dir + '" && echo ' + n + ' > "' + root.file + '"'])
    }

    // one line, one number: read once at start, written before each failure
    KitRun {
        id: reader
        onDone: (code, out, err) => {
            if (root.begun) return
            let n = parseInt(String(out).trim())
            if (isNaN(n)) n = 0
            root.life = n
            root.begin()
        }
    }

    function begin() {
        if (root.begun || !root.inSandbox || root.life < 0) return
        root.begun = true
        // a completed run (or one left half-done): start over
        if (root.life > 2) root.life = 0
        const n = root.life + 1
        root.persist(n)             // on disk before the failure lands
        if (n === 1) {
            KitHost.notify("Watchdog self-test, 1 of 3",
                "This plugin is crashing on purpose in a few seconds -- a hard kill, "
                + "the way a broken C++ path dies. Watch: the shell does not go down.")
            crasher.running = true
        } else if (n === 2) {
            KitHost.notify("Watchdog self-test, 2 of 3",
                "Now it eats memory on purpose, past its budget. The watchdog will stop it "
                + "for that, and start it again.")
            leaker.running = true
        } else {
            KitHost.notify("Watchdog self-test, 3 of 3",
                "One more crash. Three failures is the watchdog's limit: after this it "
                + "turns the plugin off, and a message says so. The shell stays up.")
            crasher.running = true
        }
    }

    Component.onCompleted: {
        if (!root.inSandbox) {
            // never anywhere but its own process: the whole point is that the
            // shell cannot be hurt from there
            KitHost.notify("Watchdog self-test",
                "I only fail on purpose inside the sandbox, and I am not in it now. Nothing was done.")
            return
        }
        KitHost.register("watchdogTest", root)
        reader.start(["sh", "-c", 'cat "' + root.file + '" 2>/dev/null || echo 0'])
    }
    Component.onDestruction: KitHost.unregister("watchdogTest", root)

    // a hard death, after a pause so the message can be read: SIGKILL on this
    // very process, the way a plugin that walks into bad memory would die
    Process {
        id: crasher
        running: false
        command: ["sh", "-c", "sleep 4 && kill -9 $PPID"]
    }

    // a runaway allocator: live JS nothing ever lets go, ~100 MiB/s, until the
    // memory budget is breached
    Timer {
        id: leaker
        running: false
        repeat: true
        interval: 1000
        property var ballast: []
        onTriggered: {
            const chunk = []
            for (let i = 0; i < 200000; i++) chunk.push({ i, s: "ballast " + i + " " + Math.random() })
            ballast.push(chunk)
        }
    }

    IpcHandler {
        target: "watchdogTest"
        function status(): string {
            return root.inSandbox
                ? "staging failure " + (root.life + 1) + " of 3"
                : "not in the sandbox: refusing to fail"
        }
        // forget the run so far: the next start begins at 1 of 3
        function reset(): string { root.persist(0); return "ok" }
    }
}
