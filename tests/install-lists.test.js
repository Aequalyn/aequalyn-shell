// node tests/install-lists.test.js -- the install chooser is really two lists:
// groups on the left, the highlighted group's choices on the right, refreshed
// live as the group or the search changes. Super + I installs, Super + R removes.
const assert = require("assert");
const fs = require("fs");
const path = require("path");

let n = 0;
const ok = (c, msg) => { assert.ok(c, msg); n++; };
const root = path.join(__dirname, "..");
const here = f => path.join(root, f);
const read = f => fs.readFileSync(here(f), "utf8");
const lists = read("plugins/installMenu/InstallLists.qml");
const menu = read("plugins/installMenu/InstallMenu.qml");
const binds = read("plugins/keybinds/js/Binds.js");
const keys = read("../aequalyn/config/hypr/keybinds.lua");
const installMigration = read("../aequalyn/migrations/20261122-5.sh");
const removeMigration = read("../aequalyn/migrations/20261122-6.sh");

for (const marker of [
    "readonly property var categoryRows",
    "readonly property var optionRows",
    'import "../store/AppIcons.js" as Icons',
    "badge: Icons.initials(o.label)",
    "badgeColor: Qt.hsla(Icons.hue(o.label + \"|\" + o.id) / 360",
    "property var installed: null",
    "property bool ready: false",
    "function canInstall(o)",
    "function actionable(o)",
    "function visibleOptions()",
    "Options.isInstalled(o, lists.installed)",
    "Options.removal(o, lists.installed).length > 0",
    '? "Installed"',
    'text: lists.mode === "remove" && !lists.ready',
    "readonly property var currentOption",
    "signal chosen(var option)",
    "signal removed(var option)",
    'const key = cat ? cat.key : "all";',
    "onQueryChanged: lists.optionPick = 0",
    "onOptionRowsChanged",
    "function focusCategory()",
    "function focusOptions()",
    "property bool allowDeleteKey: false",
    'lists.categoryPick = (lists.categoryPick + d + n) % n;',
    'if (lists.mode === "remove") lists.removed(o);'
]) {
    ok(lists.indexOf(marker) >= 0, "the two-list picker has " + marker);
}
for (const marker of [
    "property var installed: Options.blankState()",
    "root.refreshInstalled();",
    '"echo \'#pacman\'"',
    '"aequalyn-ai-tool list --json',
    '"aequalyn-webapp list --json',
    "Options.stateFromText(text)",
    "Options.isInstalled(o, root.installed)",
    "Options.removal(o, root.installed)",
    "InstallLists {",
    "mode: root.mode",
    "installed: root.installed",
    "ready: root.installedReady",
    "query: panel.query",
    "onChosen: o => root.run(o)",
    "onRemoved: o => root.run(o)",
    'target: "removeMenu"',
    'root.toggle("remove")'
]) {
    ok(menu.indexOf(marker) >= 0, "the panel wires " + marker);
}
ok(keys.includes('hl.bind(M .. " + R",       hl.dsp.exec_cmd("qs ipc call removeMenu toggle"))'),
    "Super + R opens the remove chooser");
ok(binds.includes('"SUPER + R": ["Remove chooser", "apps"]'), "the key hints name Super + R");
ok(binds.includes("removeMenu: \"Remove chooser\""), "IPC names label the remove chooser");
ok(installMigration.includes("qs ipc call installMenu toggle"), "existing installs get the install key");
ok(removeMigration.includes("qs ipc call removeMenu toggle"), "existing installs get the remove key");

const load = require("./jsload.js");
const icons = load(here("plugins/store/AppIcons.js"));
const options = load(here("plugins/installMenu/InstallOptions.js"));
const badgeKeys = options.options.map(o => icons.initials(o.label) + "|" + icons.hue(o.label + "|" + o.id));
ok(badgeKeys.length === new Set(badgeKeys).size, "every install choice has its own badge");

for (const word of ["Install Aequalyn", "system-install", "omarchy", "omaudix", "baroque", "multi-docks", "qempexe"]) {
    ok(!(lists + menu).toLowerCase().includes(word.toLowerCase()), "no " + word + " wording in the picker");
}

console.log("install lists: " + n + " ok");
