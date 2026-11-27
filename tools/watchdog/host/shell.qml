// The sandbox host: one QuickShell instance per plugin, started and watched
// by aequalyn-watchdog. The plugin named in AEQUALYN_PLUGIN_ID loads from
// AEQUALYN_PLUGIN_SOURCE and runs with its own process, its own memory and
// its own IPC, so a crash, a hang or a leak in it takes down only this
// process -- never the main shell. The watchdog restarts it (and turns the
// plugin off, with a message in the corner, if it keeps failing).
//
// This file is reached through a per-plugin config directory the watchdog
// generates under ~/.local/state/aequalyn/watchdog/hosts/<id>/, with
// symlinks to the real config folders so `root:/` imports resolve exactly as
// they do in the main shell, and a quickshell.json that turns auto-reload
// off (only the main shell reloads when files change).
//
// AEQUALYN_SANDBOX_TEST is for exercising the watchdog itself:
//   leak  grow the heap until the memory budget trips
//   hang  block the engine so the heartbeat goes unanswered
//   crash kill -9 itself after a few seconds
//   esc   reach for root without the gate, so the tripwire stops it
//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1

import Quickshell
import Quickshell.Io
import QtQuick

ShellRoot {
    id: host

    readonly property string pluginId: Quickshell.env("AEQUALYN_PLUGIN_ID") || ""
    readonly property string pluginSource: Quickshell.env("AEQUALYN_PLUGIN_SOURCE") || ""
    readonly property string testMode: Quickshell.env("AEQUALYN_SANDBOX_TEST") || ""
    readonly property real startedAt: Date.now()

    // ---- the plugin itself ------------------------------------------------
    Loader {
        id: loader
        active: host.pluginSource !== ""
        source: host.pluginSource
        onStatusChanged: if (status === Loader.Error) {
            console.error("sandbox: plugin failed to load:", host.pluginId, "-", host.pluginSource)
            // a plugin that cannot even load counts as a failed start: quit,
            // and the watchdog decides (restart now, turn off if repeated)
            Qt.quit()
        }
        onLoaded: console.info("sandbox: plugin loaded:", host.pluginId)
    }

    // ---- what the watchdog can call ---------------------------------------
    // Selected by process: `qs ipc --pid <this pid> call sandbox ping`.
    IpcHandler {
        target: "sandbox"

        // heartbeat: answered only while this engine turns. A hung plugin
        // blocks it, the call times out, and the watchdog acts.
        function ping(): string { return "ok" }

        // what the host knows about itself
        function info(): string {
            return JSON.stringify({ id: host.pluginId, source: host.pluginSource, test: host.testMode,
                                   pid: Quickshell.processId, uptime: Math.round((Date.now() - host.startedAt) / 1000) })
        }

        // The plugin's own settings live here, in its process. The main shell's
        // KitHost.get() cannot see them, so Settings and quick panels read and
        // write them through these two calls instead.
        function settings(pluginId: string): string {
            if (pluginId !== host.pluginId) return "wrong plugin"
            const p = loader.item
            const store = p ? p.settingsStore : null
            return store ? JSON.stringify(store.values) : "{}"
        }

        function set(pluginId: string, key: string, value: string): string {
            if (pluginId !== host.pluginId) return "wrong plugin"
            const p = loader.item
            const store = p ? p.settingsStore : null
            if (!store) return "no store"
            let v = value
            try { v = JSON.parse(value) } catch (e) {}
            store.set(key, v)
            return "ok"
        }

        // a clean stop, when the plugin is being turned off
        function stop(): string { Qt.quit(); return "ok" }
    }

    // ---- self-tests for the watchdog --------------------------------------
    // AEQUALYN_SANDBOX_TEST=leak: ~12 MiB/s of live JS, so the RAM budget is
    // breached and the watchdog's restart-then-disable path can be watched.
    Timer {
        running: host.testMode === "leak"
        repeat: true
        interval: 1000
        property var ballast: []
        onTriggered: {
            const chunk = []
            for (let i = 0; i < 200000; i++) chunk.push({ i, s: "ballast " + i + " " + Math.random() })
            ballast.push(chunk)
        }
    }

    // AEQUALYN_SANDBOX_TEST=hang: block this engine forever -- the heartbeat
    // goes unanswered and the watchdog restarts the process.
    Timer {
        running: host.testMode === "hang"
        interval: 2000
        onTriggered: { while (true) {} }
    }

    // AEQUALYN_SANDBOX_TEST=crash: an uncatchable death (SIGKILL on self),
    // the way a broken C++ path would kill a plugin.
    Process {
        running: host.testMode === "crash"
        command: ["sh", "-c", 'sleep 4 && kill -9 $PPID']
    }

    // AEQUALYN_SANDBOX_TEST=esc: reach for root WITHOUT the gate, the way
    // a rogue plugin would -- `sudo` straight from the process tree. The
    // watchdog's tripwire is watching: it kills the attempt, says so with
    // the exact command in a notification, and counts it like any other
    // fault (three in ten minutes turn the plugin off). The command
    // lingers: a run that finishes between the tripwire's samples would
    // slip past it (the documented limit), and a demo must not.
    Process {
        running: host.testMode === "esc"
        command: ["sudo", "sleep", "30"]
    }
}
