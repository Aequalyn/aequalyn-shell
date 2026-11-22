// node tests/store-install.test.js -- the Store uses Super + I's categories in
// its Apps list, and keeps its own pages free of the curated install chooser.
const assert = require("assert");
const fs = require("fs");
const path = require("path");

let n = 0;
const ok = (c, msg) => { assert.ok(c, msg); n++; };
const root = path.join(__dirname, "..");
const store = fs.readFileSync(path.join(root, "plugins/store/Store.qml"), "utf8");
const menu = fs.readFileSync(path.join(root, "plugins/installMenu/InstallMenu.qml"), "utf8");

for (const marker of [
    'import "root:/plugins/installMenu/InstallOptions.js" as InstallOptions',
    'import "root:/plugins/store/AppIcons.js" as AppIcons',
    'import "root:/plugins/store/PackageIds.js" as PackageIds',
    'import "root:/plugins/store/AppMeta.js" as AppMeta',
    'readonly property var appCategories: InstallOptions.categories',
    '.filter(c => c.key !== "all" && c.key !== "ai")',
    'property string appCategory: "all"',
    'readonly property int categoryAppLimit: 30',
    'readonly property var currentAppCategory',
    'model: root.currentAppCategory ? [root.currentAppCategory] : []',
    'function categoryForResult(r)',
    'function appsInCategory(key)',
    'const curated = InstallOptions.options',
    '.filter(o => o.category === key && root.packageOption(o))',
    'return key === "all" ? pool.length : root.appsInCategory(key).length;',
    'function iconForOption(o)',
    'return AppIcons.slugForOption(o);',
    'function appIconUrl(icon, name)',
    'return AppIcons.url(icon, name);',
    'function localAppIcon(path, name)',
    'readonly property string iconUrl: root.localAppIcon(card.iconPath, card.label)',
    'readonly property string iconUrl: root.localAppIcon(wrow.modelData.iconFile, wrow.label)',
    'readonly property string appIcon: row.kind === "appimage" ? root.localAppIcon(modelData.icon, row.label) : ""',
    'function appInitials(name)',
    'function appMonogramColor(name)',
    'AppMeta.aboutFor(o.id) || o.words || ""',
    'AppMeta.iconFor(o.id) || root.iconForOption(o)',
    'root.appIconUrl(modelData.icon, modelData.name || modelData.id)',
    'function appCardShape(r)',
    'icon: root.appIconUrl(r.icon, r.name || r.id),',
    'pacman: r.pacman || "", aur: r.aur || "",',
    'flatpak: r.flatpak || "", snap: r.snap || ""',
    'const ids = PackageIds.forOption(o);',
    'flatpak: ids.flatpak || "", snap: ids.snap || ""',
    'function categoryAppCards(key)',
    'component AppTile: Rectangle',
    'onClicked: root.installFound({',
    'component SourceCards: ColumnLayout',
    'property int limit: 0',
    'return out.slice(0, root.categoryAppLimit);',
    'onOpened: {',
    'model: root.categoryAppCards(modelData.key)',
    'limit: root.categoryAppLimit',
    'function appInfoName(g)',
    '["aequalyn-store", "app-info", root.appInfoName(g)]',
    'function aiAppResults()',
    'function aiMeta(tool)',
    'function aiIconUrl(tool)',
    'function openAiApp(tool)',
    'onOpened: root.openAiApp(modelData)',
    'id: aiIcon',
    'component BrowseCard: Rectangle',
    'component BrowseCards: ColumnLayout',
    'title: "AI apps"',
    'model: root.aiAppResults()',
    'visible: root.section === "apps" && root.appCategory === "all"',
    '{ key: "apps",      label: "All Apps"',
    '{ key: "apps",   title: "Apps"',
    '{ key: "web",       label: "Web apps"',
    '{ key: "ai",        label: "AI tools"',
    '{ key: "appimage",  label: "AppImages"',
    '"appcat:" + c.key',
    'readonly property var sectionNavItems',
    'function navIsOn(item)',
    'function openNav(item)',
    'title: "All Apps"',
    'if (source === "Apps") return "All Apps";',
    'function package(source: string, name: string): string',
    'function remove(source: string, name: string): string',
    'const via = ({ arch: "Arch", aur: "AUR", flatpak: "Flatpak", snap: "Snap" })',
    'readonly property string sans: Cc.sans',
    'color: Cc.alpha(root.theme.textPrimary, 0.03)'
]) {
    ok(store.includes(marker), "Store wires " + marker);
}
for (const marker of [
    'import "root:/plugins/installMenu" as InstallUi',
    'InstallUi.InstallLists',
    '{ key: "install",',
    'property var installLists',
    'Other install actions',
    'installMatches(',
    'root.installLists.key(event)',
    '? root.appCategories.filter(c => c.key !== "all") : []',
    '.concat([{ key: "other"',
    'text: "\\u{F03D6}"',
    'BrowseCards {\n                                            model: root.appsInCategory(modelData.key)',
    'text: card.isWeb ? "\\u{F0595}" : "\\u{F01D4}"',
    'text: "\\u{F0595}"'
]) {
    ok(!store.includes(marker), "Store no longer shows " + marker);
}
ok(store.includes('sections: ["plugin", "theme", "cursor", "wallpaper", "look"]'),
    "Get keeps its git pages but no install chooser");
ok(store.includes('.concat(root.appCategories.map(c => "appcat:" + c.key)).concat(["appimage"])'),
    "Apps rail includes the Super + I categories");
for (const marker of ["Install Aequalyn", "system-install"]) {
    ok(!menu.includes(marker), "Super + I no longer offers " + marker);
}

const cli = fs.readFileSync(path.join(root, "../aequalyn/bin/aequalyn-store"), "utf8");
ok(cli.includes("^[A-Za-z0-9._+][A-Za-z0-9 ._+ '()-]{0,79}$"),
    "app-info accepts curated display names such as .NET");
for (const marker of [
    "def _hit_id(hits, name_keys, id_keys, source)",
    "def _resolve_ids(name, ids)",
    '"Flatpak": lambda q: search_flathub(q, 1)[0]',
    "_resolve_ids(name, ids)",
    "with no id are resolved by name first",
    "def _agrees(primary, other)",
    "s.get(\"id\") in given",
    "not primary or _agrees(primary, s)"
]) {
    ok(cli.includes(marker), "app-info resolves every package manager: " + marker);
}

const text = store + menu;
for (const word of ["omarchy", "omaudix", "baroque", "multi-docks", "qempexe"]) {
    ok(!text.toLowerCase().includes(word), "no " + word + " wording in the chooser or Store");
}

const load = require("./jsload.js");
const icons = load(path.join(root, "plugins/store/AppIcons.js"));
const menuOptions = load(path.join(root, "plugins/installMenu/InstallOptions.js"));
ok(icons.names.length > 4000, "the icon snapshot is complete");
const appChoices = menuOptions.options.filter(o => o.cmd && o.cmd[0] === "qs" && o.cmd[4] === "package");
const meta = load(path.join(root, "plugins/store/AppMeta.js"));
ok(Object.keys(meta.about).length === appChoices.length,
    "every curated app has a real description");
ok(Object.keys(meta.icon).length > 140, "most curated apps have a publisher icon");
for (const o of appChoices) {
    const about = meta.aboutFor(o.id);
    ok(about.length > 3 && about !== o.label, o.label + " has a proper description: " + about);
    const remote = meta.iconFor(o.id);
    ok(remote === "" || /^https?:\/\//.test(remote), o.label + " has a usable icon url");
}
ok(Object.keys(meta.ai).length >= 10, "every coding agent has app metadata");
for (const [id, row] of Object.entries(meta.ai)) {
    ok((row.about || "").length > 3, id + " has an agent description");
    for (const key of ["arch", "aur", "flatpak", "snap"])
        ok(!row[key] || /^[A-Za-z0-9@._+-]{1,128}$/.test(row[key]), id + " has a plain " + key + " id");
}
const badges = new Set();
for (const o of appChoices) {
    const slug = icons.slugForOption(o);
    const url = icons.url(slug, o.label);
    ok(url.indexOf("https://") === 0 || url.indexOf("data:image/svg+xml,") === 0,
        o.label + " has a usable icon");
    ok(!url.includes("/" + slug + ".png") || icons.has(slug),
        o.label + " never asks the CDN for a missing icon");
    if (url.indexOf("data:") === 0) badges.add(url);
}
ok(badges.size > 150, "apps without a publisher icon still get their own badge");
ok(badges.size === appChoices.filter(o => !icons.has(icons.slugForOption(o))).length,
    "every generated badge is distinct");
for (const word of ["omarchy", "omaudix", "baroque", "multi-docks", "qempexe"]) {
    ok(!icons.names.join(" ").toLowerCase().includes(word), "no " + word + " icon name");
}

console.log("store install: " + n + " ok");
