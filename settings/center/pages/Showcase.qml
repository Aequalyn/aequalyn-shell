// Showcase settings in the control center. The plugin's own service owns every
// value; these rows follow the control center's look and put every change through
// the running service's setValue().
import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/settings"
import "root:/plugins/kit"
import "root:/plugins/showcase/qml/core"
import "root:/plugins/showcase/qml/js/Schema.js" as Schema
import "root:/plugins/showcase/qml/panel" as ShowPanel
import ".."

CcPage {
    id: page
    title: "Showcase"
    plugin: "showcase"
    sub: "Widgets behind your windows: clocks, dates, readings, music and notes, with looks and cards."

    readonly property var svc: KitHost.get("showcase")
    readonly property var cfg: page.svc ? page.svc.cfg : Schema.defaults
    readonly property var ui: pageUi

    UiState {
        id: pageUi
        cfg: page.svc ? Object.assign({}, page.svc.cfg, {
            colorMode: "theme", textColor: "theme", density: "comfortable",
            fontScale: 115, surfaceTint: 0, cornerRadius: 8,
            frame: false, opacity: 100, cardStyle: "soft",
            panelFrame: false, panelFrameGradient: false, panelOpacity: 100,
            speed: 180
        }) : null
        barFg: Cc.theme.textPrimary
        barBg: Cc.theme.bgBase
        themeAccent: Cc.theme.accentPrimary
        themeUrgent: Cc.theme.accentRed
        fontName: Cc.sans
        borderColors: page.svc ? page.svc.borderColors : []
        borderAngle: page.svc ? page.svc.borderAngle : 0
    }

    tabs: Schema.groups.map(g => g.title)
    readonly property var group: page.tab < Schema.groups.length ? Schema.groups[page.tab] : null
    property string filter: ""
    readonly property bool searching: page.filter.trim() !== ""

    actions: RowLayout {
        CcButton {
            visible: !!page.svc
            text: "Arrange"; icon: "\u{F0E6B}"; primary: true
            onClicked: page.svc.arrange(true)
        }
        CcButton {
            visible: !!page.svc
            text: "Next look"; icon: "\u{F0E6B}"
            onClicked: page.svc.nextLook()
        }
    }

    function val(key) {
        return page.svc && page.svc.cfg && page.svc.cfg[key] !== undefined
            ? page.svc.cfg[key] : Schema.defaults[key];
    }
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

    readonly property var noRow: ({ item: { key: "", label: "", kind: "" }, head: "" })

    CcNote {
        visible: !page.svc
        text: "Showcase is off. Turn it on above, and your desktop widgets come back."
    }

    CcField {
        id: searchField
        visible: !!page.svc
        text: page.filter
        placeholder: "Search settings…"
        inputWidth: 360
        Layout.maximumWidth: 360
        onTextChanged: page.filter = text
    }

    CcSection {
        visible: !!page.svc && page.rows.length > 0
        title: page.searching ? "Matches" : (page.group ? page.group.title : "")
        CcPluginRows {
            Repeater {
                // by index: through the model, arrays inside a row stop being arrays
                model: page.rows.length
                delegate: ColumnLayout {
                    required property int index
                    readonly property var row: index < page.rows.length ? page.rows[index] : page.noRow
                    Layout.fillWidth: true
                    spacing: 0
                    Text {
                        visible: row.head !== ""
                        Layout.fillWidth: true
                        Layout.topMargin: index > 0 ? 18 : 4
                        Layout.bottomMargin: 4
                        text: row.head.toUpperCase()
                        color: Cc.theme.textSecondary
                        font.family: Cc.sans
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1
                        opacity: 0.45
                    }
                    // the ready made looks, the widgets and the saved looks have editors
                    // of their own; each is made only for its row
                    Loader {
                        active: !!page.svc && ["presets", "widgets", "looks"].indexOf(row.item.kind) >= 0
                        visible: active
                        Layout.fillWidth: true
                        Layout.topMargin: active ? 8 : 0
                        Layout.bottomMargin: active ? 8 : 0
                        sourceComponent: row.item.kind === "presets" ? presetGrid
                            : row.item.kind === "widgets" ? widgetsEditor : lookSlots
                        Component { id: presetGrid; ShowPanel.PresetGrid { svc: page.svc; label: row.item.label; hint: row.item.hint || "" } }
                        Component { id: widgetsEditor; ShowPanel.WidgetsEditor { svc: page.svc } }
                        Component { id: lookSlots; ShowPanel.LookSlots { svc: page.svc; label: row.item.label; hint: row.item.hint || "" } }
                    }
                    ShowPanel.SettingRow {
                        visible: ["presets", "widgets", "looks"].indexOf(row.item.kind) < 0
                        Layout.fillWidth: true
                        Layout.topMargin: 8
                        Layout.bottomMargin: 8
                        ui: page.ui
                        svc: page.svc
                        settingKey: row.item.key
                        label: row.item.label
                        hint: row.item.hint || ""
                        kind: row.item.kind
                        control: row.item.control || ""
                        options: row.item.options || []
                        labels: row.item.labels || ({})
                        presets: row.item.presets || []
                        maxLength: row.item.maxLength !== undefined ? row.item.maxLength : 2048
                        min: row.item.min !== undefined ? row.item.min : 0
                        max: row.item.max !== undefined ? row.item.max : 100
                        step: row.item.step !== undefined ? row.item.step : 1
                        divisor: row.item.divisor !== undefined ? row.item.divisor : 1
                        decimals: row.item.decimals !== undefined ? row.item.decimals : 0
                        defaultValue: row.item.fallback
                        targets: row.item.targets || []
                        dimmed: page.dimmed(row.item)
                        value: page.rowValue(row.item)
                        onEdited: v => page.edit(row.item, v)
                    }
                }
            }
        }
    }
}
