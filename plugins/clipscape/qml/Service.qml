pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/theme-switcher"
import "js/Schema.js" as Schema
import "js/Clips.js" as Clips
import "js/Theme.js" as Border
import "core"

// The always-loaded part of Clipscape for Aequalyn: settings, the history, the
// watcher and ipc. The colors come from the shell's theme singleton, not from
// the shell's theme singleton.
Item {
    id: root

    visible: false

    readonly property string pluginId: "clipscape"
    property var manifest: null

    function readText(fv) {
        try { return String(typeof fv.text === "function" ? fv.text() : fv.text) } catch (e) { return "" }
    }

    FileView {
        id: manifestFile
        path: decodeURIComponent(Qt.resolvedUrl("../manifest.json").toString().replace(/^file:\/\//, ""))
        onLoaded: {
            if (root.manifest) return
            let m = null
            try { m = JSON.parse(root.readText(manifestFile)) } catch (e) { m = null }
            const v = m && typeof m.version === "string" && /^[0-9A-Za-z.+-]{1,32}$/.test(m.version) ? m.version : ""
            root.manifest = { version: v }
        }
    }

    function openUrl(url) {
        const u = String(url || "").trim()
        if (!/^https?:\/\/[A-Za-z0-9.-]+(:[0-9]{1,5})?(\/[A-Za-z0-9._~%!$&'()*+,;=:@\/?#-]*)?$/.test(u) || u.length > 2000) return false
        opener.command = ["xdg-open", u]
        opener.running = true
        return true
    }
    function showFolder(path) {
        const p = String(path || "")
        if (p.charAt(0) !== "/" || p.indexOf("\n") >= 0 || p.length > 4096) return false
        const dir = p.replace(/\/[^\/]*$/, "") || "/"
        opener.command = ["xdg-open", dir]
        opener.running = true
        return true
    }
    Process { id: opener }

    // ---- settings ---------------------------------------------------------------------
    SettingsStore { id: settingsStore }
    property alias store: settingsStore
    readonly property var cfg: Schema.resolve(settingsStore.values)

    function setValue(key, value) {
        if (Schema.isSetting(key)) settingsStore.set(key, Schema.clean(key, value))
    }

    readonly property bool paused: settingsStore.values.paused === true
    function setPaused(v) { settingsStore.set("paused", v === true ? true : null) }
    function togglePaused() { setPaused(!paused) }

    readonly property string lastFilter: Clips.FILTER_KEYS.indexOf(String(settingsStore.values.lastFilter)) >= 0
        ? String(settingsStore.values.lastFilter) : "all"
    function rememberFilter(f) {
        if (Clips.FILTER_KEYS.indexOf(f) >= 0 && f !== lastFilter) settingsStore.set("lastFilter", f)
    }

    UiState {
        id: ux
        store: settingsStore
        cfg: root.cfg
        barFg: Theme.textPrimary
        barBg: Theme.bgBase
        themeAccent: Theme.accentPrimary
        fontName: "JetBrainsMono Nerd Font"
        borderColors: root.borderColors
        borderAngle: root.borderAngle
        onPickerRequested: root.openPicker("")
    }
    property alias ui: ux

    // ---- the history -------------------------------------------------------------------
    ClipStore {
        id: clipStore
        cfg: root.cfg
        paused: root.paused
    }
    property alias clips: clipStore

    readonly property int count: clipStore.clips.length

    // ---- the surfaces ------------------------------------------------------------------
    // The picker and the bar button listen; this keeps the service independent
    // of a plugin host (summon/serviceFor/hide).
    signal pickerRequested(var payload)
    signal pickerToggleRequested()
    signal panelRequested(string tab, bool toggle)

    function openPicker(payload) { pickerRequested(String(payload || "")) }
    function togglePicker() { pickerToggleRequested() }
    function openPanel(tab) { panelRequested(String(tab || "clips"), true) }

    // ---- the theme's window border -----------------------------------------------------
    // Aequalyn writes the active border into ~/.config/hypr/aequalyn/colors.lua.
    property var borderColors: []
    property real borderAngle: 0
    FileView {
        id: borderFile
        path: Quickshell.env("HOME") + "/.config/hypr/aequalyn/colors.lua"
        watchChanges: true
        onLoaded: {
            const b = Border.parseBorder(root.readText(borderFile))
            root.borderColors = b.colors
            root.borderAngle = b.angle
        }
        onLoadFailed: { root.borderColors = []; root.borderAngle = 0 }
    }

    // ---- ipc: qs ipc call clipscape <function> ----------------------------------------
    IpcHandler {
        target: root.pluginId

        function picker(): string { root.openPicker(""); return "ok" }
        function toggle(): string { root.togglePicker(); return "ok" }
        function panel(): string { root.openPanel("clips"); return "ok" }
        function settings(): string { root.openPanel("settings"); return "ok" }

        function pause(): string { root.setPaused(true); return "paused" }
        function resume(): string { root.setPaused(false); return "recording" }
        function togglePause(): string { root.togglePaused(); return root.paused ? "paused" : "recording" }

        function copy(n: string): string { return root.useNth(n, "copy") }
        function paste(n: string): string { return root.useNth(n, "paste") }

        function clear(): string { clipStore.clearUnpinned(); return "cleared" }
        function clearAll(): string { clipStore.clearAll(); return "cleared" }

        function status(): string {
            return JSON.stringify({
                clips: root.count,
                pinned: clipStore.pinnedCount,
                recording: !root.paused,
                ready: clipStore.ready
            })
        }
    }

    function useNth(n, how) {
        const i = parseInt(String(n || "1"), 10)
        if (!(i >= 1 && i <= clipStore.clips.length)) return "no clip " + String(n).slice(0, 8)
        return clipStore.use(clipStore.clips[i - 1].id, how) ? "ok" : "failed"
    }
}
