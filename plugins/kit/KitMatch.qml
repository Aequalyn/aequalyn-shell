// The parts of one look everywhere that have to be done rather than read: the text in
// Showcase's font while Showcase leads, and a look for each theme. Loaded by PluginManager.
//
// A theme's look is the bar's, the docks', Showcase's (its cards and type, not its
// widgets), the cursor's and the fonts. It is taken down when another theme is put on, and
// put back with its theme. Kept in ~/.local/state/aequalyn/theme-looks.json.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/settings"
import "root:/plugins/atelier"
import "root:/plugins/plume"
import "root:/theme-switcher" as AeqTheme
import "root:/style/AequalynLooks.js" as Looks
import "root:/style/BarLooks.js" as BarLooks
import "root:/style/Style.js" as Style
import "root:/style/Match.js" as Match
import "root:/plugins/showcase/qml/js/Schema.js" as ShowSchema
import "root:/plugins/plume/js/Schema.js" as PlumeSchema

Singleton {
    id: root

    readonly property var match: AequalynSettings.matchCfg
    readonly property var showcase: KitHost.get("showcase")

    // ---- the text ----------------------------------------------------------------------------
    // Showcase leads and has a font of its own: the UI font is that one, when the computer
    // has it, until it no longer leads. The font from before comes back, unless another was
    // picked meanwhile.
    readonly property bool textLed: root.match.on && root.match.text && KitFollow.lead === "showcase"
    readonly property string textWant: root.textLed && root.showcase ? ShowSchema.ownFont(root.showcase.cfg.font) : ""
    readonly property bool textReady: AequalynSettings.ready && (!root.textLed || (root.showcase !== null && root.showcase.store.loaded))
    onTextWantChanged: textTimer.restart()
    onTextReadyChanged: textTimer.restart()
    Timer { id: textTimer; interval: 700; onTriggered: root.dressText() }
    function dressText() {
        if (!root.textReady || fontCheck.running) return
        if (root.textWant !== "") {
            if (root.textWant === AequalynSettings.uiFont) return
            fontCheck.family = root.textWant
            fontCheck.running = true
            return
        }
        const before = root.match.fontBefore, set = root.match.fontSet
        if (before === "") return
        if (AequalynSettings.uiFont === set) AequalynSettings.setFont("ui", before)
        AequalynSettings.setMatch({ fontBefore: "", fontSet: "" })
    }
    Process {
        id: fontCheck
        property string family: ""
        command: ["fc-list", "--quiet", ":family=" + fontCheck.family]
        onExited: code => {
            if (fontCheck.family !== root.textWant) { textTimer.restart(); return }
            if (code !== 0) return                 // only Showcase has it: the text stays
            const set = { fontSet: fontCheck.family }
            if (root.match.fontBefore === "") set.fontBefore = AequalynSettings.uiFont
            AequalynSettings.setMatch(set)
            AequalynSettings.setFont("ui", fontCheck.family)
        }
    }

    // ---- a look for each theme ------------------------------------------------------------
    property var looks: ({})
    property string lastTheme: ""
    property bool loaded: false
    // the theme that is on: its id, "*" for the wallpaper's colours, "" until it is known
    readonly property string themeNow: !AeqTheme.Theme.initialLoadDone ? ""
        : (AeqTheme.Theme.wallpaperMode ? "*" : AeqTheme.Theme.currentFolderId)
    readonly property bool ready: root.loaded && AequalynSettings.ready && root.themeNow !== ""
        && (!root.showcase || root.showcase.store.loaded) && (!PlumeHost.svc || PlumeHost.svc.store.loaded)
    onThemeNowChanged: themeTimer.restart()
    onReadyChanged: themeTimer.restart()
    Timer { id: themeTimer; interval: 250; onTriggered: root.themeChanged() }

    function themeChanged() {
        if (!root.ready || root.themeNow === root.lastTheme) return
        const from = root.lastTheme, to = root.themeNow
        root.lastTheme = to
        if (root.match.perTheme !== "off") {
            const next = Object.assign({}, root.looks)
            if (from !== "") next[from] = root.taken()
            root.looks = Match.trim(next, to)
            const mine = Match.clean(root.looks[to])
            if (mine) root.wear(mine)
            else if (root.match.perTheme === "auto" && from !== "") root.pick(to)
        }
        root.write()
    }

    // everything as it is worn now
    function taken() {
        const svc = AtelierHost.docks, show = root.showcase, pl = PlumeHost.svc
        const out = { bar: BarLooks.snapshot(AequalynSettings.barStyleCfg), ui: AequalynSettings.uiFont, mono: AequalynSettings.monoFont,
                      now: root.match.now, nowDock: root.match.nowDock }
        // Showcase's font on the text is Showcase's, not this theme's
        if (root.match.fontBefore !== "" && AequalynSettings.uiFont === root.match.fontSet) out.ui = root.match.fontBefore
        if (svc) out.docks = svc.docks.map(d => {
            const o = { followBar: d.followBar }
            for (const k of svc.barKeys) o[k] = d[k]
            return o
        })
        if (show) out.showcase = Match.cardOf(ShowSchema, show.cfg)
        if (pl) out.cursor = Match.cursorOf(PlumeSchema, pl.cfg)
        return out
    }
    function wear(l) {
        const svc = AtelierHost.docks, show = root.showcase, pl = PlumeHost.svc
        if (l.bar) AequalynSettings.setBarStyle(Object.assign({}, AequalynSettings.barStyleCfg, l.bar))
        if (svc && l.docks) svc.wearLooks(l.docks)
        if (show && l.showcase) show.store.setMany(Match.cardOf(ShowSchema, l.showcase))
        if (pl && l.cursor) pl.store.setMany(Match.cursorOf(PlumeSchema, l.cursor))
        if (l.ui && l.ui !== AequalynSettings.uiFont) AequalynSettings.setFont("ui", l.ui)
        if (l.mono && l.mono !== AequalynSettings.monoFont && !AequalynSettings.fontSame) AequalynSettings.setFont("mono", l.mono)
        AequalynSettings.setMatch(Object.assign({ now: l.now, nowDock: l.nowDock }, { fontBefore: "", fontSet: "" }))
        textTimer.restart()
    }
    // a theme worn for the first time: one of the bar's ready made looks, always the same one
    function pick(id) {
        const key = Match.pickFor(id, Looks.bar)
        AequalynSettings.setBarStyle(Object.assign(BarLooks.withLook(AequalynSettings.barStyleCfg, key),
            { enabled: true, chips: AequalynSettings.barStyleCfg.chips }))
        AequalynSettings.touched("bar")
    }
    // the theme that is on has no look of its own any more: it keeps what is worn now
    function forget() { root.looks = ({}); root.write() }
    readonly property int count: Object.keys(root.looks).length

    readonly property string dir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/aequalyn"
    function write() {
        if (!root.loaded) return
        file.setText(JSON.stringify({ last: root.lastTheme, looks: root.looks }) + "\n")
    }
    Process {
        id: mkdir
        command: ["mkdir", "-p", root.dir]
        running: true
        onExited: if (!root.loaded) file.reload()
    }
    FileView {
        id: file
        path: root.dir + "/theme-looks.json"
        printErrors: false             // no file until the first theme change
        onLoaded: {
            if (root.loaded) return
            try {
                const d = JSON.parse(file.text() || "{}")
                root.lastTheme = typeof d.last === "string" ? d.last : ""
                const out = {}
                for (const k in (d.looks || {})) { const l = Match.clean(d.looks[k]); if (l && /^[A-Za-z0-9._*-]{1,80}$/.test(k)) out[k] = l }
                root.looks = out
            } catch (e) { root.looks = ({}) }
            root.loaded = true
        }
        onLoadFailed: root.loaded = true
    }
}
