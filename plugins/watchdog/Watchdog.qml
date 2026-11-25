// The in-shell side of the plugin sandbox. The external supervisor
// (aequalyn-watchdog, see tools/watchdog) pings this target to know the
// shell's event loop is alive: if a plugin hangs the engine, the ping goes
// unanswered and the supervisor restarts the shell. Plugin on/off requests
// go through here too, so the running state, the settings file and the
// sandboxed out-of-process plugins all stay in step.
import QtQuick
import Quickshell
import Quickshell.Io
import "root:/settings"

Item {
    id: wd
    // set by shell.qml; null for a moment while it loads
    property var pluginManager: null
    // the theme the escalation window is drawn with (from shell.qml)
    property var theme: null
    readonly property real startedAt: Date.now()

    // ---- what the supervisor can call ------------------------------------

    // heartbeat: answered only while the engine turns. A blocked event loop
    // leaves this unanswered and the supervisor acts.
    IpcHandler {
        target: "watchdog"
        function ping(): string { return "ok" }

        // seconds up, and what the shell itself thinks is on and loaded --
        // also the labels the supervisor says in its notifications
        function health(): string {
            const pm = wd.pluginManager
            const rows = pm ? pm.allPlugins.concat(pm.userPlugins).map(p => ({
                id: p.id, label: pm.labelOf(p.id),
                active: pm.enabledIds.indexOf(p.id) >= 0,
                loaded: pm.items[p.id] !== undefined,
                sandboxed: pm.isSandboxed(p)
            })) : []
            return JSON.stringify({ pid: Quickshell.processId,
                                   uptime: Math.round((Date.now() - wd.startedAt) / 1000),
                                   plugins: rows })
        }

        // turn a plugin off the same way the Plugins page does: the loader
        // drops it, the settings file is saved, and the supervisor notices
        // and stops its sandboxed process, if it has one.
        function disablePlugin(id: string, reason: string): string {
            if (!wd.known(id)) return "no plugin " + id
            AequalynSettings.togglePlugin(id, false)
            wd.notify("Plugin turned off", wd.pluginManager.labelOf(id)
                + (reason ? " was turned off: " + reason : " was turned off.")
                + "\nTurn it back on in Settings \u2192 Plugins.")
            return "ok"
        }

        function enablePlugin(id: string): string {
            if (!wd.known(id)) return "no plugin " + id
            AequalynSettings.togglePlugin(id, true)
            return "ok"
        }

        // reload one plugin in place -- the in-process ones; the sandboxed
        // ones live in their own process, restarted by aequalyn-watchdog
        function restartPlugin(id: string): string {
            const pm = wd.pluginManager
            if (!pm) return "shell still loading"
            const p = pm.findPlugin(id)
            if (!p) return "no plugin " + id
            if (pm.isSandboxed(p)) return "sandboxed: use aequalyn-watchdog restart " + id
            return pm.reloadPlugin(id) ? "ok" : "no plugin " + id
        }

        // the sandbox's exceptions, from watchdog.json (noSandbox there):
        // the supervisor pushes the list so this loader picks those plugins
        // back up instead of waiting for a sandbox that will not run them.
        function setNoSandbox(idsJson: string): string {
            try { AequalynSettings.noSandboxPlugins = JSON.parse(idsJson) }
            catch (e) { return "bad json: " + e }
            AequalynSettings.save()
            return "ok"
        }

        // A plugin asked to run one of its declared root actions. The
        // supervisor already pinned the caller to its real process and the
        // command is pinned in its manifest; all that is left is asking the
        // person at the keyboard. The window (below) answers through
        // `aequalyn-watchdog decide`, with the password on a pipe.
        function escalationRequest(payload: string): string {
            try { wd.queueEscalation(JSON.parse(payload)) }
            catch (e) { return "bad json: " + e }
            return "ok"
        }

        // a request that is over (its asker is gone, nobody answered in time): its
        // window goes with it
        function escalationGone(requestId: string): string {
            wd.dropEscalation(requestId)
            return "ok"
        }
    }

    // ---- the escalation window --------------------------------------------
    // Requests are queued: one window at a time, the next opens when this
    // one is answered. A window the supervisor cannot reach this for never
    // happens (it tells the plugin the shell is down), and a window left
    // unanswered times out on the supervisor's side as a denial.
    property var escQueue: []
    property var escCurrent: null
    function queueEscalation(req) {
        // asked again after a restart it may have missed
        const id = req && req.requestId
        if (!id || (wd.escCurrent && wd.escCurrent.requestId === id)
            || wd.escQueue.some(r => r.requestId === id)) return
        // what the person just started comes before what asked by itself, unless its
        // window is being answered
        if (req.interactive === true && wd.escCurrent && wd.escCurrent.interactive !== true && !escWindow.typing) {
            wd.escQueue = [req, wd.escCurrent].concat(wd.escQueue)
            nextEscalation()
            return
        }
        wd.escQueue = req.interactive === true ? [req].concat(wd.escQueue) : wd.escQueue.concat([req])
        if (!wd.escCurrent) nextEscalation()
    }
    function dropEscalation(id) {
        wd.escQueue = wd.escQueue.filter(r => r.requestId !== id)
        if (wd.escCurrent && wd.escCurrent.requestId === id) nextEscalation()
    }
    function nextEscalation() {
        wd.escCurrent = wd.escQueue.length ? wd.escQueue[0] : null
        wd.escQueue = wd.escQueue.slice(1)
        escWindow.showRequest(wd.escCurrent)
    }
    function answerEscalation(requestId, decision, password) {
        // the password goes to the supervisor over its socket, through a
        // pipe: never in argv, never in a log line
        decideProc.requestId = requestId
        decideProc.decision = decision
        decideProc.password = password
        if (decideProc.running) {
            // a previous decide still winding down: its process is stopped
            // and this answer starts fresh a moment later, so a click is
            // never silently dropped on a busy pipe
            decideProc.running = false
            decideRestart.restart()
        } else {
            decideProc.running = true
        }
        if (wd.escCurrent && wd.escCurrent.requestId === requestId
            && decision === "always") {
            // remembered consent, saved where the Plugins page can show it
            try {
                AequalynSettings.allowRoot(wd.escCurrent.plugin, wd.escCurrent.action, true)
            } catch (e) { console.warn("could not remember the root allowance:", e) }
        }
        nextEscalation()
    }
    // a one-shot restart for the rare case a previous decide had to be
    // stopped first (see answerEscalation)
    Timer { id: decideRestart; interval: 150; onTriggered: decideProc.running = true }
    // answers the current request for the supervisor. stdinEnabled so the
    // password can be written to the pipe (Process.write, the way the file
    // manager talks to its daemon) once the process is up
    property Process decideProc: Process {
        id: decideProc
        property string requestId: ""
        property string decision: "deny"
        property string password: ""
        stdinEnabled: true
        command: ["aequalyn-watchdog", "decide", requestId, decision]
        onStarted: {
            try {
                decideProc.write(password + "\n")
            } catch (e) { console.warn("escalation: could not hand the password over:", e) }
        }
    }

    // the one window a plugin's root request ever opens: it names the
    // plugin, the action and the exact command, and its answer (with the
    // password, written to the decide process's pipe) is final
    EscalationWindow {
        id: escWindow
        theme: wd.theme
        onDecided: (requestId, decision, password) =>
            wd.answerEscalation(requestId, decision, password)
    }

    function known(id) {
        return wd.pluginManager && wd.pluginManager.findPlugin(id) !== null
    }

    function notify(title, body) {
        Quickshell.execDetached(["notify-send", "-a", "Aequalyn", String(title), String(body || "")])
    }

    // The supervisor may not be running (a shell started by hand, an install
    // where the autostart glue was not updated). Start it: it is idempotent,
    // and it adopts a running shell instead of replacing it.
    property Process starter: Process {
        running: true
        command: ["sh", "-c",
            'command -v aequalyn-watchdog >/dev/null 2>&1 && aequalyn-watchdog start --adopt >/dev/null 2>&1 || true']
    }

    // And keep it alive: if the supervisor is killed behind the shell's back,
    // bring it back (unless it was stopped by hand -- `stop` leaves a marker
    // that `ensure` respects). One short-lived process every two minutes.
    Timer {
        running: true
        repeat: true
        interval: 120000
        onTriggered: Quickshell.execDetached(
            ["sh", "-c", 'command -v aequalyn-watchdog >/dev/null 2>&1 && aequalyn-watchdog ensure >/dev/null 2>&1 || true'])
    }
}
