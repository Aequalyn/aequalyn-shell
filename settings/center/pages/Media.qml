// Media (plugins/media): what is playing on the bar. Looks to wear in a click, then a tab
// per group of its settings: the player it follows, the visualizer, its colours, the
// text, the cover, the plate behind it (shape, surface, edge), effects and behaviour.
// The rows are the plugin's own (plugins/media/qml/panel), in the control center's
// colours; every change goes through its service, which applies and saves it at once.
import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "root:/settings"
import "root:/plugins/media"
import "root:/plugins/media/qml/js/Schema.js" as Schema
import "root:/plugins/media/qml/panel" as MediaPanel
import ".."

CcPage {
    id: page
    title: "Media"
    plugin: "media"
    sub: "What is playing, on the bar: a live visualizer, the title, the cover and the buttons."

    readonly property var svc: MediaHost.svc
    readonly property var cfg: svc ? Schema.resolve(null, svc.local) : Schema.defaults()
    // its tabs: Looks, then its settings, without About and the ones for its own popup
    // window (the Window tab, and the cover's In this panel), which Aequalyn doesn't have
    readonly property var settingTabs: Schema.tabs
        .filter(t => t.key !== "looks" && t.key !== "about" && t.key !== "window")
        .map(t => Object.assign({}, t, { groups: (t.groups || []).filter(g => g.title !== "In this panel") }))
    tabs: ["Looks"].concat(settingTabs.map(t => t.title))
    readonly property var categoryData: page.tab > 0 ? settingTabs[page.tab - 1] : null
    readonly property var plateColors: page.svc ? page.svc.borderColors : []
    readonly property var stylePalette: ({
        bg: [Cc.theme.bgBase.r * 255, Cc.theme.bgBase.g * 255, Cc.theme.bgBase.b * 255],
        fg: [Cc.theme.textPrimary.r * 255, Cc.theme.textPrimary.g * 255, Cc.theme.textPrimary.b * 255],
        ac: [Cc.theme.accentPrimary.r * 255, Cc.theme.accentPrimary.g * 255, Cc.theme.accentPrimary.b * 255],
        border: page.plateColors,
        borderAngle: page.svc ? page.svc.borderAngle : 0
    })
    property var pasteRow: null
    property var pasteTarget: null
    property bool confirmReset: false
    Timer { id: resetTimer; interval: 2500; onTriggered: page.confirmReset = false }

    function requestPaste(row, target) {
        if (pasteProc.running) return
        pasteRow = row
        pasteTarget = target
        pasteProc.running = true
    }
    function finishPaste(raw) {
        if (pasteRow && pasteTarget) pasteRow.insertPasted(pasteTarget, raw)
        pasteRow = null
        pasteTarget = null
    }
    Process {
        id: pasteProc
        command: ["sh", "-c", "timeout 2 wl-paste --no-newline 2>/dev/null | head -c 1024"]
        stdout: StdioCollector {
            onStreamFinished: page.finishPaste(text)
        }
    }

    CcNote {
        visible: !page.svc
        text: "Media is off: the bar shows the plain Now playing. Turn it on above, and it starts at once."
    }

    CcSection {
        visible: !!page.svc && page.categoryData !== null && page.categoryData.kind === "players"
        title: "Follow a player"
        hint: "Choose a player, or let Media follow whichever one is active."
        CcChoice {
            options: [{ key: "auto", label: "Auto" }].concat(page.svc ? page.svc.playerList.map(p => ({ key: p.id, label: p.name })) : [])
            current: page.cfg.player || "auto"
            onChosen: key => {
                if (!page.svc) return
                page.svc.store.set("player", key)
                if (key !== "auto") page.svc.switchTo(key)
            }
        }
        CcNote {
            visible: page.svc && page.svc.playerList.length === 0
            text: "No media players are available yet. Start a music app or play audio in a browser."
        }
    }

    Repeater {
        model: page.svc && page.categoryData ? page.categoryData.groups : []
        delegate: CcSection {
            required property var modelData
            title: modelData.title
            enabled: !!page.svc
            // the plugin's rows, at the size every plugin's settings have here
            CcPluginRows {
            Repeater {
                model: modelData.items || []
                delegate: MediaPanel.SettingRow {
                    id: row
                    required property var modelData
                    readonly property var it: modelData
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    Layout.bottomMargin: 6
                    label: it.label
                    hint: it.hint || ""
                    kind: it.kind
                    options: it.options || []
                    labels: it.labels || ({})
                    abouts: it.abouts || ({})
                    presets: it.presets || []
                    maxLength: it.maxLength !== undefined ? it.maxLength : 256
                    min: it.min !== undefined ? it.min : 0
                    max: it.max !== undefined ? it.max : 100
                    step: it.step !== undefined ? it.step : 1
                    divisor: it.divisor !== undefined ? it.divisor : 1
                    decimals: it.decimals !== undefined ? it.decimals : 0
                    defaultValue: it.fallback
                    value: page.cfg[it.key]
                    dimmed: !Schema.active(it, page.cfg)
                    fg: Cc.theme.textPrimary
                    accent: Cc.theme.accentPrimary
                    bg: Cc.theme.bgBase
                    panel: Cc.theme.bgSurface
                    barFg: Cc.theme.textPrimary
                    fontFamily: Cc.sans
                    customColor: String(page.cfg.customColor || "#7aa2f7")
                    customColor2: String(page.cfg.customColor2 || "#f7768e")
                    accentColor: Cc.theme.accentPrimary
                    themeColors: page.svc ? page.svc.themePalette : []
                    borderColors: page.svc ? page.svc.borderColors : []
                    coverColors: page.svc ? page.svc.coverColors : []
                    schemeSwatches: ({
                        theme: { bg: Cc.theme.bgBase, ink: Cc.theme.textPrimary, ac: Cc.theme.accentPrimary },
                        borders: { bg: Cc.theme.bgBase, ink: Cc.theme.textPrimary,
                                   ac: page.plateColors.length ? page.plateColors[0] : Cc.theme.accentPrimary,
                                   acs: page.plateColors.slice(0, 3) },
                        custom: { bg: page.cfg.panelBgColor, ink: page.cfg.panelTextColor, ac: page.cfg.panelCustomColor },
                        monochrome: { bg: Cc.theme.bgSurface, ink: Cc.theme.textPrimary, ac: Cc.theme.textSecondary }
                    })
                    demoSpectrum: [0.25, 0.45, 0.7, 0.55, 0.85, 0.6, 0.92, 0.5]
                    demoScope: [0, 0.5, 0.8, 0.3, -0.3, -0.8, -0.5, 0]
                    styleKey: it.key
                    styleCfg: it.kind === "style" ? page.cfg : ({})
                    stylePal: it.kind === "style" ? page.stylePalette : null
                    onEdited: value => page.svc.setSetting(it.key, value)
                    onClipboardPaste: (target, maxBytes) => page.requestPaste(row, target)
                }
            }
            }
        }
    }

    MediaPanel.LooksPage {
        visible: !!page.svc && page.tab === 0
        Layout.fillWidth: true
        svc: page.svc
        cfg: page.cfg
        fg: Cc.theme.textPrimary
        ink: Cc.theme.textPrimary
        accent: Cc.theme.accentPrimary
        inkOnFg: Cc.theme.bgBase
        fontFamily: Cc.sans
        levels: page.svc && page.svc.playing ? page.svc.levels : [0.2, 0.4, 0.7, 0.5, 0.8, 0.3]
        colorCtx: ({ accent: [Cc.theme.accentPrimary.r * 255, Cc.theme.accentPrimary.g * 255, Cc.theme.accentPrimary.b * 255], palette: [], border: [], cover: [] })
    }

    CcMore {
        visible: !!page.svc && page.tab > 0
        title: "Start over"
        CcNote { text: "Every Media setting back to how it came. Your saved looks stay." }
        CcButton {
            text: page.confirmReset ? "Really reset?" : "Reset Media"
            icon: "\u{F0450}"
            danger: true
            onClicked: {
                if (!page.svc) return
                if (page.confirmReset) {
                    page.svc.store.resetAll(Schema.defaults())
                    page.confirmReset = false
                    resetTimer.stop()
                } else {
                    page.confirmReset = true
                    resetTimer.restart()
                }
            }
        }
    }

}
