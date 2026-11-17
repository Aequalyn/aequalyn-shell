// Cursor: Plume (plugins/plume). The cursor you design (arrow, surface, fill, lines,
// ornaments, shadow, and every other cursor drawn to match), the trail and the halo that
// follow the pointer, their colours, shake to find, hiding, and looks to wear in a click.
// The tabs, rows and pictures are Plume's own (plugins/plume/panel), drawn in the
// control center's colours; every change goes through Plume's service, which applies
// and saves it at once.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/settings"
import "root:/plugins/plume"
import "root:/plugins/plume/panel"
import "root:/plugins/plume/core"
import "root:/plugins/plume/js/Schema.js" as Schema
import ".."

CcPage {
    id: page
    title: "Cursor"
    plugin: "plume"
    sub: "Design your own cursor, and give the pointer trails and halos that follow it."

    readonly property var svc: PlumeHost.svc
    readonly property var cfg: svc ? svc.cfg : Schema.resolve({}, null)

    // Plume's tabs, without its About and the colours of its own popup (this page has
    // the control center's)
    readonly property var ptabs: Schema.tabs.filter(t => t.kind !== "about").map(t => Object.assign({}, t, {
        groups: t.groups.filter(g => !g.items.some(it => String(it.key).indexOf("panel") === 0))
    }))
    tabs: ptabs.map(t => t.title)
    readonly property var cur: ptabs[Math.max(0, Math.min(page.tab, ptabs.length - 1))]

    // the effects as the settings draw them, and your own cursor when it is worn
    stageHeight: 150
    stage: Rectangle {
        anchors.fill: parent
        radius: 14
        color: Cc.theme.bgSurface
        clip: true
        FxArt {
            anchors.fill: parent
            anchors.margins: 4
            visible: !!page.svc
            values: page.cfg
            colors: page.svc ? page.svc.colorCtx : ({})
            scale: 0.8
            live: page.visible && !!page.svc
            cursorSvg: page.svc && page.svc.ownCursor ? page.svc.cursorArrow : ""
            cursorHot: page.svc ? page.svc.cursorHot : [0.2, 0.15]
        }
        Text {
            anchors.centerIn: parent
            visible: !page.svc
            text: "Plume is turned off"
            color: Cc.theme.textMuted
            font.family: Cc.sans
            font.pixelSize: 13
        }
    }

    actions: [
        CcButton {
            visible: !!page.svc
            text: page.cfg.enabled ? "Effects on" : "Effects off"
            icon: "\u{F01C0}"
            primary: page.cfg.enabled === true
            onClicked: page.svc.setSetting("enabled", !page.cfg.enabled)
        },
        CcButton {
            visible: !!page.svc
            text: "Find the pointer"; icon: "\u{F0349}"
            onClicked: page.svc.find()
        }
    ]

    CcNote {
        visible: !page.svc
        text: "Plume draws your cursor and the trails and halos around it. Turn it on above, and it starts at once."
    }

    // ---- colours: the control center's ----------------------------------------------------
    function luma(c) { return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b }
    readonly property color ink: Cc.theme.textPrimary
    readonly property color accent: Cc.theme.accentPrimary
    readonly property color inkOnFg: luma(accent) > 0.55 ? Qt.rgba(0.07, 0.07, 0.09, 1) : Qt.rgba(0.97, 0.97, 0.98, 1)
    function tint(a) { return Qt.rgba(ink.r, ink.g, ink.b, a) }

    // the rows of this tab: its groups' headings and settings, in one list
    readonly property var rows: {
        const out = [];
        for (const g of (page.cur.groups || [])) {
            out.push({ header: g.title });
            for (const it of g.items) out.push({ item: it });
        }
        return out;
    }

    // ---- pasting into a text field (a hex colour): at most 1 KB of the clipboard -------------
    property var pasteRow: null
    property var pasteTarget: null
    function requestPaste(row, target) {
        if (pasteRun.running) return;
        pasteRow = row; pasteTarget = target;
        pasteRun.start(["wl-paste", "--no-newline"]);
    }
    Run {
        id: pasteRun
        seconds: 2
        maxOut: 1024
        onDone: function(code, out, err) {
            const row = page.pasteRow, target = page.pasteTarget;
            page.pasteRow = null; page.pasteTarget = null;
            if (row && target) { try { row.insertPasted(target, code === 0 ? out : "") } catch (e) { } }
        }
    }

    // ---- the tab -------------------------------------------------------------------------
    // Plume's pieces are drawn for a small panel: shown at the size every plugin's
    // settings have here (CcPluginRows)
    CcPluginRows {
        id: rows
        visible: !!page.svc

            LooksPage {
                visible: page.cur.kind === "looks"
                Layout.fillWidth: true
                Layout.preferredWidth: rows.rowWidth
                Layout.maximumWidth: rows.rowWidth
                svc: page.svc
                cfg: page.cfg
                ink: page.ink
                accent: page.accent
                inkOnFg: page.inkOnFg
                fontFamily: Cc.sans
                colors: page.svc ? page.svc.colorCtx : ({})
            }

            CursorShowcase {
                visible: page.cur.key === "cursor"
                Layout.fillWidth: true
                Layout.bottomMargin: 2
                design: page.svc ? page.svc.cursorDesign : null
                worn: page.svc ? page.svc.ownCursor : false
                ink: page.ink
                accent: page.accent
                fontFamily: Cc.sans
            }

            Repeater {
                model: page.cur.kind === "looks" ? [] : page.rows

                delegate: ColumnLayout {
                    id: entry
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        visible: !!entry.modelData.header
                        Layout.fillWidth: true
                        Layout.topMargin: entry.index > 0 ? 16 : 4
                        Layout.bottomMargin: 2
                        text: entry.modelData.header || ""
                        textFormat: Text.PlainText
                        color: page.ink
                        opacity: 0.55
                        font.family: Cc.sans
                        font.pixelSize: 8
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.2
                        font.capitalization: Font.AllUppercase
                    }
                    Rectangle {
                        visible: !!entry.modelData.item && entry.index > 0 && !page.rows[entry.index - 1].header
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: page.tint(0.07)
                    }

                    SettingRow {
                        id: settingRow
                        readonly property var it: entry.modelData.item || ({ key: "", label: "", kind: "", fallback: null })
                        visible: !!entry.modelData.item
                        Layout.fillWidth: true
                        Layout.topMargin: 12
                        Layout.bottomMargin: 12

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
                        dimmed: entry.modelData.item ? !Schema.active(it, page.cfg) : false
                        value: page.cfg[it.key]

                        fg: page.ink
                        accent: page.accent
                        bg: page.inkOnFg
                        panel: Cc.theme.bgBase
                        barFg: page.ink
                        fontFamily: Cc.sans
                        schemeMap: ({})
                        schemeMono: page.ink

                        settingKey: it.key
                        allValues: (it.kind === "trail" || it.kind === "halo" || it.kind === "colors"
                                    || it.kind === "glyph" || it.kind === "paint") ? page.cfg : ({})
                        glyph: it.glyph || ""
                        customKey: it.custom || ""
                        cursorNote: it.kind === "cursor" && page.svc ? page.svc.cursorStatus : ""
                        fxColors: page.svc ? page.svc.colorCtx : ({})
                        cursorThemes: it.kind === "cursor" && page.svc ? page.svc.cursorThemes : []
                        onEdited: function(v) { if (page.svc) page.svc.setSetting(settingRow.it.key, v) }
                        onClipboardPaste: function(target, maxBytes) { page.requestPaste(settingRow, target) }
                    }
                }
            }
            }

    CcMore {
        visible: !!page.svc
        title: "Start over"
        CcNote { text: "Every Plume setting back to how it came. Your saved looks stay." }
        CcButton {
            text: "Reset Plume"; icon: "\u{F0450}"; danger: true
            onClicked: page.svc.store.resetAll(Schema.defaults())
        }
    }
}
