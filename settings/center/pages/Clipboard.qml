// Clipboard: Clipscape's settings, in the same tabs and rows as the rest of the
// control center. The rows are the plugin's own, with the page's colours and font,
// and every change still goes through Clipscape's service.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/settings"
import "root:/plugins/clipscape"
import "root:/plugins/clipscape/qml/core"
import "root:/plugins/clipscape/qml/js/Schema.js" as Schema
import "root:/plugins/clipscape/qml/panel" as ClipPanel
import ".."

CcPage {
    id: page
    title: "Clipboard"
    plugin: "clipscape"
    sub: "Everything you copied, text and images: what is kept, how it pastes, and how the picker looks."

    readonly property var svc: ClipscapeService
    readonly property var cfg: page.svc ? page.svc.cfg : Schema.defaults
    readonly property var ui: pageUi
    // the plugin's picker can use its own colours; these rows follow the control center
    UiState {
        id: pageUi
        cfg: page.svc ? Object.assign({}, page.svc.cfg, {
            colorMode: "theme", textColor: "theme", density: "comfortable",
            fontScale: 115, surfaceTint: 0, cornerRadius: 8,
            frame: false, opacity: 100, cardStyle: "soft" }) : null
        barFg: Cc.theme.textPrimary
        barBg: Cc.theme.bgBase
        themeAccent: Cc.theme.accentPrimary
        fontName: Cc.sans
        borderColors: page.svc ? page.svc.borderColors : []
        borderAngle: page.svc ? page.svc.borderAngle : 0
    }

    tabs: Schema.groups.map(g => g.title)
    readonly property var group: page.tab < Schema.groups.length ? Schema.groups[page.tab] : null
    property string filter: ""
    readonly property bool searching: page.filter.trim() !== ""
    property bool confirmReset: false
    property bool confirmClear: false
    Timer { id: resetTimer; interval: 2500; onTriggered: page.confirmReset = false }
    Timer { id: clearTimer; interval: 4000; onTriggered: page.confirmClear = false }

    actions: CcButton {
        visible: !!page.svc
        text: "Open picker"; icon: "\u{F05B1}"; primary: true
        onClicked: page.svc.openPicker("")
    }

    function val(key) {
        return page.svc && page.svc.cfg && page.svc.cfg[key] !== undefined
            ? page.svc.cfg[key] : Schema.defaults[key];
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
    // the page is never popped out, so the window-size rows stay editable here
    function offHere(item) { return false; }
    function dimmed(item) {
        if (!item.when) return false;
        for (let i = 0; i < item.when.length; i++) {
            const c = item.when[i];
            if (c.is.map(String).indexOf(String(val(c.key))) < 0) return true;
        }
        return false;
    }
    function matches(item) {
        const f = page.filter.trim().toLowerCase();
        if (f === "") return true;
        return (item.label + " " + (item.hint || "") + " " + (item.section || ""))
            .toLowerCase().indexOf(f) >= 0;
    }

    // the selected group, or every match while searching; `head` is the heading
    // over a row, so a search still says which group each match came from
    readonly property var rows: {
        const out = [];
        for (let g = 0; g < Schema.groups.length; g++) {
            const group = Schema.groups[g];
            if (!page.searching && g !== page.tab) continue;
            let last = "";
            for (const item of group.items) {
                if (!page.matches(item)) continue;
                const section = page.searching ? group.title : (item.section || "");
                out.push({ item: item, head: section !== last ? section : "" });
                last = section;
            }
        }
        return out;
    }

    CcNote {
        visible: !page.svc
        text: "The clipboard history is off. Turn it on above, and copied text and images start collecting at once."
    }

    CcField {
        id: searchField
        visible: !!page.svc
        text: page.filter
        placeholder: "Search settings…"
        inputWidth: 360
        Layout.maximumWidth: 360
        onTextChanged: page.filter = text
        Keys.onEscapePressed: event => {
            if (text !== "") { text = ""; event.accepted = true }
        }
    }

    CcSection {
        visible: !!page.svc && page.rows.length > 0
        title: page.searching ? "Matches" : (page.group ? page.group.title : "")
        CcPluginRows {
            Repeater {
                model: page.rows
                delegate: ColumnLayout {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    spacing: 0
                    Text {
                        visible: modelData.head !== ""
                        Layout.fillWidth: true
                        Layout.topMargin: index > 0 ? 18 : 4
                        Layout.bottomMargin: 4
                        text: modelData.head.toUpperCase()
                        color: Cc.theme.textSecondary
                        font.family: Cc.sans
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1
                        opacity: 0.45
                    }
                    ClipPanel.SettingRow {
                        Layout.fillWidth: true
                        Layout.topMargin: 8
                        Layout.bottomMargin: 8
                        ui: page.ui
                        settingKey: modelData.item.key
                        label: modelData.item.label
                        hint: page.offHere(modelData.item)
                            ? "Not used here: your window manager sizes the panel."
                            : (modelData.item.hint || "")
                        kind: modelData.item.kind
                        control: modelData.item.control || ""
                        options: modelData.item.options || []
                        labels: modelData.item.labels || ({})
                        presets: modelData.item.presets || []
                        maxLength: modelData.item.maxLength !== undefined ? modelData.item.maxLength : 2048
                        min: modelData.item.min !== undefined ? modelData.item.min : 0
                        max: modelData.item.max !== undefined ? modelData.item.max : 100
                        step: modelData.item.step !== undefined ? modelData.item.step : 1
                        divisor: modelData.item.divisor !== undefined ? modelData.item.divisor : 1
                        decimals: modelData.item.decimals !== undefined ? modelData.item.decimals : 0
                        defaultValue: modelData.item.fallback
                        targets: modelData.item.targets || []
                        dimmed: page.dimmed(modelData.item)
                        locked: page.offHere(modelData.item)
                        value: page.rowValue(modelData.item)
                        onEdited: v => page.edit(modelData.item, v)
                    }
                }
            }
        }
    }

    CcSection {
        title: "Shortcut"
        hint: "The key that opens the clipboard history."
        CcRow {
            icon: "\u{F030C}"
            title: "Open the clipboard history"
            sub: "Super + Ctrl + V"
        }
    }

    CcMore {
        visible: !!page.svc
        title: "Start over"
        CcNote { text: "Every clipboard setting back to how it came. Your saved clips stay." }
        CcButton {
            text: page.confirmReset ? "Really reset?" : "Reset settings"
            icon: "\u{F0450}"; danger: true
            onClicked: {
                if (!page.svc) return;
                if (!page.confirmReset) { page.confirmReset = true; resetTimer.restart(); return; }
                const paused = page.svc.paused;
                page.svc.store.resetAll(Schema.defaults);
                page.svc.setPaused(paused);
                page.confirmReset = false;
            }
        }
        CcButton {
            text: page.confirmClear ? "Really clear?" : "Clear history"
            icon: "\u{F0450}"; danger: true
            onClicked: {
                if (!page.confirmClear) { page.confirmClear = true; clearTimer.restart(); return; }
                if (page.svc && page.svc.clips) page.svc.clips.clearAll();
                page.confirmClear = false;
            }
        }
    }
}
