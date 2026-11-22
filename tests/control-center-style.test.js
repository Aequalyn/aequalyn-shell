// node tests/control-center-style.test.js -- the clipboard page uses the control
// center's own tabs, search field, plugin rows and action buttons, rather than
// pasting the plugin's whole settings panel into a fixed-height box.
const assert = require("assert");
const fs = require("fs");
const path = require("path");

let n = 0;
const ok = (c, msg) => { assert.ok(c, msg); n++; };
const root = path.join(__dirname, "..");
const read = f => fs.readFileSync(path.join(root, f), "utf8");
const page = read("settings/center/pages/Clipboard.qml");
const store = read("plugins/store/Store.qml");
const shellPage = read("settings/center/CcPage.qml");
const info = read("PluginInfo.js");
const index = read("settings/center/SettingsIndex.js");

for (const marker of [
    'plugin: "clipscape"',
    'import "root:/plugins/clipscape/qml/core"',
    "tabs: Schema.groups.map(g => g.title)",
    "ClipPanel.SettingRow {",
    "CcPluginRows {",
    "CcField {",
    'placeholder: "Search settings…"',
    'title: "Open the clipboard history"',
    "svc.store.resetAll(Schema.defaults)",
    "svc.setPaused(paused)",
    "svc.clips.clearAll()"
]) {
    ok(page.includes(marker), "the clipboard page has " + marker);
}
for (const marker of [
    "ClipPanel.SettingsView",
    "Layout.preferredHeight: 600",
    'model: ["Super", "Ctrl", "V"]'
]) {
    ok(!page.includes(marker), "the clipboard page no longer uses " + marker);
}
ok(shellPage.includes('plugin === "clipscape" && AequalynSettings.enabledPlugins.indexOf("clipboard") >= 0'),
    "the shared page header understands the old clipboard id");
ok(shellPage.includes("AequalynSettings.togglePlugin(page.plugin, v)"),
    "the shared page header still toggles the real plugin id");
ok(info.includes('clipscape:      { icon:'), "plugin metadata knows the registry id");
ok(index.includes('{"page": "clipboard", "title": "Shortcut", "kind": "group"'),
    "search still finds the shortcut group");

for (const marker of [
    "readonly property string sans: Cc.sans",
    "Cc.alpha(root.theme.textPrimary, 0.05)",
    "font.letterSpacing: 1",
    "font.pixelSize: 9",
    "font.pixelSize: 10",
    "implicitHeight: 24",
    "radius: 6",
    "Layout.preferredHeight: 64",
    "width: 40; height: 34; radius: 10",
    "component BrowseCard: Rectangle",
    "component BrowseCards: ColumnLayout",
    "component AppTile: Rectangle",
    "component SourceCards: ColumnLayout",
    "readonly property bool hovered: tileMa.containsMouse",
    "readonly property color monogramColor",
    "color: tile.monogramColor",
    "component AiCard: Rectangle",
    "readonly property bool hovered: aiMa.containsMouse",
    "spacing: 4"
]) {
    ok(store.includes(marker), "the Store uses the control center's " + marker);
}

for (const word of ["omarchy", "omaudix", "baroque", "multi-docks", "qempexe"]) {
    ok(!page.toLowerCase().includes(word), "no " + word + " wording on the clipboard page");
}

console.log("control center style: " + n + " ok");
