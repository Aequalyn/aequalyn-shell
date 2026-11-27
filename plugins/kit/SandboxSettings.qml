pragma Singleton

// Settings bridge for plugins that run in the watchdog sandbox. Their KitStore
// lives in another process, so KitHost.get() is always null in the main shell:
// the Settings page and quick panels used to write into thin air. The sandbox
// host exposes its plugin's store over IPC (see tools/watchdog/host/shell.qml);
// this singleton caches reads and forwards writes there. In-process plugins
// keep taking the direct KitHost path, unchanged.
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: bridge
    property var cache: ({})

    function hostPath(id) {
        const state = Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"
        return state + "/aequalyn/watchdog/hosts/" + id
    }

    function value(id, key, fallback) {
        const plugin = KitHost.get(id)
        if (plugin && plugin.settingsStore) return plugin.settingsStore.get(key)
        const own = bridge.cache[id]
        return own && own[key] !== undefined ? own[key] : fallback
    }

    function setValue(id, key, value) {
        const plugin = KitHost.get(id)
        if (plugin && plugin.settingsStore) {
            plugin.settingsStore.set(key, value)
            return
        }
        const next = Object.assign({}, bridge.cache[id] || {})
        next[key] = value
        const copy = Object.assign({}, bridge.cache)
        copy[id] = next
        bridge.cache = copy
        bridge.writeProc.pluginId = id
        bridge.writeProc.exec({
            command: ["qs", "ipc", "-p", bridge.hostPath(id), "call", "sandbox",
                      "set", id, key, JSON.stringify(value)]
        })
    }

    function refresh(id) {
        if (!id) return
        const plugin = KitHost.get(id)
        if (plugin && plugin.settingsStore) return
        bridge.readProc.pluginId = id
        bridge.readProc.exec({
            command: ["qs", "ipc", "-p", bridge.hostPath(id), "call", "sandbox", "settings", id]
        })
    }

    property Process readProc: Process {
        id: readProc
        property string pluginId: ""
        stdout: StdioCollector {
            onStreamFinished: {
                let values = null
                try { values = JSON.parse(text) } catch (e) { return }
                if (!values || typeof values !== "object") return
                const copy = Object.assign({}, bridge.cache)
                copy[readProc.pluginId] = values
                bridge.cache = copy
            }
        }
    }

    property Process writeProc: Process {
        id: writeProc
        property string pluginId: ""
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "ok") console.warn("SandboxSettings: write failed:", text.trim())
                bridge.refresh(writeProc.pluginId)
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim()) console.warn("SandboxSettings:", text.trim())
        }
    }
}
