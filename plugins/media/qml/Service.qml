import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "root:/plugins/media"
import "core"
import "js/Visuals.js" as Visuals
import "js/Schema.js" as Schema
import "js/Theme.js" as Theme

// Shared brain of Media (the Media plugin, Plugins.js). Reads the active MPRIS player
// and runs ONE audio helper (viz.py) for every widget instance.
// The helper only runs while something is playing and a widget wants it.
// The bar's media widget and the control center's Media page reach it through
// MediaHost.
//
// IPC:  qs ipc call media <status|play|pause|playPause|next|previous|style <name>|...>
Item {
    id: root

    property var theme: null                  // the shell's palette (ts.theme)

    readonly property string pluginId: "media"
    readonly property var styleNames: Visuals.keys

    // ---- settings ----------------------------------------------------------------
    // What was changed in the settings panel, kept in memory (instant) and saved to
    // ~/.local/state/aequalyn/media/settings.json. Saved looks go to looks.json next
    // to it, so Reset all never touches them.
    property SettingsStore store: SettingsStore { }
    property SettingsStore looksStore: SettingsStore { fileName: "looks.json" }
    readonly property var local: store.values

    function setSetting(key, value) {
        store.set(key, Schema.cleanValue(key, value))
        // a style picked by hand always wins over one set from outside
        if (key === "vizStyle") styleOverride = ""
    }

    // ---- looks --------------------------------------------------------------------
    // The values to compare a look against: the defaults under what was changed.
    function current() { return Schema.resolve(null, store.values) }

    readonly property var slots: {
        const raw = looksStore.values.slots
        const out = []
        for (let i = 0; i < Schema.SLOTS; i++) out.push(Array.isArray(raw) ? Schema.cleanSettings(raw[i]) : null)
        return out
    }
    readonly property bool canUndo: !!Schema.cleanSettings(looksStore.values.undo)

    // Put on a look (a ready made one by key, or a set of values), or with `all` a whole
    // saved place, every setting in it. Everything as it was before is kept, so it can
    // be undone.
    function wear(look, all) {
        const clean = all ? Schema.cleanSettings(look) : Schema.cleanLook(look)
        if (!clean) return false
        looksStore.set("undo", Schema.settingsOf(current()))
        store.setMany(clean)
        styleOverride = ""
        return true
    }
    function applyLook(key) { return wear(Schema.lookSet(key)) }
    function nextLook() {
        const keys = Schema.lookOptions
        const now = Schema.lookNow(current())
        const i = keys.indexOf(now)
        return applyLook(keys[(i + 1) % keys.length]) ? keys[(i + 1) % keys.length] : ""
    }
    function undoLook() {
        const back = Schema.cleanSettings(looksStore.values.undo)
        if (!back) return false
        looksStore.set("undo", null)
        store.setMany(back)
        styleOverride = ""
        return true
    }
    function setSlot(n, look) {
        const list = []
        for (let i = 0; i < Schema.SLOTS; i++) list.push(slots[i])
        list[n] = look
        looksStore.set("slots", list)
    }
    function saveSlot(n) {
        if (!(n >= 0 && n < Schema.SLOTS)) return false
        setSlot(n, Schema.settingsOf(current()))
        return true
    }
    function saveNew() {
        const free = slots.indexOf(null)
        return free >= 0 && saveSlot(free) ? free : -1
    }
    function loadSlot(n) { return n >= 0 && n < Schema.SLOTS && !!slots[n] && wear(slots[n], true) }
    function clearSlot(n) { if (n >= 0 && n < Schema.SLOTS) setSlot(n, null) }
    function exportLook() { return JSON.stringify(Schema.lookOf(current())) }
    function importLook(text) {
        if (typeof text !== "string" || text.length > 8192) return false
        try { return wear(JSON.parse(text)) } catch (e) { return false }
    }

    // ---- the theme's colors -------------------------------------------------------
    // For the Palette and Window border color modes: the shell theme's own colours, and
    // the active window border from the colours Aequalyn writes for Hyprland
    // (~/.config/hypr/aequalyn/colors.lua). Only #rrggbb values and an angle are taken.
    function hexOf(c) {
        if (!c) return ""
        const h = (v) => ("0" + Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16)).slice(-2)
        return "#" + h(c.r) + h(c.g) + h(c.b)
    }
    readonly property var themePalette: root.theme                    // ["#rrggbb", ...]
        ? [root.theme.accentPrimary, root.theme.accentCyan, root.theme.accentGreen, root.theme.accentOrange,
           root.theme.accentRed, root.theme.textPrimary].map(c => root.hexOf(c)).filter(h => h !== "")
        : []
    property var luaBorder: ({ colors: [], angle: 0 })
    readonly property var borderColors: luaBorder.colors.length > 0 ? luaBorder.colors : themePalette.slice(0, 2)
    readonly property real borderAngle: luaBorder.colors.length > 0 ? luaBorder.angle : 45

    // the cover's main colors, worked out by the widget that shows it
    property var coverColors: []
    onAlbumArtChanged: coverColors = []

    function fileText(fv) {
        try { const t = typeof fv.text === "function" ? fv.text() : fv.text; return typeof t === "string" ? t : "" } catch (e) { return "" }
    }
    FileView {
        id: borderLua
        printErrors: false                  // rewritten whole on every theme switch
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/hypr/aequalyn/colors.lua"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.luaBorder = Theme.parseBorder(root.fileText(borderLua))
        onLoadFailed: root.luaBorder = ({ colors: [], angle: 0 })
    }

    // ---- at login ---------------------------------------------------------------------
    // Once the saved settings are in: start on Auto or a saved look if asked to, and
    // start playing if asked to.
    property bool startupDone: false
    property bool autoPlayPending: false
    readonly property bool storesLoaded: store.loaded && looksStore.loaded
    onStoresLoadedChanged: if (storesLoaded && !startupDone) Qt.callLater(root.startup)
    function startup() {
        startupDone = true
        const c = current()
        if (c.startPlayer === "auto" && c.player !== "auto") store.set("player", "auto")
        const n = parseInt(c.startLook, 10)
        if (n >= 1 && slots[n - 1]) store.setMany(slots[n - 1])
        if (c.autoPlay) autoPlayPending = true
    }
    // the player may need a moment to show up after login
    Timer {
        interval: 1000
        repeat: true
        running: root.autoPlayPending
        property int tries: 0
        onTriggered: {
            tries++
            const p = root.player || root.findPlayer(root.preferred)
            if (p) {
                try { if (!p.isPlaying) { if (p.canPlay) p.play(); else if (p.canTogglePlaying) p.togglePlaying() } } catch (e) { }
                root.autoPlayPending = false
            } else if (tries >= 30) root.autoPlayPending = false
        }
    }

    // ---- media -----------------------------------------------------------
    // The players, read straight from MPRIS.
    readonly property var players: Mpris.players ? Mpris.players.values : []
    readonly property var player: pickPlayer(players)
    readonly property string title: player ? clean(player.trackTitle, "") : ""
    readonly property string artist: player ? clean(player.trackArtist, "") : ""
    readonly property bool hasMedia: !!player && (title !== "" || artist !== "")
    readonly property bool playing: !!player && !!player.isPlaying
    // nothing to show: no song, or a player that has stopped (a paused song still counts)
    readonly property bool stopped: !hasMedia || (!playing && player.playbackState === MprisPlaybackState.Stopped)
    // The cover as the player gives it, and as it is shown: a small, clean copy made
    // by ArtCache (see js/Art.js), never the player's file or address itself.
    readonly property string artUrl: {
        if (!player || !player.trackArtUrl) return ""
        const url = String(player.trackArtUrl)
        return url.length > 2048 ? "" : url
    }
    ArtCache { id: artCache; url: root.artUrl; pythonPath: root.pythonPath; unpackPath: root.pluginSourceDir + "/helper/art.py" }
    readonly property string albumArt: artCache.file
    // the player's own logo (the icon of its app), for a song that comes without a cover
    readonly property string appIcon: {
        if (!player) return ""
        const keys = [String(player.desktopEntry || ""), String(player.identity || ""),
                      baseId(idOf(player)).replace(/^org\.mpris\.MediaPlayer2\./, "")]
        for (const k of keys) {
            if (k === "") continue
            let e = null
            try { e = DesktopEntries.byId(k) || DesktopEntries.heuristicLookup(k) } catch (err) { e = null }
            if (e && e.icon) {
                const p = Quickshell.iconPath(e.icon, true)
                if (p) return p
            }
        }
        return ""
    }
    // what the bar shows for a song: its cover, else its player's logo
    readonly property string coverOrLogo: albumArt !== "" ? albumArt : appIcon

    // "auto" follows whatever is playing; otherwise the D-Bus name of the
    // player the user picked in the settings panel.
    property string preferred: "auto"

    function idOf(p) { return String(p.dbusName || p.identity || "") }
    function baseId(s) { return String(s).replace(/\.instance\d+$/, "") }

    // Exact D-Bus name wins. The instance-less fallback (browser / mpv ids change
    // on every launch) only applies when it is unambiguous.
    function findPlayer(id) {
        if (!id || id === "auto") return null
        const list = players
        let loose = null
        let count = 0
        for (let i = 0; i < list.length; i++) {
            const p = list[i]
            if (!p) continue
            const a = idOf(p)
            if (a === id) return p
            if (baseId(a) === baseId(id)) { loose = p; count++ }
        }
        return count === 1 ? loose : null
    }

    // ---- recognising what is really behind a generic player -------------------
    // mpv, vlc, browsers... all show up under one name. MPRIS carries the track
    // URL and cover URL, which say where the audio comes from.
    function metaOf(p) {
        try { return p.metadata || ({}) } catch (e) { return ({}) }
    }
    function urlOf(p) {
        const m = metaOf(p)
        return String(m["xesam:url"] || m["mpris:url"] || "")
    }
    function appOf(p) {
        let n = String(p.identity || "").trim()
        if (n === "")
            n = baseId(idOf(p)).replace(/^org\.mpris\.MediaPlayer2\./, "")
        return n !== "" ? n : "Unknown player"
    }
    function isGeneric(app) {
        return /^(mpv|vlc|mplayer|mpd|cmus|celluloid|haruna|firefox|mozilla firefox|chromium|google chrome|chrome|brave|vivaldi|zen|librewolf|microsoft edge)\b/i.test(app)
    }
    function sourceOf(p) {
        const sourceRules = [
            [/music\.youtube\.com|ytmusic|googleusercontent\.com/, "YouTube Music"],
            [/youtube\.com|youtu\.be|googlevideo|ytimg|ytdl:/, "YouTube"],
            [/spotify|scdn\.co/, "Spotify"],
            [/soundcloud|sndcdn/, "SoundCloud"],
            [/bandcamp|bcbits/, "Bandcamp"],
            [/tidal\.com/, "Tidal"],
            [/deezer|dzcdn/, "Deezer"],
            [/twitch\.tv|ttvnw/, "Twitch"],
            [/^file:/, "Local file"]
        ]
        const url = urlOf(p).toLowerCase()
        const art = String(p.trackArtUrl || "").toLowerCase()
        const hay = url + " " + art
        for (let i = 0; i < sourceRules.length; i++) {
            if (sourceRules[i][0].test(url) || (i < 2 && sourceRules[i][0].test(art)))
                return sourceRules[i][1]
        }
        // A web stream with no known length is a live station.
        const web = /^(https?|rtmps?|icy|mms):/.test(url)
        const live = !p.lengthSupported || !(Number(p.length) > 0)
        if (web && live) return "Radio"
        return ""
    }
    function nameOf(p) {
        const app = appOf(p)
        if (isGeneric(app)) {
            const src = sourceOf(p)
            if (src !== "") return src
        }
        return app
    }
    function trackOf(p) {
        const t = clean(p.trackTitle, "")
        const a = clean(p.trackArtist, "")
        return (t !== "" && a !== "") ? a + " \u2013 " + t : (t !== "" ? t : a)
    }

    // Everything the settings panel needs to list the players.
    // Only republished when the content really changes, so the settings panel
    // does not rebuild its rows on every MPRIS property tick.
    property var playerList: []
    property string playerListJson: "[]"
    onPlayerListRawChanged: {
        const s = JSON.stringify(playerListRaw)
        if (s === playerListJson) return
        playerListJson = s
        playerList = playerListRaw
    }

    readonly property var playerListRaw: {
        const out = []
        const list = players
        for (let i = 0; i < list.length; i++) {
            const p = list[i]
            if (!p) continue
            const app = appOf(p)
            const name = nameOf(p)
            out.push({ id: idOf(p), name: name, via: name !== app ? app : "",
                       track: trackOf(p), playing: !!p.isPlaying, url: urlOf(p) })
        }
        // identical names (two unrecognised mpv's): number them
        const seen = ({})
        const total = ({})
        for (let a = 0; a < out.length; a++) total[out[a].name] = (total[out[a].name] || 0) + 1
        for (let b = 0; b < out.length; b++) {
            const nm = out[b].name
            if (total[nm] > 1) {
                seen[nm] = (seen[nm] || 0) + 1
                out[b].name = nm + " #" + seen[nm]
            }
        }
        return out
    }
    readonly property string activeId: player ? idOf(player) : ""
    readonly property var chosen: findPlayer(preferred)
    readonly property string selectedId: chosen ? idOf(chosen) : ""

    function pickPlayer(list) {
        const c = findPlayer(preferred)
        // A chosen player that is still loading (no track yet) or idle must not
        // hide another player that is actually playing.
        if (c && (c.isPlaying || !!(c.trackTitle || c.trackArtist))) {
            if (c.isPlaying) return c
            for (let k = 0; k < list.length; k++) {
                const o = list[k]
                if (o && o !== c && o.isPlaying && (o.trackTitle || o.trackArtist)) return o
            }
            return c
        }
        let fallback = null
        for (let i = 0; i < list.length; i++) {
            const p = list[i]
            if (!p) continue
            const hasTrack = !!(p.trackTitle || p.trackArtist)
            if (p.isPlaying && hasTrack) return p
            if (!fallback && hasTrack) fallback = p
        }
        return fallback
    }

    // Follow `id` and make it the one playing: every other player that is
    // playing gets paused, then the chosen one is started.
    function switchTo(playerId) {
        preferred = playerId
        const target = findPlayer(playerId)
        const list = players
        if (!target) return false
        for (let j = 0; j < list.length; j++) {
            const p = list[j]
            if (!p || p === target || !p.isPlaying) continue
            try {
                if (p.canPause) p.pause()
                else if (p.canTogglePlaying) p.togglePlaying()
            } catch (e) { }
        }
        try {
            if (!target.isPlaying) {
                if (target.canPlay) target.play()
                else if (target.canTogglePlaying) target.togglePlaying()
            }
        } catch (e) { }
        return true
    }

    // ---- follow external changes ------------------------------------------------
    // When something else starts playing (another app, a keyboard media key, a
    // browser tab...), follow it right away instead of sticking to the old pick.
    signal followed(string playerId)
    property bool pauseOthers: false       // pause the previous player when a new one starts
    property var playingIds: ({})
    property bool playingSeeded: false

    function syncPlaying() {
        const now = ({})
        let started = ""
        const list = players
        for (let i = 0; i < list.length; i++) {
            const p = list[i]
            if (!p || !p.isPlaying) continue
            const id = idOf(p)
            now[id] = true
            if (playingSeeded && !playingIds[id]) started = id
        }
        playingIds = now
        playingSeeded = true
        if (started === "") return
        if (pauseOthers) {
            for (let j = 0; j < list.length; j++) {
                const o = list[j]
                if (!o || !o.isPlaying || idOf(o) === started) continue
                try {
                    if (o.canPause) o.pause()
                    else if (o.canTogglePlaying) o.togglePlaying()
                } catch (e) { }
            }
        }
        if (preferred === "auto") return
        const cur = findPlayer(preferred)
        if (cur && idOf(cur) === started) return
        preferred = started
        store.set("player", started)
        followed(started)
    }

    onPlayersChanged: syncPlaying()

    Timer {
        interval: 400
        repeat: true
        running: true
        onTriggered: root.syncPlaying()
    }

    function clean(primary, fallback) {
        const s = String(primary || fallback || "").replace(/[\r\n\t]+/g, " ").trim()
        return s.length > 300 ? s.substring(0, 300) : s
    }

    // the player's own volume, when it has one
    function nudgeVolume(step) {
        if (!player) return false
        try {
            if (player.volumeSupported === false) return false
            player.volume = Math.max(0, Math.min(1, (Number(player.volume) || 0) + step))
            return true
        } catch (e) {
            return false
        }
    }

    function runAction(action) {
        if (!player) return false
        try {
            if (action === "playPause") player.togglePlaying()
            else if (action === "next") player.next()
            else if (action === "previous") player.previous()
            else return false
            return true
        } catch (e) {
            return false
        }
    }

    // ---- shared visualizer state -------------------------------------------
    property string styleOverride: ""      // set by IPC, cleared on shell restart
    property var levels: []                // 0..1 (spectrum) or -1..1 (scope)
    property bool receiving: false
    property string lastError: ""
    property bool fatal: false
    property bool shuttingDown: false
    property int failures: 0
    property bool stopping: false          // true while we are stopping the helper on purpose
    property int consumerCount: 0
    property var config: ({ style: "bars", bars: 20, fps: 30, gain: 100, smooth: 60, engine: "auto" })

    readonly property string mode: Visuals.isScope(config.style) ? "scope" : "spectrum"
    readonly property int frameSize: mode === "scope" ? 64 : config.bars
    readonly property bool shouldRun: !shuttingDown && !fatal && consumerCount > 0 && playing

    // the plugin's folder (plugins/media), where helper/ is
    readonly property string pluginSourceDir: decodeURIComponent(String(Qt.resolvedUrl("../")).replace(/^file:\/\//, "").replace(/\/$/, ""))
    readonly property string helperPath: pluginSourceDir + "/helper/viz.py"
    readonly property string pythonPath: "/usr/bin/python3"

    function register() { consumerCount = consumerCount + 1 }
    function unregister() { consumerCount = Math.max(0, consumerCount - 1) }

    function cycleStyle(current, step) {
        let i = styleNames.indexOf(current)
        if (i < 0) i = 0
        const n = styleNames.length
        styleOverride = styleNames[(i + (step < 0 ? n - 1 : 1)) % n]
    }

    function bounded(value, lo, hi, fallback) {
        const v = Number(value)
        if (!isFinite(v)) return fallback
        return Math.max(lo, Math.min(hi, Math.round(v)))
    }

    function configure(cfg) {
        const engines = ["auto", "cava", "builtin"]
        const next = {
            style: styleNames.indexOf(cfg.style) >= 0 ? cfg.style : "bars",
            bars: bounded(cfg.bars, 6, 64, 20),
            fps: bounded(cfg.fps, 15, 60, 30),
            gain: bounded(cfg.gain, 25, 400, 100),
            smooth: bounded(cfg.smooth, 0, 100, 60),
            engine: engines.indexOf(cfg.engine) >= 0 ? cfg.engine : "auto"
        }
        if (JSON.stringify(next) === JSON.stringify(config)) return
        const prev = config
        const modeChanged = Visuals.isScope(next.style) !== Visuals.isScope(prev.style)
        // The helper only cares about these. A pure style change (bars -> neon)
        // is drawn by the widget from the same data, so it needs no restart and
        // shows up on the very next frame.
        const helperChanged = modeChanged || next.bars !== prev.bars || next.fps !== prev.fps
            || next.gain !== prev.gain || next.smooth !== prev.smooth || next.engine !== prev.engine
        config = next
        if (modeChanged) levels = []
        failures = 0
        fatal = false
        if (helperChanged && shouldRun) restartHelper()
    }

    // ---- helper process lifecycle -----------------------------------------
    onShouldRunChanged: {
        if (shouldRun) {
            startTimer.restart()
        } else {
            stopHelper()
            receiving = false
            decayTimer.restart()
        }
    }

    function stopHelper() {
        if (!helper.running) return
        stopping = true
        helper.running = false
    }

    function restartHelper() {
        stopHelper()
        receiving = false
        startTimer.restart()
    }

    function helperEnvironment() {
        return {
            "LANG": "C.UTF-8",
            "LC_ALL": "C.UTF-8",
            "PATH": "/usr/bin",
            "HOME": Quickshell.env("HOME") || "",
            "XDG_RUNTIME_DIR": Quickshell.env("XDG_RUNTIME_DIR") || "",
            "PYTHONDONTWRITEBYTECODE": "1"
        }
    }

    function startHelper() {
        if (!shouldRun) return
        if (helper.running) {            // previous one is still shutting down
            startTimer.restart()
            return
        }
        decayTimer.stop()
        helper.environment = helperEnvironment()
        helper.exec([
            pythonPath, "-I", "-S", helperPath,
            "--mode", mode,
            "--engine", config.engine,
            "--bars", String(config.bars),
            "--fps", String(config.fps),
            "--gain", String(config.gain),
            "--smooth", String(config.smooth)
        ])
    }

    function handleExit(exitCode) {
        receiving = false
        if (stopping) {                  // we asked for this exit, so it is not a failure
            stopping = false
            return
        }
        if (!shouldRun) return
        if (exitCode === 127) {
            fatal = true
            lastError = "Missing dependency: pw-record (pipewire-audio) or cava for the chosen engine"
            return
        }
        failures = failures + 1
        if (failures >= 6) {
            fatal = true
            lastError = "Audio helper kept failing (last exit code " + exitCode + ")"
            return
        }
        retryTimer.restart()
    }

    function consumeLine(line) {
        const text = String(line)
        if (text.length > 4096) return
        const parts = text.trim().split(" ")
        if (parts.length < 2 || parts.length > 128) return
        const out = new Array(parts.length)
        const scope = mode === "scope"
        for (let i = 0; i < parts.length; i++) {
            let v = parseInt(parts[i], 10)
            if (isNaN(v)) return
            v = v / 100
            out[i] = scope ? Math.max(-1, Math.min(1, v)) : Math.max(0, Math.min(1, v))
        }
        levels = out
        receiving = true
        failures = 0
        lastError = ""
        staleTimer.restart()
    }

    function decayStep() {
        const next = []
        let peak = 0
        for (let i = 0; i < levels.length; i++) {
            const v = levels[i] * 0.78
            next.push(v)
            peak = Math.max(peak, Math.abs(v))
        }
        levels = next
        if (peak < 0.01) {
            levels = []
            decayTimer.stop()
        }
    }

    function shutdown() {
        shuttingDown = true
        startTimer.stop()
        retryTimer.stop()
        staleTimer.stop()
        decayTimer.stop()
        stopHelper()
    }

    Component.onCompleted: {
        MediaHost.svc = root
        helper.exited.connect(root.handleExit)
    }
    Component.onDestruction: {
        if (MediaHost.svc === root) MediaHost.svc = null
        root.shutdown()
    }

    Timer {
        id: startTimer
        interval: 180
        repeat: false
        onTriggered: root.startHelper()
    }

    Timer {
        id: retryTimer
        interval: 1500
        repeat: false
        onTriggered: root.startHelper()
    }

    // Quiet fall-off after pause instead of bars snapping to zero.
    Timer {
        id: decayTimer
        interval: 33
        repeat: true
        onTriggered: root.decayStep()
    }

    Timer {
        id: staleTimer
        interval: 900
        repeat: false
        onTriggered: root.receiving = false
    }

    // Safety net: if the process never reported back, try again.
    Timer {
        interval: 3000
        repeat: true
        running: root.shouldRun && !root.receiving && !helper.running
        onTriggered: root.startHelper()
    }

    Process {
        id: helper
        running: false
        clearEnvironment: true
        stdout: SplitParser {
            onRead: function(line) { root.consumeLine(line) }
        }
    }

    IpcHandler {
        target: root.pluginId

        function status(): string {
            return JSON.stringify({
                hasMedia: root.hasMedia,
                playing: root.playing,
                stopped: root.stopped,
                title: root.title,
                artist: root.artist,
                albumArt: root.albumArt,
                player: root.activeId,
                selected: root.selectedId,
                preferred: root.preferred,
                players: root.playerList,
                consumers: root.consumerCount,
                mode: root.mode,
                config: root.config,
                styleOverride: root.styleOverride,
                helperRunning: helper.running,
                receiving: root.receiving,
                failures: root.failures,
                fatal: root.fatal,
                lastError: root.lastError,
                helperPath: root.helperPath
            })
        }

        function restart(): string {
            root.fatal = false
            root.failures = 0
            root.lastError = ""
            if (root.shouldRun) root.restartHelper()
            return "ok"
        }

        function cycleStyle(): string {
            root.cycleStyle(root.styleOverride !== "" ? root.styleOverride : root.config.style, 1)
            return root.styleOverride
        }

        function resetStyle(): string {
            root.styleOverride = ""
            return "ok"
        }

        function switchPlayer(playerId: string): string {
            if (!root.switchTo(playerId)) return "not found"
            root.store.set("player", playerId)
            return "ok"
        }

        function look(key: string): string { return root.applyLook(key) ? "ok" : "unknown look" }
        function nextLook(): string { return root.nextLook() }
        function undo(): string { return root.undoLook() ? "ok" : "nothing to undo" }
        function save(slot: int): string { return root.saveSlot(slot - 1) ? "ok" : "slots are 1 to " + Schema.SLOTS }
        function saveNew(): string { const n = root.saveNew(); return n >= 0 ? String(n + 1) : "no free slot" }
        function load(slot: int): string { return root.loadSlot(slot - 1) ? "ok" : "empty slot" }
        function exportLook(): string { return root.exportLook() }
        function importLook(json: string): string { return root.importLook(json) ? "ok" : "not a look" }
        function set(key: string, value: string): string {
            if (!Schema.byKey[key]) return "unknown setting"
            root.setSetting(key, value)
            return JSON.stringify(root.current()[key])
        }

        function playPause(): string { return root.runAction("playPause") ? "ok" : "unhandled" }
        function next(): string { return root.runAction("next") ? "ok" : "unhandled" }
        function previous(): string { return root.runAction("previous") ? "ok" : "unhandled" }
    }
}
