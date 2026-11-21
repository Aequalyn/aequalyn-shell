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
