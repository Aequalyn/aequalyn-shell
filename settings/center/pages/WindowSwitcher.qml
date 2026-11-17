// Window switcher: Altscape (plugins/altscape), Alt + Tab. Layouts: the twelve ways to
// see your windows, with a live preview of yours; then a tab per group of its settings
// (which windows, previews, look, motion, backdrop). The rows are Altscape's own
// (plugins/altscape/panel), in its colours, which follow the theme unless changed on
// Look; every change goes through its service, which applies and saves it at once.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/settings"
import "root:/plugins/altscape"
import "root:/plugins/altscape/panel"
import "root:/plugins/altscape/controls"
import "root:/plugins/altscape/core"
import "root:/plugins/altscape/js/Schema.js" as Schema
import ".."

CcPage {
    id: page
    title: "Window switcher"
    plugin: "altscape"
    sub: {
        if (!page.svc) return "Alt + Tab: every window in one of twelve layouts, with live previews.";
        const n = page.svc.windowCount;
        let s = n + (n === 1 ? " window open" : " windows open");
        const b = page.svc.bindStatus;
        const want = page.svc.cfg.shortcut;
        if (want === "off") s += ". No shortcut: Aequalyn's own Alt + Tab is on.";
        else if (b && b.ok && b.shortcut === want && b.active === "false") s += ". The shortcut is written, but Hyprland is not using it.";
        else if (b && b.ok && b.shortcut === want) s += ". " + (want === "super" ? "Super" : "Alt") + " + Tab opens the switcher, Shift goes back.";
        else if (b && b.error) s += ". The shortcut could not be set: " + b.error;
        return s;
    }

    readonly property var svc: AltscapeHost.svc
    // the rows and the layout tiles in the control center's colours, font and spacing
    // (the switcher itself keeps its own look, set on Look)
    readonly property var ui: svc ? pageUi : null
    UiState {
        id: pageUi
        cfg: page.svc ? Object.assign({}, page.svc.cfg, {
            colorMode: "theme", density: "comfortable", fontScale: 115, surfaceTint: 0,
            frame: false, opacity: 100, cornerRadius: 10 }) : null
        barFg: Cc.theme.textPrimary
        barBg: Cc.theme.bgBase
        themeAccent: Cc.theme.accentPrimary
        themeUrgent: Cc.theme.accentRed
        fontName: Cc.sans
        borderColors: page.svc ? page.svc.borderColors : []
        borderAngle: page.svc ? page.svc.borderAngle : 0
    }

    // its settings groups, without the one for its own popup
    readonly property var groups: Schema.groups.filter(g => g.title !== "Panel")
    tabs: ["Layouts"].concat(groups.map(g => g.title))
    fills: [0]
    readonly property var group: page.tab > 0 ? page.groups[page.tab - 1] : null

    actions: [
        CcButton {
            visible: !!page.svc
            text: "Open switcher"; icon: "\u{F05B1}"; primary: true
            onClicked: page.svc.openSwitcher("open")
        }
    ]

    CcNote {
        visible: !page.svc
        text: "The window switcher shows every window when you press Alt + Tab. Turn it on above, and it starts at once."
    }

    // ---- Layouts: pick one, and see your windows in it ---------------------------------
    VisualisersView {
        visible: !!page.svc && page.tab === 0
        Layout.fillWidth: true
        Layout.fillHeight: true
        svc: page.svc
        look: page.ui
        shown: page.visible && page.tab === 0
    }

    // ---- a group of settings -------------------------------------------------------------
    function val(key) {
        return page.svc && page.svc.cfg && page.svc.cfg[key] !== undefined ? page.svc.cfg[key] : Schema.defaults[key];
    }
    // a row's value: one setting, or for a palette row its colours as { key: value }
    function rowValue(item) {
        if (item.kind !== "palette") return val(item.key);
        const o = {};
        for (let i = 0; i < item.targets.length; i++) o[item.targets[i].key] = val(item.targets[i].key);
        return o;
    }
    function edit(item, v) {
        if (!page.svc) return;
        if (item.kind !== "palette") { page.svc.setValue(item.key, v); return; }
        if (v && v.reset) {
            for (let i = 0; i < item.targets.length; i++)
                page.svc.setValue(item.targets[i].key, item.fallback[item.targets[i].key]);
        } else if (v && v.key) {
            page.svc.setValue(v.key, v.value);
        }
    }
    function dimmed(item) {
        if (!item.when) return false;
        for (let i = 0; i < item.when.length; i++) {
            const c = item.when[i];
            if (c.is.map(String).indexOf(String(val(c.key))) < 0) return true;
        }
        return false;
    }
    // the shortcut row also says when the keybind couldn't be written
    function hintOf(item) {
        if (item.key === "shortcut" && page.svc && page.svc.bindStatus.error) return item.hint + "\n⚠ " + page.svc.bindStatus.error;
        return item.hint || "";
    }
    // the group's rows, with a heading where a new section starts
    readonly property var rows: {
        const out = [];
        if (!page.group) return out;
        let last = "";
        for (const it of page.group.items) {
            const section = it.section || "";
            out.push({ item: it, head: section !== last ? section : "" });
            last = section;
        }
        return out;
    }

    // Altscape's rows are drawn for a small panel: shown at the size every plugin's
    // settings have here (CcPluginRows)
    CcPluginRows {
        id: rows
        visible: !!page.svc && page.tab > 0
        Repeater {
            model: page.tab > 0 && page.ui ? page.rows : []
            delegate: ColumnLayout {
                id: entry
                required property var modelData
                required property int index
                Layout.fillWidth: true
                spacing: 0
                Txt {
                    ui: page.ui
                    visible: entry.modelData.head !== ""
                    Layout.fillWidth: true
                    Layout.topMargin: entry.index > 0 ? 18 : 4
                    text: entry.modelData.head
                    opacity: 0.55
                    font.pixelSize: page.ui.fs(10)
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.2
                    font.capitalization: Font.AllUppercase
                }
                Rectangle {
                    visible: entry.index > 0 && entry.modelData.head === ""
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: page.ui.tint(0.07)
                }
                SettingRow {
                    Layout.fillWidth: true
                    Layout.topMargin: 14
                    Layout.bottomMargin: 14
                    ui: page.ui
                    settingKey: entry.modelData.item.key
                    label: entry.modelData.item.label
                    hint: page.hintOf(entry.modelData.item)
                    kind: entry.modelData.item.kind
                    control: entry.modelData.item.control || ""
                    options: entry.modelData.item.options || []
                    labels: entry.modelData.item.labels || ({})
                    presets: entry.modelData.item.presets || []
                    maxLength: entry.modelData.item.maxLength !== undefined ? entry.modelData.item.maxLength : 2048
                    min: entry.modelData.item.min !== undefined ? entry.modelData.item.min : 0
                    max: entry.modelData.item.max !== undefined ? entry.modelData.item.max : 100
                    step: entry.modelData.item.step !== undefined ? entry.modelData.item.step : 1
                    divisor: entry.modelData.item.divisor !== undefined ? entry.modelData.item.divisor : 1
                    decimals: entry.modelData.item.decimals !== undefined ? entry.modelData.item.decimals : 0
                    defaultValue: entry.modelData.item.fallback
                    dimmed: page.dimmed(entry.modelData.item)
                    value: page.rowValue(entry.modelData.item)
                    targets: entry.modelData.item.targets || []
                    onEdited: function(v) { page.edit(entry.modelData.item, v) }
                }
            }
        }
        }

    CcMore {
        visible: !!page.svc && page.tab > 0
        title: "Start over"
        CcNote { text: "Every switcher setting back to how it came. The layout you picked stays." }
        CcButton {
            text: "Reset the switcher"; icon: "\u{F0450}"; danger: true
            onClicked: {
                const keep = page.svc.cfg.mode;
                page.svc.store.resetAll(Schema.defaults);
                page.svc.setValue("mode", keep);
            }
        }
    }
}
