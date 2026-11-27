// node tests/notification-history.test.js -- notifications are archived in a
// persistent log before they expire, and can be re-read with Super + Ctrl + N.
const assert = require("assert");
const fs = require("fs");
const path = require("path");
const load = require("./jsload.js");

let n = 0;
const ok = (c, msg) => { assert.ok(c, msg); n++; };
const root = path.join(__dirname, "..");
const read = f => fs.readFileSync(path.join(root, f), "utf8");

// -- pure model -------------------------------------------------------------
const H = load(path.join(root, "plugins/notifications/js/History.js"));
const e = H.entry({ id: 7, summary: "Build failed", body: "unit tests", appName: "kitty",
                    appIcon: "", image: "", urgency: 2 }, 3, false);
ok(e.summary === "Build failed" && e.body === "unit tests" && e.appName === "kitty", "entry snapshots the fields");
ok(e.text === "Build failed\nunit tests", "plain text to copy is title + body");
ok(/^\d+-\d+$/.test(e.id), "entry has a stable local id");
const dnd = H.entry({ summary: "Quiet", body: "during DND" }, 4, true);
ok(dnd.suppressed === true, "DND notifications are marked when archived");

const list = H.add([], e);
ok(list.length === 1 && list[0].id === e.id, "add appends a new entry");
ok(H.add(list, dnd).length === 2, "nothing is dropped automatically");
ok(H.remove(H.add(list, dnd), e.id).length === 1, "one entry can be deleted");
ok(H.find(list, e.id) === e, "entries can be found by id");
ok(H.search(H.add(list, dnd), "quiet").length === 1, "search matches title/body/app");
ok(H.search(list, "kitty").length === 1, "search matches the sending app");
const round = H.parseStore(H.serialize(H.add(list, dnd)));
ok(round.length === 2 && round[0].suppressed === true && round[0].text === "Quiet\nduring DND",
    "the JSON file round-trips without losing fields");
ok(H.parseStore("not json").length === 0, "a bad file is treated as empty");
ok(H.parseStore(JSON.stringify([{ body: "legacy array" }])).length === 1, "a bare array is accepted too");
ok(/^\d\d:\d\d$/.test(H.timeLabel(Date.now())), "times are shown as HH:MM");

// -- capture before dismissal, including DND -------------------------------
const svc = read("plugins/notifications/NotificationService.qml");
for (const marker of [
    '"js/History.js" as History',
    "notification-history.json",
    "atomicWrites: true",
    "root._record(notification, root.doNotDisturb);",
    "if (root.doNotDisturb) return;",
    "function clearHistory()",
    "function removeHistoryEntry(id)",
    "function copyHistoryEntry(id)",
    "function toggleHistory()"
]) ok(svc.includes(marker), "service archives: " + marker);
ok(svc.indexOf("root._record(notification, root.doNotDisturb);")
   < svc.indexOf("if (root.doNotDisturb) return;"),
   "archive happens before the DND early return");

// -- the reader panel and its controls --------------------------------------
const panel = read("plugins/notifications/NotificationHistory.qml");
for (const marker of [
    "PanelWindow {",
    'import "root:/settings/center"',
    "CcChoice {",
    "CcRow {",
    "CcButton { text: \"Clear all\"",
    'action: "Copy"',
    'action2: "Delete"',
    "History.search(list, root.query)"
]) ok(panel.includes(marker), "history panel uses Aequalyn controls: " + marker);

// grouped views, one monitor, and an app selector
for (const marker of [
    'property string mode: "app"',
    'root.mode === "dnd"',
    '{ key: "app", label: "By application" }',
    '{ key: "dnd", label: "While in DND" }',
    'property string appFilter: ""',
    "readonly property var appNames:",
    'visible: root.mode !== "dnd" && root.appNames.length > 0',
    'section.property: "group"',
    'readonly property string monitor: NotificationService.historyMonitor',
    'visible: root.open && modelData.name === root.monitor'
]) ok(panel.includes(marker), "grouping / monitor wiring: " + marker);

const popup = read("plugins/notifications/NotificationPopup.qml");
for (const marker of [
    "NotificationHistory {",
    "open: NotificationService.historyVisible",
    "function history(): void",
    "function history_open(): void",
    "function history_close(): void",
    "function history_clear(): void"
]) ok(popup.includes(marker), "notification IPC exposes " + marker);

// -- shortcut and command palette ------------------------------------------
const binds = read("plugins/keybinds/js/Binds.js");
ok(binds.includes('"SUPER + CTRL + N": ["Notification history", "apps"]'),
    "the key is listed in the shortcut catalogue");
const palette = read("plugins/palette/Palette.qml");
ok(palette.includes('title: "Notification history"')
   && palette.includes('"notifications", "history"'),
    "the command palette can open history");
for (const f of ["config/hypr/keybinds.lua", "../../.config/hypr/keybinds.lua"]) {
    const p = path.resolve(root, f);
    if (fs.existsSync(p))
        ok(fs.readFileSync(p, "utf8").includes('+ CTRL + N') && fs.readFileSync(p, "utf8").includes('notifications history'),
            f + " binds Super + Ctrl + N");
}
ok(read("PluginInfo.js").includes("Super + Ctrl + N: re-read saved notifications"),
    "plugin info documents the shortcut");

const quick = read("plugins/bar/QuickPanel.qml");
ok(quick.includes('glyph: "\\u{F009B}"; title: "Notifications"')
   && quick.includes("hasMore: true")
   && quick.includes("NotificationService.openHistory(name)"),
    "the quick panel's Notifications › opens the history panel");

console.log("notification-history: " + n + " checks passed");
