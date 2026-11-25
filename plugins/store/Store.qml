// The Store: plugins, themes, cursors, wallpaper packs and looks from git, every one
// checked before it is kept (bin/aequalyn-store does the work; this is its window);
// the app browser, grouped with the same categories Super + I uses; web apps and
// AI tools
// (aequalyn-webapp and aequalyn-ai-tool do the work, the same live report shows it);
// and the way AppImages come in: checked without anything inside them ever running,
// moved to ~/Applications with a menu entry of their own. Super + Alt + S, or
// `qs ipc call store open` (`section <name>` opens it on a section,
// `install <kind> <git-url>` installs, `package`/`remove` act on one plain id,
// `appimage <path>` brings one over).
//
// Dressed as the control center: the same palette (the live one the shell binds into
// every plugin), the same two fonts (words in a plain sans, numbers, paths and icons
// in the shell's mono), the same rail, footer and rise between sections. Every action
// runs aequalyn-store, and its report shows live under the page.
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "root:/settings"
import "../../settings/center"
import "root:/settings/center/Pages.js" as Pages
import "root:/plugins/installMenu/InstallOptions.js" as InstallOptions
import "root:/plugins/store/AppIcons.js" as AppIcons
import "root:/plugins/store/PackageIds.js" as PackageIds
import "root:/plugins/store/AppMeta.js" as AppMeta
import "root:/style/backdrop"
import "../../style/AequalynLooks.js" as Looks
import "../../Plugins.js" as PluginRegistry
import "../../PluginInfo.js" as PluginInfo

Scope {
    id: root
    // the live palette, bound by the shell's PluginManager; the fallback is the one
    // every module uses, so the Store dresses like the control center on any theme
    property var theme: AequalynDefaultTheme {}
    // words in a plain sans, numbers, paths, keys and icons in the shell's mono
    readonly property string sans: Cc.sans
    readonly property string mono: Cc.mono
    property bool open: false
    property string section: "home"
    property string category: ""
    // Which of the two left lists the arrows work in. Right moves from the
    // squares to the section list, Left back; Up/Down then move in that list.
    property string navSide: "sections"
    // the title-bar search, as the control center's: apps and settings share one
    // results view, with a chip for each source, one page per app, and keys to move
    property string query: ""
    property string querySource: "All"
    property string settingCat: ""
    property int pick: 0
    readonly property bool queryActive: root.query.trim() !== ""
    readonly property var resultSources: ["All", "Apps", "Arch", "AUR", "Flatpak", "Snap", "Installed", "Settings"]
        .concat(Pages.categories.map(c => c.key))
    function resultLabel(source) {
        if (source === "Apps") return "All Apps";
        const c = Pages.categories.find(x => x.key === source);
        return c ? c.title : source;
    }
    function isSettingSource(source) {
        return source === "Settings" || Pages.categories.some(c => c.key === source);
    }
    function normKey(s) { return String(s || "").toLowerCase().replace(/[^a-z0-9]+/g, " ").trim(); }
    // one app can arrive from several backends under different ids; the curated
    // list knows them, else the name is the best identity we have
    function curatedFor(r) {
        const id = root.normKey(r.id), name = root.normKey(r.name || r.id);
        const byId = root.apps.find(a => id !== "" && (
            (r.source === "Arch" && root.normKey(a.pacman) === id) ||
            (r.source === "AUR" && root.normKey(a.aur) === id) ||
            (r.source === "Flatpak" && root.normKey(a.flatpak) === id) ||
            (r.source === "Snap" && root.normKey(a.snap) === id)));
        if (byId) return byId;
        return root.apps.find(a => root.normKey(a.name) === name || root.normKey(a.id) === name) || null;
    }
    function appIcon(c, r) {
        return root.appIconUrl(c && c.icon ? c.icon : (r && r.icon), (r && (r.name || r.id)) || "");
    }
    // The app list uses the same categories as Super + I. Everything that is not
    // one of those curated choices stays in All and under Uncategorised.
    // AI stays one place: the AI tools page. Super + I keeps its AI group, but
    // the Store's Apps rail does not repeat it.
    readonly property var appCategories: InstallOptions.categories
        .filter(c => c.key !== "all" && c.key !== "ai")
    property string appCategory: "all"
    // A category shows at most 30 apps: two pages of the same 5x3 grid.
    readonly property int categoryAppLimit: 30
    // Only the picked category gets a page. Web apps, AI tools and AppImages are
    // their own sections; All Apps keeps its search and source filters.
    readonly property var currentAppCategory: root.section !== "apps" || root.appCategory === "all"
        ? null : (root.appCategories.find(c => c.key === root.appCategory) || null)
    function backendKey(source) {
        const s = String(source || "").toLowerCase();
        if (s === "pacman") return "arch";
        return s;
    }
    function optionForResult(r) {
        if (!r) return null;
        const src = root.backendKey(r.source), id = root.normKey(r.id);
        const name = root.normKey(r.name || r.id), curated = root.curatedFor(r);
        const curatedName = curated ? root.normKey(curated.name) : "";
        return InstallOptions.options.find(o => {
            const c = o.cmd || [];
            if (c[0] !== "qs" || c[4] !== "package") return false;
            if (root.backendKey(c[5]) === src && root.normKey(c[6]) === id) return true;
            const label = root.normKey(o.label);
            return label !== "" && (label === name || (curatedName !== "" && label === curatedName));
        }) || null;
    }
    function categoryForResult(r) {
        const o = root.optionForResult(r);
        return o && o.category ? o.category : "other";
    }
    function appCategoryCount(key) {
        const pool = root.appPool || [];
        return key === "all" ? pool.length : root.appsInCategory(key).length;
    }
    // A category page shows its own apps: matches from the current app list first,
    // then the curated Super + I packages for that group. Live search rows win,
    // and one app never appears twice because source and id are the same.
    function appsInCategory(key) {
        const seen = {}, out = [];
        function add(r) {
            if (!r || !r.source || !r.id) return;
            const sig = root.backendKey(r.source) + "|" + root.normKey(r.id);
            if (seen[sig]) return;
            seen[sig] = true;
            out.push(r);
        }
        for (const r of root.appPool || [])
            if (root.categoryForResult(r) === key) add(r);
        const curated = InstallOptions.options
            .filter(o => o.category === key && root.packageOption(o))
            .map(o => root.optionResult(o));
        for (const r of curated)
            if (root.foundSource !== "Installed" || r.installed) add(r);
        return out;
    }
    // One card per app, with the same four install buttons the Popular apps grid
    // uses. Sources for the same app are merged, so it never appears twice.
    function appCardShape(r) {
        const via = root.backendKey(r.source);
        const a = { name: r.name || r.id || "", about: r.about || "",
                    icon: root.appIconUrl(r.icon, r.name || r.id),
                    pacman: r.pacman || "", aur: r.aur || "",
                    flatpak: r.flatpak || "", snap: r.snap || "" };
        if (via === "arch") a.pacman = r.id;
        else if (via === "aur") a.aur = r.id;
        else if (via === "flatpak") a.flatpak = r.id;
        else if (via === "snap") a.snap = r.id;
        return a;
    }
    function categoryAppCards(key) {
        const byName = {}, out = [];
        for (const r of root.appsInCategory(key)) {
            const nk = root.normKey(r.name || r.id);
            const s = root.appCardShape(r);
            let a = byName[nk];
            if (!a) { byName[nk] = s; out.push(s); continue; }
            for (const k of ["pacman", "aur", "flatpak", "snap"])
                if (s[k] && !a[k]) a[k] = s[k];
            if (!a.icon && s.icon) a.icon = s.icon;
            if (!a.about && s.about) a.about = s.about;
        }
        return out.slice(0, root.categoryAppLimit);
    }
    function packageOption(o) {
        const c = (o && o.cmd) || [];
        return c[0] === "qs" && c[4] === "package";
    }
    // A curated choice carries a font glyph, not an image. The icon library maps
    // it to the closest published icon name, then to a local badge when there is
    // none, so every app in every category has its own face.
    function iconForOption(o) {
        return AppIcons.slugForOption(o);
    }
    // One icon policy for every app card: a real image when the icon set has it,
    // and a locally generated badge for everything else. No 404 requests.
    function appIconUrl(icon, name) {
        return AppIcons.url(icon, name);
    }
    // Web apps and AppImages keep their icon as a local file. When no file was
    // saved -- or it has gone missing -- the same generated badge every other
    // app uses stands in, so no app ever shows a blank or shared icon.
    function localAppIcon(path, name) {
        const p = String(path || "").trim();
        if (p === "") return root.appIconUrl("", name);
        if (/^(?:https?:|file:|data:)/i.test(p)) return p;
        return "file://" + p;
    }
    function appInitials(name) {
        return AppIcons.initials(name);
    }
    function appMonogramColor(name) {
        return Qt.hsla(AppIcons.hue(name) / 360, 0.42, 0.42, 1);
    }
    // A curated AI package is shown on the AI tools page with the same cards as
    // All Apps. Give it the plain result shape those cards and actions expect.
    function optionResult(o) {
        const c = (o && o.cmd) || [];
        const via = ({ arch: "Arch", aur: "AUR", flatpak: "Flatpak", snap: "Snap" })[String(c[5]).toLowerCase()] || "AUR";
        const ids = PackageIds.forOption(o);
        const r = { source: via, id: c[6] || "", name: o.label || c[6] || "",
                    about: AppMeta.aboutFor(o.id) || o.words || "",
                    icon: AppMeta.iconFor(o.id) || root.iconForOption(o), installed: false,
                    flatpak: ids.flatpak || "", snap: ids.snap || "" };
        r.installed = root.foundInstalled(r);
        return r;
    }
    function aiAppResults() {
        return InstallOptions.options
            .filter(o => o.category === "ai" && root.packageOption(o))
            .map(o => root.optionResult(o));
    }
    // The terminal agents keep their own lifecycle, but they are still apps: the
    // same checked package ids and icon/description data feed a full app page.
    function aiMeta(tool) {
        return tool && tool.id ? AppMeta.aiFor(tool.id) : ({});
    }
    function aiIconUrl(tool) {
        const m = root.aiMeta(tool);
        return root.appIconUrl(m.icon || "", (tool && tool.name) || (tool && tool.id) || "ai tool");
    }
    function openAiApp(tool) {
        if (!tool) return;
        const m = root.aiMeta(tool);
        const sources = [];
        [["Arch", m.arch], ["AUR", m.aur], ["Flatpak", m.flatpak], ["Snap", m.snap]]
            .forEach(x => { if (x[1]) sources.push({ source: x[0], id: x[1], name: tool.name || tool.id }); });
        root.openApp({
            key: "ai-tool:" + (tool.id || ""),
            name: tool.name || tool.id || "AI tool",
            about: m.about || tool.description || "",
            icon: root.aiIconUrl(tool),
            sources: sources,
            installed: !!tool.installed,
            popularity: 0
        });
    }
    readonly property var appResults: {
        const list = root.found.slice();
        const q = root.query.trim().toLowerCase();
        for (const a of root.installedApps) {
            if (q !== "" && (a.name + " " + a.id).toLowerCase().indexOf(q) < 0) continue;
            list.push({ source: a.source, id: a.id, name: a.name, version: a.version,
                        about: a.version !== "" ? "Version " + a.version : "Installed",
                        icon: root.installedIcon(a, root.apps), installed: true });
        }
        return list;
    }
    readonly property var appGroups: {
        const groups = [], byKey = {};
        for (const r of root.appResults) {
            if (!r || !r.source || !r.id) continue;
            const c = root.curatedFor(r);
            const key = c ? "curated:" + c.id : "name:" + (root.normKey(r.name || r.id) || root.normKey(r.id));
            let g = byKey[key];
            if (!g) {
                g = { key: key, name: (c && c.name) || r.name || r.id, about: (c && c.about) || r.about || "",
                      icon: root.appIcon(c, r), curated: c, sources: [], installed: false, popularity: 0 };
                byKey[key] = g;
                groups.push(g);
            }
            const sig = r.source + "|" + r.id;
            if (!g.sources.some(s => s.source + "|" + s.id === sig)) g.sources.push(r);
            if (!g.about && r.about) g.about = r.about;
            if (!g.icon && r.icon) g.icon = r.icon;
            g.installed = g.installed || !!r.installed || root.foundInstalled(r);
            g.popularity = Math.max(g.popularity, Number(r.popularity) || 0);
        }
        groups.sort((a, b) => (b.installed ? 1 : 0) - (a.installed ? 1 : 0)
            || b.popularity - a.popularity || a.name.localeCompare(b.name));
        return groups;
    }
    readonly property var allSettingResults: root.queryActive ? Pages.search(root.query.trim(), "") : []
    function resultCount(source) {
        if (source === "All") return root.appGroups.length + root.allSettingResults.length;
        if (source === "Apps") return root.appGroups.length;
        if (source === "Settings") return root.allSettingResults.length;
        if (root.isSettingSource(source)) return root.allSettingResults.filter(r => r.cat === source).length;
        if (source === "Installed") return root.appGroups.filter(g => g.installed).length;
        return root.appGroups.filter(g => g.sources.some(s => s.source === source)).length;
    }
    function rowsFor(source) {
        let apps = [], sets = [];
        if (root.isSettingSource(source)) {
            sets = source === "Settings" ? root.allSettingResults
                : root.allSettingResults.filter(r => r.cat === source);
        } else {
            apps = source === "Installed" ? root.appGroups.filter(g => g.installed)
                : source === "All" || source === "Apps" ? root.appGroups
                : root.appGroups.filter(g => g.sources.some(s => s.source === source));
            if (source === "All") sets = root.allSettingResults;
        }
        return apps.map(g => ({ kind: "app", group: g }))
            .concat(sets.map(r => ({ kind: "setting", result: r })));
    }
    readonly property var resultShown: root.rowsFor(root.querySource)
    function setQuerySource(source) {
        root.querySource = source;
        root.settingCat = root.isSettingSource(source) && source !== "Settings" ? source : "";
        root.pick = 0;
    }

    function searchFromTitle() {
        if (!root.queryActive) return;
        root.open = true;
        root.foundSource = ["Arch", "AUR", "Flatpak", "Snap", "Installed"].indexOf(root.querySource) >= 0
            ? root.querySource : "All";
        root.foundAt = 0;
        root.detectApps();
        root.searchApps(root.query.trim(), false);
    }
    onQueryChanged: {
        root.pick = 0;
        root.foundAt = 0;
        if (root.queryActive) {
            root.appPage = null;
            root.appDetail = null;
            titleSearchTimer.restart();
        } else {
            titleSearchTimer.stop();
            root.found = [];
            root.foundErrors = {};
            root.appPage = null;
            root.appDetail = null;
            root.appReturn = null;
        }
    }
    Timer {
        id: titleSearchTimer
        interval: 350
        onTriggered: root.searchFromTitle()
    }

    // ---- one app, one page --------------------------------------------------------------
    // the search lists an app once, however many managers can install it; its page
    // gathers the details from all of them. The state of the page we came from is
    // kept so Back really goes back there, search results included.
    property var appPage: null
    property var appReturn: null
    property var appDetail: null
    property bool appDetailBusy: false
    property var appDetailErrors: ({})
    readonly property string detailErrorText: Object.keys(root.appDetailErrors)
        .filter(k => String(k).trim() !== "")
        .map(k => k + (root.appDetailErrors[k] ? " — " + String(root.appDetailErrors[k]).slice(0, 80) : ""))
        .join(", ")
    function appIds(g) {
        const ids = { "Arch": "", "AUR": "", "Flatpak": "", "Snap": "" };
        // the curated card knows every id, even when search only loaded one of
        // them; those ids must reach app-info or the page loses install paths
        const c = g.curated || {};
        ids.Arch = c.pacman || "";
        ids.AUR = c.aur || "";
        ids.Flatpak = c.flatpak || "";
        ids.Snap = c.snap || "";
        for (const s of g.sources) if (ids[s.source] !== undefined && !ids[s.source]) ids[s.source] = s.id;
        return ids;
    }
    // app-info validates a display name before it queries the backends. Curated
    // names like ".NET" and "Heroic (Epic Games)" are still plain app names, so
    // pass them through unchanged; the backend ids are validated on their own.
    function appInfoName(g) {
        return String((g && g.name) || (g && g.id) || "app").slice(0, 80);
    }
    function openApp(g) {
        if (!g) return;
        if (appInfoProc.running) appInfoProc.running = false;
        if (!root.appPage) root.appReturn = { query: root.query, querySource: root.querySource,
            settingCat: root.settingCat, section: root.section, category: root.category,
            pick: root.pick, foundAt: root.foundAt, foundSource: root.foundSource };
        root.appPage = g;
        root.appDetail = null;
        root.appDetailBusy = true;
        root.appDetailErrors = {};
        const ids = root.appIds(g);
        appInfoProc.command = ["aequalyn-store", "app-info", root.appInfoName(g)]
            .concat(ids.Arch ? ["--arch", ids.Arch] : [])
            .concat(ids.AUR ? ["--aur", ids.AUR] : [])
            .concat(ids.Flatpak ? ["--flatpak", ids.Flatpak] : [])
            .concat(ids.Snap ? ["--snap", ids.Snap] : []);
        appInfoProc.running = true;
    }
    function backFromApp() {
        const r = root.appReturn || {};
        root.appPage = null;
        root.appDetail = null;
        root.appDetailBusy = false;
        root.appDetailErrors = {};
        if (r.query !== undefined) {
            root.query = r.query || "";
            root.querySource = r.querySource || "All";
            root.settingCat = r.settingCat || "";
            root.section = r.section || root.section;
            root.category = r.category || "";
            root.pick = r.pick || 0;
            root.foundAt = r.foundAt || 0;
            root.foundSource = r.foundSource || "All";
        }
        root.appReturn = null;
        titleSearch.forceActiveFocus();
    }
    function detailSources() {
        if (!root.appPage) return [];
        const fetched = root.appDetail ? root.appDetail.sources : [];
        const ids = root.appIds(root.appPage);
        let wanted = Object.keys(ids).filter(k => ids[k]).map(k => ({ source: k, id: ids[k] }));
        if (wanted.length === 0) wanted = root.appPage.sources.map(s => ({ source: s.source, id: s.id }));
        // app-info can also find an AUR build by the app's plain name; show it
        // even when no curated id advertised it
        for (const s of fetched) if (!wanted.some(x => x.source === s.source))
            wanted.push({ source: s.source, id: s.id });
        return wanted.map(base => {
            const got = fetched.find(s => s.source === base.source)
                || fetched.find(s => root.normKey(s.id) === root.normKey(base.id)) || {};
            const searchHit = root.appPage.sources.find(x => x.source === base.source && x.id === base.id)
                || root.appPage.sources.find(x => x.source === base.source) || {};
            const c = root.appPage.curated || {};
            return Object.assign({}, got, {
                source: base.source,
                id: base.id,
                name: got.name || searchHit.name || root.appPage.name,
                icon: got.icon || searchHit.icon || (c.icon ? root.appIcon(c, searchHit) : root.appPage.icon) || "",
                installed: !!got.installed || root.foundInstalled({ source: base.source, id: base.id }),
                about: got.about || searchHit.about || "",
                version: got.version || searchHit.version || "",
                url: got.url || "",
                license: got.license || "",
                size: got.size || "",
                details: got.details || []
            });
        });
    }
    // a short, quiet set of facts for the app's own page: the useful fields from
    // whichever source published them, never a wall of package-manager output
    function appFacts() {
        if (!root.appPage) return [];
        const sources = root.detailSources();
        const primary = sources.find(s => (s.details || []).length > 0) || sources[0] || {};
        const wanted = ["Version", "License", "Size", "Installed Size", "Download Size",
                        "Developer", "Publisher", "Maintainer", "Repository", "Architecture",
                        "Votes", "Popularity", "Last updated", "Latest release", "Latest version", "Categories"];
        const out = [];
        function add(label, value) {
            value = String(value === undefined || value === null ? "" : value).trim();
            if (value !== "" && value.length <= 90 && !out.some(f => f.label === label))
                out.push({ label: label, value: value });
        }
        add("Version", primary.version);
        add("License", primary.license);
        add("Size", primary.size);
        for (const d of (primary.details || [])) if (wanted.indexOf(d.label) >= 0) add(d.label, d.value);
        return out.slice(0, 8);
    }
    // every useful line a manager published, in a compact list that fills its card
    // find the one app group behind any card: a search result, an installed row
    // or one of the curated cards. If the group is not loaded yet, build it from
    // the card itself so every card has somewhere to go.
    function groupFor(a) {
        if (!a) return null;
        const c = root.curatedFor(a);
        if (c) {
            const byCurated = root.appGroups.find(g => g.key === "curated:" + c.id);
            if (byCurated) return byCurated;
        }
        const nameKey = "name:" + (root.normKey(a.name || a.id) || "");
        const byName = root.appGroups.find(g => g.key === nameKey);
        if (byName) return byName;
        if (a.source && a.id) {
            const bySource = root.appGroups.find(g => g.sources.some(s => s.source === a.source && s.id === a.id));
            if (bySource) return bySource;
        }
        const sources = [];
        if (a.source && a.id) sources.push(a);
        else {
            [["Arch", a.pacman], ["AUR", a.aur], ["Flatpak", a.flatpak], ["Snap", a.snap]]
                .forEach(x => { if (x[1]) sources.push({ source: x[0], id: x[1], name: a.name, about: a.about }); });
        }
        return {
            key: c ? "curated:" + c.id : nameKey,
            name: (c && c.name) || a.name || a.id,
            about: (c && c.about) || a.about || "",
            icon: c && c.icon ? root.appIcon(c, a) : (a.icon || ""),
            curated: c,
            sources: sources,
            installed: sources.some(s => root.foundInstalled(s)) || root.installedVia(a) !== "",
            popularity: Number(a.popularity) || 0
        };
    }
    function sourceDetails(s) {
        if (!s) return [];
        const out = [];
        function add(label, value) {
            value = String(value === undefined || value === null ? "" : value).trim();
            if (value !== "" && !out.some(x => x.label === label)) out.push({ label: label, value: value });
        }
        add("Package", s.id);
        if (s.installedVersion) add("Installed", s.installedVersion);
        add("License", s.license);
        add("Size", s.size);
        for (const d of (s.details || [])) add(d.label, d.value);
        add("Project", s.url);
        return out.filter(x => x.value.length <= 60).slice(0, 10);
    }
    Process {
        id: appInfoProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.appDetailBusy = false;
                try {
                    const d = JSON.parse(text);
                    root.appDetail = d.apps && d.apps[0] ? d.apps[0] : null;
                    root.appDetailErrors = d.errors || {};
                } catch (e) { root.appDetailErrors = { all: "the details could not be read" }; }
            }
        }
    }

    // ---- settings, found from the Store too ------------------------------------------------
    function settingValue(e) {
        if (!e || !e.setting) return "";
        const v = AequalynSettings[e.setting];
        if (e.kind === "toggle") return v ? "On" : "Off";
        if (e.kind === "slider") return (Number(v) % 1 === 0 ? String(v) : Number(v).toFixed(1)) + (e.unit || "");
        if (e.kind === "choice") { const o = (e.options || []).find(x => x.key === v); return o ? o.label : String(v); }
        return "";
    }
    function adjustSetting(e, dir) {
        if (!e || !e.setting) return;
        const v = AequalynSettings[e.setting];
        if (e.kind === "toggle") { AequalynSettings.apply(e.setting, !v); return; }
        if (e.kind === "slider") {
            const step = e.step || 1, lo = e.from !== undefined ? e.from : 0, hi = e.to !== undefined ? e.to : 100;
            const next = Math.max(lo, Math.min(hi, Number((Number(v) + dir * step).toFixed(4))));
            if (next !== Number(v)) AequalynSettings.apply(e.setting, next);
            return;
        }
        if (e.kind === "choice" && (e.options || []).length > 0) {
            const keys = e.options.map(o => o.key);
            const i = keys.indexOf(v);
            AequalynSettings.apply(e.setting, keys[((i < 0 ? 0 : i) + dir + keys.length) % keys.length]);
        }
    }
    function activateSetting(r) {
        if (!r) return;
        if (r.entry && r.entry.setting && r.entry.kind === "toggle") { root.adjustSetting(r.entry, 1); return; }
        const target = Pages.resolve(r.page + (r.tab ? ":" + r.tab : ""));
        Quickshell.execDetached(["qs", "ipc", "call", "aequalyn", "reveal", target.page, r.label]);
        root.open = false;
    }
    function activateResult(row) {
        if (!row) return;
        if (row.kind === "app") root.openApp(row.group);
        else root.activateSetting(row.result);
    }
    function preferredSource(g) {
        const order = ["Arch", "AUR", "Flatpak", "Snap"];
        const choices = g.sources.slice().sort((a, b) => order.indexOf(a.source) - order.indexOf(b.source));
        return choices.find(s => !root.foundInstalled(s)) || choices[0] || null;
    }

    readonly property var sections: [
        { key: "home",      label: "Home",       glyph: "\u{F02DC}" },
        { key: "plugin",    label: "Plugins",    glyph: "\u{F0431}" },
        { key: "theme",     label: "Themes",     glyph: "\u{F03D8}" },
        { key: "cursor",    label: "Cursors",    glyph: "\u{F01BE}" },
        { key: "wallpaper", label: "Wallpapers", glyph: "\u{F02E9}" },
        { key: "look",      label: "Looks",      glyph: "\u{F0E09}" },
        { key: "apps",      label: "All Apps",   glyph: "\u{F003B}" },
        { key: "web",       label: "Web apps",   glyph: "\u{F0595}" },
        { key: "ai",        label: "AI tools",   glyph: "\u{F06A9}" },
        { key: "appimage",  label: "AppImages",  glyph: "\u{F01D4}" },
        { key: "market",    label: "Market",     glyph: "\u{F0110}" },
        { key: "updates",   label: "Updates",    glyph: "\u{F06B0}" }
    ]
    // the control center's two levels: a short rail of categories, then the
    // sections of the chosen one beside it. Home stands apart.
    readonly property var categories: [
        { key: "get",    title: "Get",     icon: "\u{F0431}", sections: ["plugin", "theme", "cursor", "wallpaper", "look"] },
        { key: "apps",   title: "Apps",    icon: "\u{F003B}", sections: ["apps", "web", "ai"]
            .concat(root.appCategories.map(c => "appcat:" + c.key)).concat(["appimage"]) },
        { key: "manage", title: "Manage", icon: "\u{F0110}", sections: ["market", "updates"] }
    ]
    readonly property var categoryNow: root.categories.find(c => c.key === root.category) || null
    // The Apps rail shows All Apps, Web apps and AI tools, then the Super + I
    // categories, then AppImages. Picking a category opens just that category's
    // page; All Apps keeps its own search, source and category filters.
    readonly property var sectionNavItems: {
        if (!root.categoryNow) return [];
        const items = [];
        for (const key of root.categoryNow.sections) {
            if (key.indexOf("appcat:") === 0) {
                const c = root.appCategories.find(x => x.key === key.slice(7));
                if (c) items.push({ key: "apps", label: c.label, glyph: c.icon || "", appCategory: c.key });
                continue;
            }
            const s = root.sections.find(x => x.key === key) || {};
            items.push(key === "apps"
                ? { key: "apps", label: "All Apps", glyph: s.glyph || "", appCategory: "all" }
                : { key: key, label: s.label || key, glyph: s.glyph || "" });
        }
        return items;
    }
    function navIsOn(item) {
        if (!item || root.section !== item.key) return false;
        if (item.appCategory === undefined) return item.key !== "apps" || root.appCategory === "all";
        return root.appCategory === item.appCategory;
    }
    readonly property var currentNavItem: root.sectionNavItems.find(i => root.navIsOn(i)) || null
    function currentTitle() {
        if (root.currentNavItem) return root.currentNavItem.label;
        const s = root.sections.find(x => x.key === root.section);
        return s ? s.label : "";
    }
    // the shell's own plugins, as the control center lists them; the control center
    // itself is left out because turning it off would lock you out
    readonly property var builtInPlugins: PluginRegistry.list.filter(p => p.id !== "settings")
    function builtInInfo(id) {
        // the registry's clipscape id and PluginInfo's clipboard key are one plugin
        return PluginInfo.of(id === "clipscape" ? "clipboard" : id);
    }
    readonly property string wallpaperDir: Quickshell.env("HOME") + "/.local/share/aequalyn/wallpapers"
    readonly property var builtInCursors: [
        { id: "plume", label: "Plume", about: "The cursor designer that ships with Aequalyn: draw the pointer, its trail and its halo here.",
          icon: "\u{F01C0}" }
    ]
    readonly property var builtInLooks: Looks.ensembles.map(e => ({
        id: e.key, label: e.label, about: e.about, icon: "\u{F0E09}"
    }))
    // what others made: what is installed here, then what the Market has of it, each with
    // what the catalog says about it
    function communityEntries(kind) {
        const glyph = (root.sections.find(s => s.key === kind) || {}).glyph || "\u{F0431}";
        const listed = root.market.filter(m => m.kind === kind);
        const mine = root.itemsOf(kind).map(i => {
            const m = listed.find(x => x.id === i.id && x.repo === i.source);
            return Object.assign({}, i, {
                label: (m && m.name) || i.label || i.id,
                about: (m && m.about) || i.source || "",
                icon: glyph,
                installed: true,
                preview: (m && m.preview) || "",
                by: (m && m.by) || "",
                market: m || null,
                // from git: whether its repo has anything newer is only known by asking it
                newer: m ? m.state === "update available" : true
            });
        });
        // by what is listed above, not by the catalog's word: one of the two is read first.
        // An id is installed once, wherever it came from: one card for it
        const others = listed.filter(m => !mine.some(i => i.id === m.id)).map(m => ({
            id: m.id, label: m.name || m.id, about: m.about || m.repo, icon: glyph, installed: false,
            preview: m.preview || "", by: m.by || "", source: m.repo, market: m, newer: false,
            blocked: m.state === "another installed"
        }));
        return mine.concat(others);
    }
    function installFromMarket(kind, entry) {
        if (kind === "app") {
            root.inTerminal("aequalyn-store install-market app:" + entry.id);
            return;
        }
        root.runJob("Installing " + (entry.label || entry.id), ["install-market", kind + ":" + entry.id]);
    }
    function builtInEntries(kind) {
        if (kind === "theme") return root.themeCatalog
            .filter(i => (i.label || "Built-in") !== "Community")
            .map(i => ({ id: i.id, label: i.name || i.id, about: "A theme shipped with Aequalyn.",
                         icon: "\u{F03D8}", installed: !!i.installed, preview: i.preview || "",
                         source: i.source }));
        if (kind === "wallpaper") return root.wallpaperCatalog
            .map(i => ({ id: i.id, label: i.id, about: "A wallpaper shipped with Aequalyn.",
                         icon: "\u{F02E9}", installed: !!i.installed,
                         preview: i.source, source: i.source }));
        if (kind === "cursor") return root.builtInCursors;
        if (kind === "look") return root.builtInLooks;
        return [];
    }
    function getPrimary(kind, entry, builtIn) {
        const name = entry.label || entry.id;
        if (builtIn && kind === "cursor") {
            root.runSide(["qs", "ipc", "call", "aequalyn", "page", "cursor"]);
            return;
        }
        if (builtIn && kind === "look") {
            root.runSide(["qs", "ipc", "call", "aequalyn", "openSettings"]);
            return;
        }
        if (builtIn && kind === "theme" && !entry.installed) {
            root.runJob("Installing " + name, ["install", "theme", entry.source]);
            return;
        }
        if (builtIn && kind === "wallpaper" && !entry.installed) {
            root.runCmd("Installing " + name,
                ["sh", "-c", "mkdir -p \"$HOME/.local/share/aequalyn/wallpapers\" && cp -f \"$1\" \"$HOME/.local/share/aequalyn/wallpapers/\" && echo OK",
                 "sh", entry.source]);
            return;
        }
        if (kind === "theme") root.runSide(["qs", "ipc", "call", "theme", "set", entry.id]);
        else if (kind === "cursor") root.runSide(["sh", "-c", 'hyprctl setcursor "$1" 24 && gsettings set org.gnome.desktop.interface cursor-theme "$1"', "sh", entry.id]);
        // a pack is a folder: its first wallpaper
        else if (kind === "wallpaper" && !builtIn) root.runSide(["sh", "-c",
            'f=$(find "$1" -maxdepth 1 -type f ! -name ".*" | LC_ALL=C sort | head -n 1); [ -n "$f" ] && exec aequalyn-wallpaper set "$f"',
            "sh", root.wallpaperDir + "/" + entry.id]);
        else if (kind === "wallpaper") root.runSide(["aequalyn-wallpaper", "set", root.wallpaperDir + "/" + entry.id]);
        else if (kind === "look") root.runJob("Wearing " + name, ["apply-look", entry.id]);
    }
    function communityHint(kind) {
        if (kind === "") return "";
        const one = root.kindWords[kind] ? root.kindWords[kind].one : kind;
        return root.communityEntries(kind).length === 0
            ? "No community " + one + " from the Store yet. Add one with the form below."
            : "Made by others. What comes from the Market was reviewed, and is installed at the exact commit that was.";
    }
    function builtInHint(kind) {
        if (kind === "cursor") return "The cursor designer ships with Aequalyn. Open it here and wear what you make.";
        if (kind === "look") return "These ensembles ship with the shell. Open Control Center to wear one, then fine tune it.";
        return "These ship with Aequalyn. Install or apply them here; the published catalogue syncs when you open this page.";
    }
    function isVideoName(name) { return /\.(mp4|webm|mkv|mov)$/i.test(String(name || "")); }
    function pluginPreview(entry, builtIn) {
        let info = {};
        let base = "";
        if (builtIn) {
            info = root.pluginInfoOf(entry, true);
            const reg = PluginRegistry.list.find(p => p.id === entry.id);
            if (reg && reg.source) base = Qt.resolvedUrl("../../" + reg.source).toString().replace(/\/[^/]+$/, "");
        } else {
            const user = UserPlugins.byId(entry.id);
            info = user && user.info ? user.info : {};
            if (user && user.source) base = user.source.replace(/\/[^/]+$/, "");
        }
        const raw = info.preview || info.image || info.screenshot || "";
        if (raw) {
            if (raw.indexOf("://") >= 0 || raw.charAt(0) === "/") return raw;
            return base ? base + "/" + raw : raw;
        }
        return base ? base + "/preview.png" : "";
    }
    function previewFor(kind, entry, builtIn) {
        if (entry.preview) return entry.preview;
        if (!builtIn && entry.installed === false) return "";
        if (kind === "theme") {
            const known = root.themeCatalog.find(t => t.id === entry.id);
            if (known && known.preview) return known.preview;
            return entry.source ? entry.source + "/preview.jpg" : "";
        }
        if (kind === "wallpaper") return builtIn ? entry.source : (root.wallpaperDir + "/" + entry.id);
        if (kind === "plugin") return root.pluginPreview(entry, builtIn);
        return "";
    }
    // A first frame is enough for a card: one ffmpeg process at a time fills
    // a small cache, instead of dozens of live Video players in the grids.
    property var videoThumbs: ({})
    property var videoThumbQueue: []
    property bool videoThumbRunning: false
    function videoThumbPath(path) {
        let h = 0;
        for (let i = 0; i < path.length; i++) h = (h * 31 + path.charCodeAt(i)) | 0;
        return Quickshell.env("HOME") + "/.cache/aequalyn/store-previews/" + Math.abs(h).toString(36) + ".jpg";
    }
    function queueVideoThumb(path) {
        if (!path || root.videoThumbs[path] || root.videoThumbQueue.indexOf(path) >= 0) return;
        root.videoThumbQueue.push(path);
        root.runNextVideoThumb();
    }
    function runNextVideoThumb() {
        if (root.videoThumbRunning || root.videoThumbQueue.length === 0) return;
        const path = root.videoThumbQueue.shift();
        root.videoThumbRunning = true;
        videoThumbProc.path = path;
        videoThumbProc.command = ["sh", "-c",
            "mkdir -p \"$(dirname \"$2\")\"; [ -s \"$2\" ] || ffmpeg -y -loglevel error -i \"$1\" -frames:v 1 \"$2\"",
            "sh", path, root.videoThumbPath(path)];
        videoThumbProc.running = true;
    }
    Process {
        id: videoThumbProc
        property string path: ""
        onExited: code => {
            if (code === 0 && videoThumbProc.path !== "") {
                const next = Object.assign({}, root.videoThumbs);
                next[videoThumbProc.path] = root.videoThumbPath(videoThumbProc.path);
                root.videoThumbs = next;
            }
            root.videoThumbRunning = false;
            root.runNextVideoThumb();
        }
    }

    // one place that keeps the two left lists and the page in step, so an IPC
    // request or a card on Home lands on the right category as well
    function categoryOf(section) {
        for (let i = 0; i < root.categories.length; i++)
            if (root.categories[i].sections.indexOf(section) >= 0) return root.categories[i].key;
        return "";
    }
    function openSection(section) {
        if (!root.sections.some(s => s.key === section)) return;
        root.category = root.categoryOf(section);
        root.section = section;
        if (section === "apps") root.appCategory = "all";
        root.navSide = "sections";
    }
    function openCategory(key) {
        const c = root.categories.find(x => x.key === key);
        root.category = c ? c.key : "";
        root.section = c ? c.sections[0] : "home";
        if (c && c.key === "apps") root.appCategory = "all";
        root.navSide = "rail";
    }
    function openNav(item) {
        if (!item) return;
        if (item.appCategory !== undefined) {
            root.openSection("apps");
            root.appCategory = item.appCategory;
            root.foundAt = 0;
        } else {
            if (item.key === "apps") root.appCategory = "all";
            root.openSection(item.key);
        }
        root.navSide = "sections";
    }
    function focusRail() {
        if (root.queryActive || root.pickOpen || root.appPage) return;
        root.navSide = "rail";
        card.forceActiveFocus();
    }
    function focusSections() {
        if (root.queryActive || root.pickOpen || root.appPage || !root.categoryNow) return;
        root.navSide = "sections";
        card.forceActiveFocus();
    }
    function stepCategory(delta) {
        const keys = [""].concat(root.categories.map(c => c.key));
        const i = keys.indexOf(root.category);
        root.openCategory(keys[Math.max(0, Math.min(keys.length - 1, i + delta))]);
    }
    function stepSection(delta) {
        const items = root.sectionNavItems;
        if (items.length === 0) return;
        let i = 0;
        for (let j = 0; j < items.length; j++)
            if (root.navIsOn(items[j])) { i = j; break; }
        root.openNav(items[Math.max(0, Math.min(items.length - 1, i + delta))]);
    }
    readonly property var kindWords: ({
        plugin: { one: "plugin", hint: "A git repo with a plugin.json: it is checked (its files, qmllint, what it may run), then installed into ~/.local/share/aequalyn/plugins and switched on at once." },
        theme: { one: "theme", hint: "A git repo with a theme.json (or colors.toml) and a backgrounds/ folder. It is checked, then lands in ~/.config/aequalyn/themes and shows in Super + T." },
        cursor: { one: "cursor", hint: "A git repo with an XCursor cursors/ folder or a Hyprcursor manifest. It lands in ~/.local/share/icons; wear it here or on the Cursor page." },
        wallpaper: { one: "wallpaper pack", hint: "A git repo with an index.json listing its wallpapers: each file is fetched from the pack's own repo, checked, and kept in ~/.local/share/aequalyn/wallpapers." },
        look: { one: "look", hint: "A git repo with a look.json: a bar look, a dock look, a cursor look, a lock screen, lock and sleep timings, a login (SDDM) theme, or several. Wear all of it or one piece." }
    })
    readonly property var pieceWords: ({ bar: "Bar", dock: "Docks", cursor: "Cursor", lock: "Lock screen", sleep: "Lock and sleep", sddm: "Login screen" })

    // ---- what is installed ------------------------------------------------------------
    property var installed: []
    function itemsOf(kind) { return root.installed.filter(i => i.kind === kind); }
    // what can update from git: an AppImage is one file with no source to fetch,
    // so the Updates page leaves it to its own page
    readonly property var updatable: root.installed.filter(i => i.kind !== "appimage" && i.kind !== "app")
    // the plugin grids hold fifteen tiles per page, in rows of five
    function pluginAt(count, page) {
        return Math.min(page, Math.max(0, Math.ceil(count / 15) - 1)) * 15;
    }
    function pluginRows(items, page) {
        const at = root.pluginAt(items.length, page);
        const shown = items.slice(at, at + 15);
        const rows = [];
        for (let i = 0; i < shown.length; i += 5) rows.push(shown.slice(i, i + 5));
        // three rows on every page only where there are pages: the arrows stay put
        while (items.length > 15 && rows.length < 3) rows.push([]);
        return rows;
    }
    function pluginInfoOf(item, builtIn) {
        if (builtIn) return root.builtInInfo(item.id);
        const user = UserPlugins.byId(item.id);
        return user && user.info ? user.info : { icon: "\u{F0431}", keys: "", page: "", about: item.source || "" };
    }
    function refresh() { if (!listProc.running) listProc.running = true; }
    Process {
        id: listProc
        command: ["aequalyn-store", "list", "--json"]
        stdout: StdioCollector {
            onStreamFinished: { try { root.installed = JSON.parse(text); } catch (e) { root.installed = []; } }
        }
    }

    // ---- the Market's catalog (aequalyn-store refresh keeps it, checked) ---------------
    property var market: []
    property bool marketLoaded: false
    function loadMarket() { if (!marketProc.running) marketProc.running = true; }
    // the catalog kept fresh while the Store is used: quietly, at most once a minute;
    // what is already here shows at once
    property double marketFetched: 0
    function freshMarket() {
        root.loadMarket();
        if (Date.now() - root.marketFetched < 60000 || marketFetch.running) return;
        root.marketFetched = Date.now();
        marketFetch.running = true;
    }
    Process {
        id: marketFetch
        command: ["aequalyn-store", "refresh"]
        onExited: code => { if (code !== 0) root.marketFetched = 0; root.refresh(); root.loadMarket(); }
    }

    // ---- themes & wallpapers published in Aequalyn/aequalyn-themes ---------------------
    // aequalyn-update keeps a clone for the whole system, where the built-in themes are
    // too: that one is read, with no download here. Without it, the Store keeps its own.
    readonly property string themeRepoSh: "d=/var/lib/aequalyn/src/aequalyn-themes; own=; "
        + "[ -d \"$d/themes\" ] || { own=1; d=\"$HOME/.cache/aequalyn/aequalyn-themes\"; }; "
    property var themeCatalog: []
    property var wallpaperCatalog: []
    property bool repoSyncing: false
    function syncThemeRepo() {
        // show the local catalogue at once, even if git pull has no network
        if (root.section === "theme" && root.themeCatalog.length === 0 && !themeCatalogProc.running) themeCatalogProc.running = true;
        if (root.section === "wallpaper" && root.wallpaperCatalog.length === 0 && !wallpaperCatalogProc.running) wallpaperCatalogProc.running = true;
        if (!repoSync.running) repoSync.running = true;
    }
    Process {
        id: marketProc
        command: ["aequalyn-store", "market", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.market = JSON.parse(text); root.marketLoaded = true; }
                catch (e) { root.market = []; root.marketLoaded = false; }
            }
        }
    }

    // sync the Store's own clone, if it is the one in use, then read what there is
    Process {
        id: repoSync
        command: ["sh", "-c",
            root.themeRepoSh
            + "[ -n \"$own\" ] || exit 0; "
            + "mkdir -p \"$(dirname \"$d\")\"; "
            + "if [ -d \"$d/.git\" ]; then git -C \"$d\" pull -q; "
            + "else git clone -q --depth 1 https://github.com/Aequalyn/aequalyn-themes \"$d\"; fi"]
        onRunningChanged: root.repoSyncing = running
        onExited: code => {
            // a failed pull still leaves the last synced catalogue on disk, so
            // read it either way: an offline Store must not look empty
            if (!themeCatalogProc.running) themeCatalogProc.running = true;
            if (!wallpaperCatalogProc.running) wallpaperCatalogProc.running = true;
        }
    }
    Process {
        id: themeCatalogProc
        command: ["sh", "-c",
            root.themeRepoSh
            + "listed=$(aequalyn-themes list --json 2>/dev/null | jq -r '.[].id' 2>/dev/null || true); "
            + "for t in \"$d\"/themes/*/theme.json; do "
            + "  [ -f \"$t\" ] || continue; "
            + "  id=$(basename \"$(dirname \"$t\")\"); "
            + "  name=$(jq -r '.name // \"'\"$id\"'\"' \"$t\" 2>/dev/null || echo \"$id\"); "
            + "  if [ -d \"$HOME/.config/aequalyn/themes/$id\" ] || printf '%s\\n' \"$listed\" | grep -qx \"$id\"; then inst=1; else inst=0; fi; "
            + "  if [ \"$id\" = \"spectral\" ]; then lab=Community; else lab=Built-in; fi; "
            + "  dir=$(dirname \"$t\"); "
            + "  preview=$(find \"$dir/backgrounds\" -maxdepth 1 -type f 2>/dev/null | sort | head -1); "
            + "  [ -n \"$preview\" ] || preview=\"$dir/preview.jpg\"; "
            + "  printf '%s\\t%s\\t%s\\t%s\\t%s\\t%s\\n' \"$id\" \"$name\" \"$inst\" \"$lab\" \"$preview\" \"$dir\"; "
            + "done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    if (line.trim() === "") continue;
                    const p = line.split("\t");
                    out.push({ id: p[0], name: p[1] || p[0], installed: p[2] === "1",
                               label: p[3] || "Built-in", preview: p[4] || "", source: p[5] || "" });
                }
                root.themeCatalog = out;
            }
        }
    }
    Process {
        id: wallpaperCatalogProc
        command: ["sh", "-c",
            root.themeRepoSh
            + "d=\"$d/wallpapers\"; "
            + "for f in \"$d\"/*; do "
            + "  [ -f \"$f\" ] || continue; "
            + "  case \"$f\" in *.jpg|*.jpeg|*.png|*.webp|*.gif|*.mp4|*.webm|*.mkv|*.mov) ;; *) continue ;; esac; "
            + "  base=$(basename \"$f\"); "
            + "  if [ -f \"$HOME/.local/share/aequalyn/wallpapers/$base\" ]; then inst=1; else inst=0; fi; "
            + "  printf '%s\\t%s\\t%s\\n' \"$base\" \"$inst\" \"$f\"; "
            + "done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    if (line.trim() === "") continue;
                    const p = line.split("\t");
                    out.push({ id: p[0], installed: p[1] === "1", source: p[2] || "" });
                }
                root.wallpaperCatalog = out;
            }
        }
    }

    // ---- apps: the curated grid (apps.json) and the four backends ----------------------
    // pacman always; yay (the AUR), flatpak (Flathub) and snap when they are installed.
    // Installs run in a terminal, where sudo asks for the password.
    property var apps: []
    // the popular grid, fifteen to a page like the cards everywhere else; each
    // card carries its own four install buttons, greyed where there is no build
    property int popPage: 0
    readonly property var popShown: root.apps
    readonly property int popAt: Math.min(root.popPage, Math.max(0, Math.ceil(root.popShown.length / 15) - 1)) * 15
    property var backends: ({ yay: false, flatpak: false, snap: false })
    property var installedPkgs: ({ pacman: [], flatpak: [], snap: [] })
    // explicitly installed packages from every backend; many are CLI tools, so
    // All apps' Installed filter shows them instead of a separate apps section
    property var installedApps: []
    property string installedQuery: ""
    // the Installed view has no search result carrying an icon, so borrow the one
    // from the curated apps: the same dashboard icon the Popular apps grid uses
    function installedIcon(a, apps) {
        const keys = [a.id, a.name].map(v => (v || "").toLowerCase()).filter(v => v !== "");
        const hit = apps.find(x => [x.id, x.name, x.pacman, x.aur, x.flatpak, x.snap]
            .some(v => !!v && keys.indexOf(String(v).toLowerCase()) >= 0));
        return hit && hit.icon ? root.appIconUrl(hit.icon, a.name) : "";
    }
    readonly property var installedResults: root.installedApps
        .filter(a => root.installedQuery === "" ||
                     (a.name + " " + a.id).toLowerCase().indexOf(root.installedQuery.toLowerCase()) >= 0)
        .map(a => ({ source: a.source, id: a.id, name: a.name, version: a.version,
                     about: a.version !== "" ? "Version " + a.version : "Installed",
                     icon: root.installedIcon(a, root.apps), installed: true }))
    FileView {
        path: Qt.resolvedUrl("apps.json").toString().replace("file://", "")
        onLoaded: { try { root.apps = JSON.parse(text()); } catch (e) { root.apps = []; } }
    }
    function detectApps() { if (!detect.running) detect.running = true; }
    Process {
        id: detect
        // the same sweep fills the popular-app badges and All apps' Installed filter:
        // pacman's foreign packages are the AUR ones, and the source/name/version
        // records let a row run the right update or remove command
        command: ["sh", "-c",
            "for b in yay flatpak snap; do command -v \"$b\" >/dev/null 2>&1 && echo \"has $b\"; done; "
            + "echo \"#pacman\"; pacman -Qq 2>/dev/null; "
            + "echo \"#flatpak\"; flatpak list --app --columns=application 2>/dev/null; "
            + "echo \"#snap\"; snap list 2>/dev/null | tail -n +2 | cut -d\" \" -f1; "
            + "echo \"#your\"; "
            + "f=$(mktemp); pacman -Qqm 2>/dev/null > \"$f\"; "
            + "pacman -Qe 2>/dev/null | awk -v f=\"$f\" 'NR==FNR { foreign[$1]=1; next } !($1 in foreign) { printf \"Arch\\t%s\\t%s\\t%s\\n\", $1, $1, $2 }' \"$f\" -; "
            + "rm -f \"$f\"; "
            + "pacman -Qem 2>/dev/null | awk '{ printf \"AUR\\t%s\\t%s\\t%s\\n\", $1, $1, $2 }'; "
            + "flatpak list --app --columns=application,version,name 2>/dev/null | awk -F'\\t' '{ printf \"Flatpak\\t%s\\t%s\\t%s\\n\", $1, $3, $2 }'; "
            + "snap list --color=never 2>/dev/null | tail -n +2 | awk '{ printf \"Snap\\t%s\\t%s\\t%s\\n\", $1, $2, $2 }'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const b = { yay: false, flatpak: false, snap: false };
                const got = { pacman: [], flatpak: [], snap: [] };
                const yours = [];
                let part = "";
                for (const line of text.split("\n")) {
                    if (line.startsWith("has ")) b[line.slice(4)] = true;
                    else if (line.startsWith("#")) part = line.slice(1);
                    else if (line !== "" && got[part]) got[part].push(line.trim());
                    else if (line !== "" && part === "your") {
                        const f = line.split("\t");
                        if (f.length >= 3) yours.push({ source: f[0], id: f[1], name: f[2], version: f[3] || "" });
                    }
                }
                root.backends = b;
                root.installedPkgs = got;
                root.installedApps = yours;
            }
        }
    }
    // which backend this app is installed from, or ""
    function installedVia(a) {
        const pk = a.pacman || a.aur;
        if (pk && root.installedPkgs.pacman.indexOf(pk) >= 0) return a.pacman ? "Arch" : "AUR";
        if (a.flatpak && root.installedPkgs.flatpak.indexOf(a.flatpak) >= 0) return "Flatpak";
        if (a.snap && root.installedPkgs.snap.indexOf(a.snap) >= 0) return "Snap";
        return "";
    }
    // a command in a terminal, kept open at the end so its output can be read.
    // Started detached on purpose: the terminal is the user's own console --
    // it steps out of the shell's process tree (where the watchdog's
    // tripwire watches for privilege launches), and its password prompt is
    // typed by the person looking at it. Only flows that need a person at a
    // keyboard use this (yay's build, snap's confinement questions);
    // pacman goes through the root gate instead (gatePkg below).
    property bool terminalBusy: false
    Timer { id: busyClear; interval: 60000; onTriggered: root.terminalBusy = false }
    function anyBusy() { return root.terminalBusy || gatePkgProc.running }
    function inTerminal(cmd) {
        if (root.terminalBusy) return;
        const tail = cmd + '; echo; read -rp "Done. Press Enter to close " _';
        root.terminalBusy = true;
        busyClear.restart();
        Quickshell.execDetached(["sh", "-c",
            'if command -v kitty >/dev/null; then exec kitty sh -c "$1"; '
            + 'elif command -v foot >/dev/null; then exec foot sh -c "$1"; '
            + 'elif command -v alacritty >/dev/null; then exec alacritty -e sh -c "$1"; '
            + 'elif command -v ghostty >/dev/null; then exec ghostty -e sh -c "$1"; fi', "sh", tail]);
    }

    // A package through the root gate: the approval window decides (the page
    // names the command), pacman runs as root with the staged ids -- full
    // argv, --noconfirm, no shell -- and what it printed comes back here.
    // Only plain ids ever reach this (validated again on the root side).
    property Process gatePkgProc: Process {
        id: gatePkgProc
        stdout: StdioCollector { id: gateOut }
        stderr: StdioCollector { id: gateErr }
        onExited: (code) => {
            root.detectApps();
            if (root.section === "ai") root.loadAi();
            const denied = (gateOut.text || "").indexOf("denied") >= 0;
            const tail = ((gateErr.text || "") + (gateOut.text || "")).trim().slice(-300);
            Quickshell.execDetached(["notify-send", "-a", "Aequalyn",
                code === 0 ? "Package ready" : denied ? "Package action denied" : "Package action failed",
                code === 0 ? "pacman finished; the list on this page is refreshed."
                    : denied ? "The approval window was denied or timed out; nothing was installed."
                    : (tail || "pacman exited " + code)]);
        }
    }
    function gatePkg(op, id) {
        if (gatePkgProc.running) return;
        const req = JSON.stringify({ op: op, packages: [id] });
        gatePkgProc.command = ["sh", "-c",
            'mkdir -p "$HOME/.local/state/aequalyn/gate" && printf \'%s\' "$2" > "$HOME/.local/state/aequalyn/gate/pkg.json" '
            + '&& aequalyn-watchdog exec-root --as store "$1"; r=$?; rm -f "$HOME/.local/state/aequalyn/gate/pkg.json"; exit $r',
            "sh", op === "install" ? "pkg-install" : "pkg-remove", req];
        gatePkgProc.running = true;
    }
    readonly property string flathub: "flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo"
    // every app from every backend: aequalyn-store search-apps (no words: Flathub's most
    // installed, page by page, and Snap's featured)
    property var found: []
    property var foundErrors: ({})
    property string foundQuery: ""
    property int foundPage: 0
    property int flathubPages: 1
    property string foundSource: "All"
    property bool searching: false
    // the page of results shown at a time (foundAt: where it starts)
    property int foundAt: 0
    readonly property int foundStep: 15
    readonly property var appPool: root.foundSource === "Installed"
        ? root.installedResults
        : root.found.filter(r => root.foundSource === "All" || r.source === root.foundSource)
    readonly property var foundShown: root.appCategory === "all"
        ? root.appPool
        : root.appPool.filter(r => root.categoryForResult(r) === root.appCategory)
    function searchApps(q, more) {
        // Installed is a local view: filter what is already here, no network search
        if (root.foundSource === "Installed") {
            root.installedQuery = q;
            root.foundAt = 0;
            return;
        }
        if (searchProc.running) return;
        root.foundPage = more ? root.foundPage + 1 : 1;
        if (!more) { root.found = []; root.foundQuery = q; root.foundAt = 0; }
        root.searching = true;
        searchProc.command = ["aequalyn-store", "search-apps"].concat(q !== "" ? [q] : []).concat(["--page", String(root.foundPage)]);
        searchProc.running = true;
    }
    Process {
        id: searchProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.searching = false;
                try {
                    const d = JSON.parse(text);
                    root.found = root.found.concat(d.results);
                    root.foundErrors = d.errors || {};
                    root.flathubPages = d.flathubPages || 1;
                } catch (e) { root.foundErrors = { all: "the search failed" }; }
                // typing while a search was in flight: run the newest words
                if (root.queryActive && root.query.trim() !== root.foundQuery) titleSearchTimer.restart();
            }
        }
    }
    function foundInstalled(r) {
        if (r.source === "Arch" || r.source === "AUR") return root.installedPkgs.pacman.indexOf(r.id) >= 0;
        if (r.source === "Flatpak") return root.installedPkgs.flatpak.indexOf(r.id) >= 0;
        return root.installedPkgs.snap.indexOf(r.id) >= 0;
    }
    function installFound(r) {
        const a = r.source === "Arch" ? { pacman: r.id } : r.source === "AUR" ? { aur: r.id }
                : r.source === "Flatpak" ? { flatpak: r.id } : { snap: r.id, snapAsk: true };
        root.installApp(a, r.source);
    }
    function installApp(a, via) {
        // only plain package names ever reach the shell
        const name = a.pacman || a.aur || a.flatpak || a.snap || "";
        if (!/^[A-Za-z0-9@._+-]{1,128}$/.test(name)) return;
        if (via === "Snap" && a.snapAsk) {
            root.inTerminal("sudo snap install " + name + " || { echo; read -rp \"" + name + " asks for classic confinement: it can reach your whole system. Install it that way? [y/N] \" a; "
                            + "[ \"$a\" = y ] && sudo snap install " + name + " --classic; }");
            return;
        }
        // Arch packages ride the root gate: the approval window opens, the
        // password goes to sudo on a pipe, and pacman runs with the staged
        // id -- no terminal, no polkit, no side doors.
        if (via === "Arch") root.gatePkg("install", a.pacman);
        else if (via === "AUR") root.inTerminal("yay -S --needed " + a.aur);
        else if (via === "Flatpak") root.inTerminal(root.flathub + " && flatpak install --user -y flathub " + a.flatpak);
        else if (via === "Snap") root.inTerminal("sudo snap install " + a.snap + (a.snapClassic ? " --classic" : ""));
    }
    // Installed filter: the matching update or remove -- Arch through the
    // gate, the rest in the user's detached console. Only the plain id from
    // the package manager reaches the shell.
    function appAction(r, action) {
        const id = r.id;
        if (!/^[A-Za-z0-9@._+-]{1,128}$/.test(id)) return;
        if (r.source === "Arch")
            root.gatePkg(action === "update" ? "install" : "remove", id);
        else if (r.source === "AUR")
            root.inTerminal(action === "update" ? "yay -S --needed " + id : "yay -Rns " + id);
        else if (r.source === "Flatpak")
            root.inTerminal(action === "update" ? "flatpak update -y " + id : "flatpak uninstall -y " + id);
        else if (r.source === "Snap")
            root.inTerminal(action === "update" ? "sudo snap refresh " + id : "sudo snap remove " + id);
    }
    function installBackend(name) {
        if (name === "yay") root.inTerminal("sudo pacman -S --needed git base-devel && d=$(mktemp -d) && git clone https://aur.archlinux.org/yay-bin.git \"$d\" && cd \"$d\" && makepkg -si");
        else if (name === "flatpak") root.inTerminal("sudo pacman -S --needed flatpak && " + root.flathub);
        else if (name === "snap") root.inTerminal("yay -S --needed snapd && sudo systemctl enable --now snapd.socket && sudo ln -sfn /var/lib/snapd/snap /snap");
    }
    onOpenChanged: {
        if (open) { root.refresh(); root.freshMarket(); }
        if (open && section === "apps") detectApps();
        if (open && section === "web") loadWebapps();
        if (open && section === "ai") loadAi();
        if (open && section === "appimage") checkHandler();
        if (open && (section === "theme" || section === "wallpaper")) root.syncThemeRepo();
    }
    // ---- web apps: websites in their own window ----------------------------------------
    // aequalyn-webapp owns everything (the desktop entries, the Super + Shift
    // binds, ~/.config/aequalyn/webapps.json); this page shows what it holds and
    // runs it, the same way the rest of the Store runs aequalyn-store.
    property var webapps: []
    property var webBrowsers: []
    property var webCategories: []
    property string webBrowser: ""
    // the web app whose category is being changed, and the category being renamed
    property var categoryTarget: null
    property string renamingCategory: ""
    function setWebCategory(cat) {
        const app = root.categoryTarget;
        if (!app) return;
        root.categoryTarget = null;
        root.runCmd("Changing " + app.name,
                    ["aequalyn-webapp", "set-category", app.slug, cat || "none"]);
    }
    function renameWebCategory(id, label) {
        label = (label || "").trim();
        root.renamingCategory = "";
        if (id !== "" && label !== "")
            root.runCmd("Renaming category", ["aequalyn-webapp", "category-rename", id, label]);
    }
    // the web apps page: cards like the AppImages ones, five to a row, three rows
    // to a page; a plain list while they are few. The category chips above them
    // narrow the list to one of your own categories, or to those with none
    property int webPage: 0
    property string webFilter: "all"
    readonly property bool webHasUncategorised: root.webapps.some(a => !a.category)
    readonly property var webShown: root.webFilter === "all" ? root.webapps
        : root.webFilter === "none" ? root.webapps.filter(a => !a.category)
        : root.webapps.filter(a => a.category === root.webFilter)
    function setWebFilter(id) { root.webFilter = id; root.webPage = 0; }
    // a category filter keeps the same card grid even when only a few apps match
    readonly property bool webUseCards: root.webShown.length > 0 &&
        (root.webFilter !== "all" || root.webShown.length > 5)
    readonly property int webAt: Math.min(root.webPage, Math.max(0, Math.ceil(root.webShown.length / 15) - 1)) * 15
    function webRows() {
        const shown = root.webShown.slice(root.webAt, root.webAt + 15);
        const rows = [];
        for (let i = 0; i < shown.length; i += 5) rows.push(shown.slice(i, i + 5));
        while (rows.length < 3) rows.push([]);
        return rows;
    }
    function loadWebapps() {
        if (!webProc.running) webProc.running = true;
        if (!catProc.running) catProc.running = true;
    }
    Process {
        id: webProc
        command: ["aequalyn-webapp", "list", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text.trim());
                    root.webapps = j.apps || [];
                    root.webBrowsers = j.browsers || [];
                    root.webBrowser = j.browser || "auto";
                } catch (e) { root.webapps = []; }
            }
        }
    }
    // the user's own categories come from the same command the old settings page
    // used; the Store keeps them beside the apps so a category can be picked here
    Process {
        id: catProc
        command: ["aequalyn-webapp", "categories", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const cats = JSON.parse(text.trim()) || [];
                    root.webCategories = cats;
                    if (root.webFilter !== "all" && root.webFilter !== "none"
                        && !cats.some(c => c.id === root.webFilter)) root.webFilter = "all";
                } catch (e) { root.webCategories = []; }
            }
        }
    }

    // ---- ai tools: the coding agents ------------------------------------------------------
    // aequalyn-ai-tool installs, updates and removes them (their publisher's npm
    // package, Google's own installer for Antigravity); this page lists what it
    // knows and runs it.
    property var aiTools: []
    property string aiError: ""
    property int aiPage: 0
    property int aiAppPage: 0
    readonly property int aiPerPage: 15
    readonly property int aiAt: Math.min(root.aiPage, Math.max(0, Math.ceil(root.aiTools.length / root.aiPerPage) - 1)) * root.aiPerPage
    function aiRows() {
        const shown = root.aiTools.slice(root.aiAt, root.aiAt + root.aiPerPage);
        const rows = [];
        for (let i = 0; i < shown.length; i += 5) rows.push(shown.slice(i, i + 5));
        while (rows.length < 3) rows.push([]);
        return rows;
    }
    function loadAi() { root.aiError = ""; if (!aiProc.running) aiProc.running = true; }
    // a coding agent in a terminal: they are terminal programs. ~/.local/bin is
    // where Aequalyn links them, so it is added here in case this shell was not
    // started from the Hyprland session that puts it on PATH.
    function aiLaunch(command) {
        const q = "'" + String(command).replace(/'/g, "'\\''") + "'";
        const script = "export PATH=\"$HOME/.local/bin:$PATH\"; "
            + "if command -v xdg-terminal-exec >/dev/null 2>&1; then exec xdg-terminal-exec " + q
            + "; elif command -v kitty >/dev/null 2>&1; then exec kitty sh -lc " + q
            + "; elif command -v foot >/dev/null 2>&1; then exec foot sh -lc " + q
            + "; elif command -v alacritty >/dev/null 2>&1; then exec alacritty -e sh -lc " + q
            + "; elif command -v ghostty >/dev/null 2>&1; then exec ghostty -e sh -lc " + q
            + "; else echo 'No terminal emulator found.'; fi";
        Quickshell.execDetached(["sh", "-c", script]);
    }
    // a command in /usr/bin still has an owner: an Arch package or a system-wide
    // npm install. The tool CLI knows that owner and needs sudo, so give it a
    // terminal rather than running it in the Store's own process.
    function aiSystemAction(a, action) {
        const id = a.id || "";
        if (!/^[a-z]{1,32}$/.test(id) || (action !== "update" && action !== "remove")) return;
        root.inTerminal("aequalyn-ai-tool " + action + " " + id);
    }
    Process {
        id: aiProc
        command: ["aequalyn-ai-tool", "list", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.aiTools = JSON.parse(text.trim()); root.aiError = ""; }
                catch (e) { root.aiTools = []; root.aiError = "Could not read the AI tool list."; }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: { if (text.trim() !== "") root.aiError = text.trim(); }
        }
        onExited: code => {
            if (code !== 0 && root.aiError === "") root.aiError = "Could not read the AI tool list.";
        }
    }

    // ---- appimages: the Store as their default handler ---------------------------------
    // What the desktop sees: "ours" the Store is the default .AppImage opener,
    // "none" no default is set, "other" something else answers, "unknown" xdg-mime
    // is not there to ask.
    property string appimageHandler: "unknown"
    // the imported AppImages: a plain list while they are few, cards when they
    // grow (fifteen to a page, five to a row, ‹ › to walk the pages)
    readonly property var importedApps: root.itemsOf("appimage")
    property int importedPage: 0
    readonly property int importedPerPage: 15
    readonly property int importedAt: Math.min(root.importedPage, Math.max(0, Math.ceil(root.importedApps.length / root.importedPerPage) - 1)) * root.importedPerPage
    // the page's cards, as rows of five (a RowLayout gives each its fifth), the
    // page always holding its three rows -- what the page does not show is empty
    // rows, so the view keeps its shape and a short page sits its cards top-left
    function importedRows() {
        const shown = root.importedApps.slice(root.importedAt, root.importedAt + root.importedPerPage);
        const rows = [];
        for (let i = 0; i < shown.length; i += 5) rows.push(shown.slice(i, i + 5));
        while (rows.length < Math.ceil(root.importedPerPage / 5)) rows.push([]);
        return rows;
    }
    function checkHandler() { if (!mimeProc.running) mimeProc.running = true; }
    Process {
        id: mimeProc
        command: ["sh", "-c", 'command -v xdg-mime >/dev/null 2>&1 || exit 0; '
            + 'for m in application/vnd.appimage application/x-appimage application/x-iso9660-appimage; do '
            + 'xdg-mime query default "$m" 2>/dev/null; done']
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n").slice(0, 3);
                root.appimageHandler = l.length < 3 ? "unknown"
                    : l.every(x => x === "aequalyn-appimage.desktop") ? "ours"
                    : l.every(x => x === "") ? "none"
                    : "other";
            }
        }
    }
    // import what the field holds (an .AppImage a file manager handed over, or a
    // path typed in)
    function importField() {
        const file = appField.text.trim();
        if (file !== "") root.runJob("Importing " + file, ["import-appimage", file]);
    }
    // the picker, drawn inside this window: a layer-shell panel sits over every
    // normal window, so the desktop's own dialog opens beneath it and cannot be
    // seen. This one is part of the panel itself: folders walk in, an .AppImage
    // picked imports through the same checked job as the field below it.
    property bool pickOpen: false
    property string pickDir: ""
    property var pickEntries: []
    property bool pickBusy: false
    // one entry a NUL pair: "d" or "f", then the name (a space or a newline in a
    // name survives; a newline split would not)
    readonly property string pickLs: 'd="$1"; [ -d "$d" ] || d="$HOME"; cd "$d" || exit 0; '
        + 'for f in *; do [ -e "$f" ] || continue; '
        + 'if [ -d "$f" ]; then printf "d\\0%s\\0" "$f"; '
        + 'else case "$f" in *.AppImage|*.appimage) printf "f\\0%s\\0" "$f";; esac; fi; done'
    function pickBegin() {
        root.pickOpen = true;
        // where AppImages usually land, or the home when there is none
        root.pickNavigate(Quickshell.env("HOME") + "/Downloads");
    }
    function pickNavigate(dir) {
        if (pickListProc.running) return;
        root.pickDir = dir;
        root.pickEntries = [];
        root.pickBusy = true;
        pickListProc.command = ["sh", "-c", root.pickLs, "sh", dir];
        pickListProc.running = true;
    }
    function pickChild(name) { return (root.pickDir === "/" ? "" : root.pickDir) + "/" + name; }
    function pickUp() {
        const d = root.pickDir.replace(/\/+$/, "");
        const i = d.lastIndexOf("/");
        root.pickNavigate(i <= 0 ? "/" : d.slice(0, i));
    }
    Process {
        id: pickListProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.pickBusy = false;
                const parts = text.split("\0");
                const out = [];
                for (let i = 0; i + 1 < parts.length; i += 2)
                    if (parts[i] === "d" || parts[i] === "f")
                        out.push({ dir: parts[i] === "d", name: parts[i + 1] });
                // folders first, then AppImages, both in plain sight order
                out.sort((a, b) => (b.dir ? 1 : 0) - (a.dir ? 1 : 0) || a.name.localeCompare(b.name));
                root.pickEntries = out;
            }
        }
    }
    onSectionChanged: {
        if (section !== "web") { root.categoryTarget = null; root.renamingCategory = ""; }
        if (open && section !== "market") root.freshMarket();
        if (section === "market") { loadMarket(); if (!busy) runJob("Refreshing the catalog", ["refresh"]); }
        if (section === "apps") { root.appCategory = "all"; detectApps(); if (root.foundPage === 0) searchApps("", false); }
        if (section === "web") loadWebapps();
        if (section === "ai") { detectApps(); loadAi(); }
        if (section === "appimage") checkHandler();
        if (section === "theme" || section === "wallpaper") root.syncThemeRepo();
        pageIn.restart();
    }

    // ---- one job at a time, its report live -------------------------------------------
    property bool busy: false
    property string jobTitle: ""
    property int jobCode: -1
    property var jobArgs: []
    ListModel { id: logModel }
    function runJob(title, args) {
        root.jobArgs = args;
        root.runCmd(title, ["aequalyn-store"].concat(args));
    }
    // one job at a time over any of this window's commands -- the engine, the web
    // app tool, the ai tool -- all into the same live report
    function runCmd(title, cmd) {
        if (root.busy) return;
        logModel.clear();
        root.jobTitle = title;
        root.jobCode = -1;
        root.busy = true;
        job.command = cmd;
        job.running = true;
    }
    Process {
        id: job
        stdout: SplitParser { onRead: line => logModel.append({ line: line }) }
        stderr: SplitParser { onRead: line => logModel.append({ line: line }) }
        onExited: code => {
            root.busy = false;
            root.jobCode = code;
            root.refresh();
            root.loadMarket();
            UserPlugins.rescan();
            if (root.section === "web") root.loadWebapps();
            if (root.section === "ai") root.loadAi();
            if (root.section === "appimage") root.checkHandler();
            if (root.section === "theme" && !themeCatalogProc.running) themeCatalogProc.running = true;
            if (root.section === "wallpaper" && !wallpaperCatalogProc.running) wallpaperCatalogProc.running = true;
            // a fresh import lands on the last page: show it where it arrives
            if (root.section === "appimage" && root.jobArgs[0] === "import-appimage") root.importedPage = 99;
        }
    }
    Process { id: side }
    function runSide(cmd) { side.command = cmd; side.running = true; }

    // ---- IPC ----------------------------------------------------------------------------
    IpcHandler {
        target: "store"
        function open(): void { root.open = true; root.refresh(); }
        function close(): void { root.open = false; }
        function toggle(): void { root.open = !root.open; if (root.open) root.refresh(); }
        // open on a section: home, plugin, theme, cursor, wallpaper, look,
        // apps, web, ai, appimage, market, updates
        function section(name: string): string {
            const section = name;
            if (!root.sections.some(s => s.key === section)) return "no section " + section;
            root.openSection(section); root.open = true; root.refresh(); return "ok";
        }
        // look through apps and settings, as the title bar does
        function search(words: string): void {
            root.openSection("apps"); root.open = true; root.setQuerySource("All"); root.query = words;
        }
        // an .AppImage opened in a file manager (the handler's menu entry runs
        // aequalyn-store open-appimage): this page, its import form filled in and
        // the file already checked, so Enter (or Import) is all that is left
        function appimage(path: string): string {
            root.openSection("appimage"); root.open = true; root.refresh();
            appField.text = path;
            root.runJob("Checking " + path, ["check-appimage", path]);
            return "ok";
        }
        // install from a git URL (or a folder), with every check first
        function install(kind: string, source: string): string {
            if (!root.kindWords[kind]) return "no kind " + kind;
            root.openSection(kind); root.open = true;
            root.runJob("Installing " + source, ["install", kind, source]);
            return "ok";
        }
        // one package, by source name: the same validated path a Store card uses.
        // Arch goes through the approval gate; the others run in a terminal.
        function package(source: string, name: string): string {
            const via = ({ arch: "Arch", aur: "AUR", flatpak: "Flatpak", snap: "Snap" })[String(source).toLowerCase()];
            if (!via) return "no source " + source;
            if (!/^[A-Za-z0-9@._+-]{1,128}$/.test(name)) return "bad package " + name;
            const a = {};
            if (via === "Arch") a.pacman = name;
            else if (via === "AUR") a.aur = name;
            else if (via === "Flatpak") a.flatpak = name;
            else a.snap = name;
            root.installApp(a, via);
            return "ok";
        }
        // the other half of a curated choice: remove the same plain package id
        // through the same gated/terminal path the Installed page uses
        function remove(source: string, name: string): string {
            const via = ({ arch: "Arch", aur: "AUR", flatpak: "Flatpak", snap: "Snap" })[String(source).toLowerCase()];
            if (!via) return "no source " + source;
            if (!/^[A-Za-z0-9@._+-]{1,128}$/.test(name)) return "bad package " + name;
            root.appAction({ source: via, id: name }, "remove");
            return "ok";
        }
    }

    // ---- small parts --------------------------------------------------------------------
    // A button, as everywhere in Aequalyn: quiet, a hairline edge; `primary` (the main
    // one) in the accent's edge on a lifted fill, `danger` red when you point at it.
    component Btn: Rectangle {
        id: btn
        property string text: ""
        property string icon: ""
        property bool primary: false
        property bool danger: false
        signal clicked()
        implicitHeight: 24
        implicitWidth: row.implicitWidth + 16
        radius: 6
        color: primary ? root.theme.accentPrimary
             : danger && ma.containsMouse ? Cc.alpha(root.theme.accentRed, 0.10)
             : ma.containsMouse ? Cc.alpha(root.theme.textPrimary, 0.12)
             : Cc.alpha(root.theme.textPrimary, 0.05)
        border.width: !primary && danger ? 1 : 0
        border.color: root.theme.accentRed
        opacity: enabled ? 1 : 0.4
        Behavior on color { ColorAnimation { duration: 90 } }
        Accessible.role: Accessible.Button
        Accessible.name: text
        readonly property color ink: primary ? root.theme.bgBase
                       : danger && ma.containsMouse ? root.theme.accentRed : root.theme.textPrimary
        Row {
            id: row
            anchors.centerIn: parent
            spacing: 5
            Text { visible: btn.icon !== ""; text: btn.icon; color: btn.ink; font.family: root.mono; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
            Text { visible: btn.text !== ""; text: btn.text; color: btn.ink; opacity: btn.primary ? 1 : 0.85; font.family: root.sans; font.pixelSize: 11; font.weight: btn.primary ? Font.DemiBold : Font.Normal; anchors.verticalCenter: parent.verticalCenter }
        }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: btn.clicked() }
    }
    // A one-line text field, looking like the rest of the shell.
    component Field: Rectangle {
        id: fld
        property alias text: input.text
        property string placeholder: ""
        signal accepted()
        function forceInput() { input.forceActiveFocus() }
        Layout.fillWidth: true
        implicitHeight: 34
        radius: 6
        color: Cc.alpha(root.theme.textPrimary, 0.05)
        border.width: 1
        border.color: Cc.alpha(root.theme.textPrimary, input.activeFocus ? 0.28 : 0.08)
        Behavior on border.color { ColorAnimation { duration: 90 } }
        MouseArea { anchors.fill: parent; onClicked: input.forceActiveFocus() }
        TextInput {
            id: input
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 10
            verticalAlignment: TextInput.AlignVCenter
            color: root.theme.textPrimary
            selectionColor: root.theme.accentPrimary
            selectedTextColor: root.theme.bgBase
            font.family: root.sans
            font.pixelSize: 12
            clip: true
            selectByMouse: true
            onAccepted: fld.accepted()
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: input.text === "" && !input.activeFocus
                text: fld.placeholder
                color: root.theme.textMuted
                font: input.font
            }
        }
    }
    // A question and what answers it, as every control center page lays one out: a
    // short title, an optional hint, then the content in one rounded group.
    component Box: ColumnLayout {
        id: box
        default property alias content: body.data
        property string title: ""
        property string hint: ""
        Layout.fillWidth: true
        spacing: 6
        Text {
            visible: box.title !== ""
            text: box.title.toUpperCase()
            color: root.theme.textSecondary
            font.family: root.sans
            font.pixelSize: 9
            font.weight: Font.DemiBold
            font.letterSpacing: 1
            opacity: 0.45
            Layout.fillWidth: true
            Layout.leftMargin: 2
        }
        Text {
            visible: box.hint !== ""
            text: box.hint
            color: root.theme.textMuted
            font.family: root.sans
            font.pixelSize: 10
            wrapMode: Text.WordWrap
            opacity: 0.55
            Layout.fillWidth: true
            Layout.leftMargin: 2
            Layout.topMargin: -4
        }
        // the group: the quiet framed group a control center page uses
        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 2
            implicitHeight: body.implicitHeight + 8
            radius: 6
            color: Cc.alpha(root.theme.textPrimary, 0.03)
            border.width: 1
            border.color: Cc.alpha(root.theme.textPrimary, 0.08)
            ColumnLayout {
                id: body
                x: 4
                y: 4
                width: parent.width - 8
                spacing: 6
            }
        }
    }
    component Pill: Rectangle {
        property string text: ""
        property color tone: root.theme.accentGreen
        implicitWidth: pt.implicitWidth + 16
        implicitHeight: 20
        radius: 4
        color: Cc.alpha(tone, 0.14)
        Text { id: pt; anchors.centerIn: parent; text: parent.text; color: parent.tone; font.family: root.mono; font.pixelSize: 10; font.weight: Font.DemiBold }
    }

    // ‹ and ›, as the control center steps its choices
    component StepBtn: Rectangle {
        id: sb
        property string glyph: ""
        signal clicked()
        Layout.preferredWidth: 24
        Layout.preferredHeight: 24
        radius: 6
        color: Cc.alpha(root.theme.textPrimary, sbMa.containsMouse ? 0.12 : 0.06)
        border.width: 0
        Accessible.role: Accessible.Button
        Text { anchors.centerIn: parent; text: sb.glyph; color: root.theme.textSecondary; font.family: root.mono; font.pixelSize: 14 }
        MouseArea { id: sbMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: sb.clicked() }
    }

    // One app tile, shared by All Apps and every category page. It keeps the
    // All Apps look: quiet fill, icon, name, source, and actions in the tile.
    component BrowseCard: Rectangle {
        id: bcard
        required property var modelData
        readonly property bool have: root.foundInstalled(modelData)
        readonly property bool hovered: bcardMa.containsMouse
        readonly property bool installedHere: !!modelData.installed
        readonly property bool ready: modelData.source === "Arch"
            || (modelData.source === "AUR" && root.backends.yay)
            || (modelData.source === "Flatpak" && root.backends.flatpak)
            || (modelData.source === "Snap" && root.backends.snap)
        readonly property string iconUrl: root.appIconUrl(modelData.icon, modelData.name || modelData.id)
        readonly property string initials: root.appInitials(modelData.name || modelData.id)
        readonly property color monogramColor: root.appMonogramColor(modelData.name || modelData.id)
        signal opened()
        Layout.fillWidth: true
        Layout.preferredWidth: 203
        height: 150
        radius: 6
        color: hovered ? Cc.alpha(root.theme.textPrimary, 0.10)
            : Cc.alpha(root.theme.textPrimary, 0.03)
        border.width: 1
        border.color: Cc.alpha(root.theme.textPrimary, 0.08)
        MouseArea {
            id: bcardMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: bcard.opened()
        }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 6
            RowLayout {
                spacing: 8
                Item {
                    Layout.preferredWidth: 30; Layout.preferredHeight: 30
                    Image {
                        id: bicon
                        anchors.fill: parent
                        source: bcard.iconUrl
                        sourceSize.width: 64; sourceSize.height: 64
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        visible: status === Image.Ready
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: 8
                        color: bcard.monogramColor
                        visible: !bicon.visible
                        Text {
                            anchors.centerIn: parent
                            text: bcard.initials
                            color: "#ffffff"
                            font.family: root.sans
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                    }
                }
                ColumnLayout {
                    spacing: 1
                    Layout.fillWidth: true
                    Text {
                        text: bcard.modelData.name
                        color: root.theme.textPrimary; font.family: root.sans; font.pixelSize: 12; font.weight: Font.DemiBold
                        elide: Text.ElideRight; Layout.fillWidth: true
                    }
                    Text {
                        text: bcard.modelData.source === "Flatpak" ? "Flathub" : bcard.modelData.source
                        color: root.theme.textMuted; font.family: root.mono; font.pixelSize: 10
                        elide: Text.ElideRight; Layout.fillWidth: true
                    }
                }
            }
            Text {
                text: bcard.modelData.about
                color: root.theme.textSecondary; font.family: root.sans; font.pixelSize: 11
                wrapMode: Text.WordWrap; elide: Text.ElideRight
                maximumLineCount: 2; Layout.fillWidth: true
            }
            Item { Layout.fillHeight: true }
            ColumnLayout {
                visible: bcard.installedHere
                Layout.fillWidth: true
                spacing: 4
                Pill { text: "Installed"; tone: root.theme.accentGreen }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Btn {
                        Layout.fillWidth: true
                        implicitHeight: 26
                        text: "Update"
                        primary: true
                        enabled: !root.anyBusy()
                        onClicked: root.appAction(bcard.modelData, "update")
                    }
                    Btn {
                        Layout.fillWidth: true
                        implicitHeight: 26
                        text: "Remove"
                        danger: true
                        enabled: !root.anyBusy()
                        onClicked: root.appAction(bcard.modelData, "remove")
                    }
                }
            }
            RowLayout {
                visible: !bcard.installedHere
                Layout.fillWidth: true
                spacing: 6
                Pill { visible: bcard.have; text: "Installed"; tone: root.theme.accentGreen }
                Item { Layout.fillWidth: true }
                Btn {
                    visible: !bcard.have
                    implicitHeight: 26
                    text: bcard.ready ? "Install" : "Needs " + (bcard.modelData.source === "AUR" ? "the AUR" : bcard.modelData.source === "Flatpak" ? "Flathub" : "Snap")
                    primary: bcard.ready
                    enabled: bcard.ready && !root.anyBusy()
                    onClicked: root.installFound(bcard.modelData)
                }
            }
        }
    }

    // The same 5x3 grid and page controls wherever apps are listed. Category
    // pages own their page number; All Apps follows its own search paging.
    component BrowseCards: ColumnLayout {
        id: grid
        property var model: []
        property int page: 0
        signal goToPage(int value)
        readonly property int count: (grid.model || []).length
        readonly property int step: 15
        readonly property int at: Math.min(Math.max(0, grid.page),
            Math.max(0, Math.ceil(grid.count / grid.step) - 1)) * grid.step
        readonly property var rows: {
            const shown = (grid.model || []).slice(grid.at, grid.at + grid.step);
            const out = [];
            for (let i = 0; i < shown.length; i += 5) out.push(shown.slice(i, i + 5));
            while (out.length < 3) out.push([]);
            return out;
        }
        Layout.fillWidth: true
        spacing: 10
        Repeater {
            model: grid.rows
            delegate: RowLayout {
                id: cardRow
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredHeight: 150
                spacing: 10
                Repeater {
                    model: cardRow.modelData
                    delegate: BrowseCard {
                        onOpened: {
                            const g = root.groupFor(modelData);
                            if (g) root.openApp(g);
                        }
                    }
                }
                Repeater {
                    model: 5 - cardRow.modelData.length
                    delegate: Item { Layout.fillWidth: true; Layout.preferredWidth: 203 }
                }
            }
        }
        RowLayout {
            visible: grid.count > grid.step
            spacing: 6
            Item { Layout.fillWidth: true }
            Text {
                text: grid.count + (grid.count === 1 ? " app" : " apps")
                color: root.theme.textMuted; font.family: root.mono; font.pixelSize: 11
            }
            StepBtn {
                glyph: "\u2039"
                enabled: grid.at > 0
                onClicked: grid.goToPage(grid.at / grid.step - 1)
            }
            Text {
                text: (grid.at + 1) + "–" + Math.min(grid.at + grid.step, grid.count) + " of " + grid.count
                color: root.theme.textMuted; font.family: root.mono; font.pixelSize: 11
            }
            StepBtn {
                glyph: "\u203A"
                enabled: grid.at + grid.step < grid.count
                onClicked: grid.goToPage(grid.at / grid.step + 1)
            }
        }
    }

    // The Popular apps tile, shared with category pages. Four source buttons sit
    // in the card; a click on the card itself opens that app's own page.
    component AppTile: Rectangle {
        id: tile
        required property var modelData
        readonly property string via: root.installedVia(modelData)
        readonly property bool hovered: tileMa.containsMouse
        readonly property string iconUrl: root.appIconUrl(modelData.icon, modelData.name || modelData.id)
        readonly property string initials: root.appInitials(modelData.name || modelData.id)
        readonly property color monogramColor: root.appMonogramColor(modelData.name || modelData.id)
        signal opened()
        Layout.fillWidth: true
        Layout.preferredWidth: 203
        height: 164
        radius: 6
        color: hovered ? Cc.alpha(root.theme.textPrimary, 0.10)
            : Cc.alpha(root.theme.textPrimary, 0.03)
        border.width: 1
        border.color: Cc.alpha(root.theme.textPrimary, 0.08)
        MouseArea {
            id: tileMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.opened()
        }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 6
            RowLayout {
                spacing: 10
                Item {
                    Layout.preferredWidth: 34; Layout.preferredHeight: 34
                    Image {
                        id: tileIcon
                        anchors.centerIn: parent
                        width: 34; height: 34
                        source: tile.iconUrl
                        sourceSize.width: 64; sourceSize.height: 64
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        smooth: true
                        visible: tile.iconUrl !== "" && status === Image.Ready
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: 34; height: 34
                        radius: 8
                        color: tile.monogramColor
                        visible: !tileIcon.visible
                        Text {
                            anchors.centerIn: parent
                            text: tile.initials
                            color: "#ffffff"
                            font.family: root.sans
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }
                    }
                }
                ColumnLayout {
                    spacing: 1
                    Layout.fillWidth: true
                    Text {
                        text: tile.modelData.name
                        color: root.theme.textPrimary; font.family: root.sans
                        font.pixelSize: 13; font.weight: Font.DemiBold
                        elide: Text.ElideRight; Layout.fillWidth: true
                    }
                    Pill { visible: tile.via !== ""; text: "Installed · " + tile.via; tone: root.theme.accentGreen }
                }
            }
            Text {
                text: tile.modelData.about || ""
                color: root.theme.textSecondary; font.family: root.sans; font.pixelSize: 11
                wrapMode: Text.WordWrap; elide: Text.ElideRight
                maximumLineCount: 2; Layout.fillWidth: true
            }
            Item { Layout.fillHeight: true }
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                rows: 2
                flow: GridLayout.LeftToRight
                columnSpacing: 4
                rowSpacing: 4
                Repeater {
                    model: [
                        { via: "Arch", has: !!tile.modelData.pacman, ready: true },
                        { via: "AUR", has: !!tile.modelData.aur, ready: root.backends.yay === true },
                        { via: "Flatpak", has: !!tile.modelData.flatpak, ready: root.backends.flatpak === true },
                        { via: "Snap", has: !!tile.modelData.snap, ready: root.backends.snap === true }
                    ]
                    delegate: Btn {
                        required property var modelData
                        text: modelData.via
                        Layout.fillWidth: true
                        Layout.preferredWidth: 0
                        Layout.minimumWidth: 0
                        Layout.preferredHeight: 24
                        primary: modelData.has && modelData.ready && tile.via === ""
                        enabled: modelData.has && modelData.ready && !root.anyBusy()
                        onClicked: root.installFound({
                            source: modelData.via,
                            id: modelData.via === "Arch" ? tile.modelData.pacman
                                : modelData.via === "AUR" ? tile.modelData.aur
                                : modelData.via === "Flatpak" ? tile.modelData.flatpak
                                : tile.modelData.snap
                        })
                    }
                }
            }
        }
    }

    // Five tiles to a row, fifteen to a page, with the same page controls the
    // rest of the Store uses. `limit` caps a category at 30 apps across two
    // pages; Popular apps keep their whole catalog.
    component SourceCards: ColumnLayout {
        id: sourceGrid
        property var model: []
        property int page: 0
        // 0 means no cap: the Popular grid keeps paging through every app.
        property int limit: 0
        signal goToPage(int value)
        readonly property var items: sourceGrid.limit > 0
            ? (sourceGrid.model || []).slice(0, sourceGrid.limit) : (sourceGrid.model || [])
        readonly property int count: sourceGrid.items.length
        readonly property int step: 15
        readonly property int at: Math.min(Math.max(0, sourceGrid.page),
            Math.max(0, Math.ceil(sourceGrid.count / sourceGrid.step) - 1)) * sourceGrid.step
        readonly property var rows: {
            const shown = sourceGrid.items.slice(sourceGrid.at, sourceGrid.at + sourceGrid.step);
            const out = [];
            for (let i = 0; i < shown.length; i += 5) out.push(shown.slice(i, i + 5));
            while (out.length < 3) out.push([]);
            return out;
        }
        Layout.fillWidth: true
        spacing: 10
        Repeater {
            model: sourceGrid.rows
            delegate: RowLayout {
                id: sourceRow
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredHeight: 164
                spacing: 10
                Repeater {
                    model: sourceRow.modelData
                    delegate: AppTile {
                        onOpened: {
                            const g = root.groupFor(modelData);
                            if (g) root.openApp(g);
                        }
                    }
                }
                Repeater {
                    model: 5 - sourceRow.modelData.length
                    delegate: Item { Layout.fillWidth: true; Layout.preferredWidth: 203 }
                }
            }
        }
        RowLayout {
            visible: sourceGrid.count > sourceGrid.step
            spacing: 6
            Item { Layout.fillWidth: true }
            Text {
                text: sourceGrid.count + (sourceGrid.count === 1 ? " app" : " apps")
                color: root.theme.textMuted; font.family: root.mono; font.pixelSize: 11
            }
            StepBtn {
                glyph: "\u2039"
                enabled: sourceGrid.at > 0
                onClicked: sourceGrid.goToPage(sourceGrid.at / sourceGrid.step - 1)
            }
            Text {
                text: (sourceGrid.at + 1) + "–" + Math.min(sourceGrid.at + sourceGrid.step, sourceGrid.count) + " of " + sourceGrid.count
                color: root.theme.textMuted; font.family: root.mono; font.pixelSize: 11
            }
            StepBtn {
                glyph: "\u203A"
                enabled: sourceGrid.at + sourceGrid.step < sourceGrid.count
                onClicked: sourceGrid.goToPage(sourceGrid.at / sourceGrid.step + 1)
            }
        }
    }

    // one card: an imported AppImage or a web app -- its icon, its name, and what
    // its page does with it (Open and Remove come back as signals, the card never
    // runs anything itself)
    component AppCard: Rectangle {
        id: card
        required property var modelData
        // laid out by its row: no width of its own (a fixed one made the layouts
        // treat a lone card as the whole row); every slot of the row carries the
        // same preferred width, so all fifths come out equal
        height: 150
        readonly property bool isWeb: modelData.slug !== undefined
        readonly property string iconPath: card.isWeb ? (modelData.iconFile || "") : (modelData.icon || "")
        readonly property string label: modelData.label || modelData.name || modelData.id
        readonly property string iconUrl: root.localAppIcon(card.iconPath, card.label)
        readonly property string initials: root.appInitials(card.label)
        readonly property color monogramColor: root.appMonogramColor(card.label)
        readonly property bool canOpen: card.isWeb ? !!modelData.slug : !!modelData.path
        signal openRequested()
        signal removeRequested()
        signal categoryRequested()
        radius: 6
        color: root.theme.bgBase
        border.width: 1
        border.color: root.theme.bgBorder
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 6
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                Image {
                    id: cardIcon
                    anchors.centerIn: parent
                    width: 56; height: 56
                    source: card.iconUrl
                    sourceSize.width: 112; sourceSize.height: 112
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                    visible: status === Image.Ready
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 56; height: 56
                    radius: 12
                    color: card.monogramColor
                    visible: !cardIcon.visible
                    Text {
                        anchors.centerIn: parent
                        text: card.initials
                        color: "#ffffff"
                        font.family: root.sans
                        font.pixelSize: 19
                        font.weight: Font.DemiBold
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                text: card.label
                color: root.theme.textPrimary
                font.family: root.sans; font.pixelSize: 12; font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideMiddle
            }
            Item { Layout.fillHeight: true }
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Btn {
                    Layout.fillWidth: true
                    implicitHeight: 30
                    text: "Open"
                    primary: true
                    enabled: card.canOpen
                    onClicked: card.openRequested()
                }
                Btn {
                    Layout.fillWidth: true
                    implicitHeight: 30
                    text: "Remove"
                    danger: true
                    enabled: !root.busy
                    onClicked: card.removeRequested()
                }
                Btn {
                    visible: card.isWeb
                    Layout.fillWidth: true
                    implicitHeight: 30
                    text: "Cat"
                    enabled: !root.busy
                    onClicked: card.categoryRequested()
                }
            }
        }
    }

    // One AI tool, dressed like every other app tile: quiet fill, icon, name,
    // two lines of detail, a state pill and compact actions. The lifecycle is
    // still the tool's own, so update and remove stay with Open and Install.
    component AiCard: Rectangle {
        id: card
        required property var modelData
        readonly property bool installedHere: !!modelData.installed
        readonly property bool elsewhere: !!modelData.availableElsewhere
        readonly property bool systemManaged: !installedHere && !!modelData.systemManager
        readonly property bool conflict: !!modelData.launcherConflict
        readonly property string label: modelData.name || modelData.id || ""
        readonly property string stateText: installedHere
            ? "Installed · " + (modelData.version || modelData.command)
            : systemManaged ? "System · " + (modelData.systemId || modelData.availablePath)
            : elsewhere ? "Available · " + (modelData.availablePath || modelData.command)
            : conflict ? "Command in use" : "Not installed"
        readonly property color stateTone: installedHere ? root.theme.accentGreen
            : elsewhere ? root.theme.accentPrimary
            : conflict ? root.theme.accentOrange : root.theme.textMuted
        readonly property bool hovered: aiMa.containsMouse
        readonly property string iconUrl: root.aiIconUrl(modelData)
        readonly property string initials: root.appInitials(card.label)
        readonly property color monogramColor: root.appMonogramColor(card.label)
        signal opened()
        signal openRequested()
        signal installRequested()
        signal updateRequested()
        signal removeRequested()
        height: 150
        radius: 6
        color: hovered ? Cc.alpha(root.theme.textPrimary, 0.10)
            : Cc.alpha(root.theme.textPrimary, 0.03)
        border.width: 1
        border.color: Cc.alpha(root.theme.textPrimary, 0.08)
        MouseArea {
            id: aiMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: card.opened()
        }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 4
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Item {
                    Layout.preferredWidth: 30; Layout.preferredHeight: 30
                    Image {
                        id: aiIcon
                        anchors.fill: parent
                        source: card.iconUrl
                        sourceSize.width: 64; sourceSize.height: 64
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        smooth: true
                        visible: status === Image.Ready
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: 8
                        color: card.monogramColor
                        visible: !aiIcon.visible
                        Text {
                            anchors.centerIn: parent
                            text: card.initials
                            color: "#ffffff"
                            font.family: root.sans
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        text: card.label
                        color: root.theme.textPrimary
                        font.family: root.sans
                        font.pixelSize: 12; font.weight: Font.DemiBold
                        elide: Text.ElideRight; Layout.fillWidth: true
                    }
                    Text {
                        text: card.stateText
                        color: card.stateTone
                        font.family: root.mono
                        font.pixelSize: 10
                        elide: Text.ElideRight; Layout.fillWidth: true
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                text: root.aiMeta(modelData).about || modelData.description || ""
                color: root.theme.textSecondary
                font.family: root.sans
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                elide: Text.ElideRight
                maximumLineCount: 2
            }
            Item { Layout.fillHeight: true }
            Btn {
                Layout.fillWidth: true
                implicitHeight: 26
                text: card.installedHere || card.elsewhere ? "Open"
                    : card.conflict ? "In use" : "Install"
                primary: card.installedHere || card.elsewhere || !card.conflict
                enabled: !root.busy && (card.installedHere || card.elsewhere || !card.conflict)
                onClicked: {
                    if (card.installedHere || card.elsewhere) card.openRequested();
                    else if (!card.conflict) card.installRequested();
                }
            }
            RowLayout {
                visible: card.installedHere || card.systemManaged
                Layout.fillWidth: true
                spacing: 6
                Btn {
                    Layout.fillWidth: true
                    implicitHeight: 26
                    text: "Update"
                    enabled: !root.busy
                    onClicked: card.updateRequested()
                }
                Btn {
                    Layout.fillWidth: true
                    implicitHeight: 26
                    text: "Remove"
                    danger: true
                    enabled: !root.busy
                    onClicked: card.removeRequested()
                }
            }
        }
    }

    // one installed item: its name, where it came from, its state and its actions.
    // Rows sit together as the control center's rows do: on the group's colour, a
    // hairline between them, no card of their own.
    component ItemRow: ColumnLayout {
        id: row
        required property var modelData
        required property int index
        readonly property string kind: modelData.kind
        readonly property string label: modelData.label || modelData.name || modelData.id || ""
        readonly property string appIcon: row.kind === "appimage" ? root.localAppIcon(modelData.icon, row.label) : ""
        readonly property string initials: root.appInitials(row.label)
        readonly property color monogramColor: root.appMonogramColor(row.label)
        readonly property bool pluginOn: kind === "plugin" && (AequalynSettings.enabledPlugins || []).indexOf(modelData.id) >= 0
        Layout.fillWidth: true
        spacing: 0
        Rectangle { visible: row.index > 0; Layout.fillWidth: true; Layout.preferredHeight: 1; color: root.theme.bgBorder }
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            Layout.topMargin: 9
            Layout.bottomMargin: 9
            spacing: 10
            // the app's own icon beside its name (an imported AppImage always
            // carries one), or the kind's glyph for the rest
            Item {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                Image {
                    id: rowIcon
                    anchors.fill: parent
                    visible: row.kind === "appimage" && status === Image.Ready
                    source: row.appIcon
                    sourceSize.width: 64
                    sourceSize.height: 64
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                }
                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: row.monogramColor
                    visible: row.kind === "appimage" && !rowIcon.visible
                    Text {
                        anchors.centerIn: parent
                        text: row.initials
                        color: "#ffffff"
                        font.family: root.sans
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }
                }
                Text {
                    anchors.centerIn: parent
                    visible: row.kind !== "appimage"
                    text: (root.sections.find(s => s.key === row.kind) || {}).glyph || "\u{F01D4}"
                    color: root.theme.accentPrimary
                    font.family: root.mono
                    font.pixelSize: 16
                }
            }
            ColumnLayout {
                spacing: 3
                Layout.fillWidth: true
                RowLayout {
                    spacing: 8
                    Layout.fillWidth: true
                    Text { text: row.modelData.label || row.modelData.id; color: root.theme.textPrimary; font.family: root.sans; font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
                    Pill { visible: row.kind === "plugin"; text: row.pluginOn ? "Active" : "Inactive"; tone: row.pluginOn ? root.theme.accentGreen : root.theme.textMuted }
                    Pill { visible: row.kind === "appimage"; text: "AppImage"; tone: root.theme.accentPrimary }
                    Pill { visible: row.modelData.present === false; text: "Missing"; tone: root.theme.accentRed }
                    Item { Layout.fillWidth: true }
                }
                Text {
                    text: (row.modelData.version ? "v" + row.modelData.version + "  ·  " : "")
                        + (row.modelData.commit ? row.modelData.commit.slice(0, 12) + "  ·  " : "")
                        + (row.modelData.source || "")
                    color: root.theme.textMuted; font.family: root.mono; font.pixelSize: 11
                    elide: Text.ElideMiddle; Layout.fillWidth: true
                }
                // a look: wear one piece of it
                Flow {
                    visible: row.kind === "look" && (row.modelData.pieces || []).length > 0
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: row.modelData.pieces || []
                        delegate: Btn {
                            required property string modelData
                            implicitHeight: 26
                            text: (root.pieceWords[modelData] || modelData)
                            enabled: !root.busy
                            onClicked: root.runJob("Wearing the " + (root.pieceWords[modelData] || modelData).toLowerCase()
                                                   + " of " + row.modelData.id, ["apply-look", row.modelData.id, "--piece", modelData])
                        }
                    }
                }
            }
            Btn {
                visible: row.kind === "plugin"
                text: row.pluginOn ? "Deactivate" : "Activate"
                onClicked: AequalynSettings.togglePlugin(row.modelData.id, !row.pluginOn)
            }
            Btn {
                visible: row.kind === "theme"
                text: "Apply"
                primary: true
                onClicked: root.runSide(["qs", "ipc", "call", "theme", "set", row.modelData.id])
            }
            Btn {
                visible: row.kind === "cursor"
                text: "Wear"
                primary: true
                onClicked: root.runSide(["sh", "-c", 'hyprctl setcursor "$1" 24 && gsettings set org.gnome.desktop.interface cursor-theme "$1"', "sh", row.modelData.id])
            }
            Btn {
                visible: row.kind === "look"
                text: "Wear all"
                primary: true
                enabled: !root.busy
                onClicked: root.runJob("Wearing " + (row.modelData.label || row.modelData.id), ["apply-look", row.modelData.id])
            }
            Btn {
                visible: row.kind === "appimage"
                text: "Launch"
                primary: true
                enabled: !!row.modelData.path
                onClicked: Quickshell.execDetached([row.modelData.path])
            }
            Btn {
                visible: row.kind !== "appimage"
                text: "Update"
                enabled: !root.busy
                onClicked: root.runJob("Updating " + row.modelData.id, ["update", row.kind, row.modelData.id])
            }
            Btn {
                text: "Remove"
                danger: true
                enabled: !root.busy
                onClicked: root.runJob("Removing " + row.modelData.id, ["remove", row.kind, row.modelData.id])
            }
        }
    }

    // the preview area shared by every Get card: a still image, or a cached
    // first frame for video, with the glyph until one is ready
    component CardPreview: Rectangle {
        id: pv
        required property string preview
        required property string icon
        readonly property bool remote: /^[a-zA-Z][a-zA-Z0-9+.-]*:/.test(pv.preview)
        readonly property string source: {
            if (pv.preview === "") return "";
            if (root.isVideoName(pv.preview)) return root.videoThumbs[pv.preview] || "";
            return pv.remote ? pv.preview : ("file://" + pv.preview);
        }
        Layout.fillWidth: true
        Layout.preferredHeight: 72
        radius: 8
        color: root.theme.bgSurface
        border.width: 1
        border.color: root.theme.bgBorder
        clip: true
        Image {
            id: still
            anchors.fill: parent
            visible: pv.source !== "" && status !== Image.Error
            source: pv.source
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
        }
        Text {
            anchors.centerIn: parent
            visible: pv.source === "" || still.status === Image.Error
            text: pv.icon
            color: root.theme.accentPrimary
            font.family: root.mono
            font.pixelSize: 26
        }
        Component.onCompleted: {
            if (root.isVideoName(pv.preview)) root.queueVideoThumb(pv.preview);
        }
    }

    // one plugin tile, used for both the built-in and the community grids
    component PluginCard: Rectangle {
        id: card
        required property var modelData
        required property bool builtIn
        readonly property bool here: card.builtIn || card.modelData.installed !== false
        readonly property var info: card.here ? root.pluginInfoOf(card.modelData, card.builtIn)
            : ({ icon: card.modelData.icon, about: card.modelData.about })
        readonly property bool on: (AequalynSettings.enabledPlugins || []).indexOf(card.modelData.id) >= 0
        height: 208
        Layout.fillWidth: true
        Layout.preferredWidth: 180
        Layout.minimumWidth: 120
        Layout.preferredHeight: 208
        radius: 6
        color: root.theme.bgBase
        border.width: 1
        border.color: card.on ? root.theme.accentPrimary : root.theme.bgBorder
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 5
            CardPreview {
                preview: String(root.previewFor("plugin", card.modelData, card.builtIn) || "")
                icon: card.info.icon || "\u{F0431}"
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 7
                Text {
                    Layout.fillWidth: true
                    text: card.modelData.label || card.modelData.id
                    color: root.theme.textPrimary
                    font.family: root.sans
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Rectangle {
                    Layout.preferredWidth: 6
                    Layout.preferredHeight: 6
                    radius: 3
                    color: card.on ? root.theme.accentGreen : root.theme.textMuted
                }
            }
            Text {
                Layout.fillWidth: true
                text: card.info.about || card.modelData.about || card.modelData.source || ""
                color: root.theme.textSecondary
                font.family: root.sans
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
            Item { Layout.fillHeight: true }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 5
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 5
                    Btn {
                        visible: !card.here
                        Layout.fillWidth: true
                        implicitHeight: 24
                        text: "Install"
                        primary: true
                        enabled: !root.busy && !card.modelData.blocked
                        onClicked: root.installFromMarket("plugin", card.modelData)
                    }
                    Btn {
                        visible: card.here
                        Layout.fillWidth: true
                        implicitHeight: 24
                        text: card.on ? "Turn off" : "Turn on"
                        primary: true
                        onClicked: AequalynSettings.togglePlugin(card.modelData.id, !card.on)
                    }
                    Btn {
                        visible: card.builtIn
                        Layout.fillWidth: true
                        implicitHeight: 24
                        text: "Details"
                        onClicked: root.runSide(["qs", "ipc", "call", "aequalyn", "pluginPage", card.modelData.id])
                    }
                    // one row, as the built-in cards: Remove in words, or both as glyphs
                    // beside the first button when there is an Update too
                    Btn {
                        visible: !card.builtIn && card.here && card.modelData.newer !== false
                        Layout.preferredWidth: 28
                        implicitHeight: 24
                        icon: "\u{F06B0}"
                        Accessible.name: "Update"
                        enabled: !root.busy
                        onClicked: root.runJob("Updating " + card.modelData.id, ["update", "plugin", card.modelData.id])
                    }
                    Btn {
                        visible: !card.builtIn && card.here
                        Layout.fillWidth: card.modelData.newer === false
                        Layout.preferredWidth: card.modelData.newer === false ? implicitWidth : 28
                        implicitHeight: 24
                        text: card.modelData.newer === false ? "Remove" : ""
                        icon: card.modelData.newer === false ? "" : "\u{F0A7A}"
                        Accessible.name: "Remove"
                        danger: true
                        enabled: !root.busy
                        onClicked: root.runJob("Removing " + card.modelData.id, ["remove", "plugin", card.modelData.id])
                    }
                }
            }
        }
    }

    // a paged 5x3 grid, the same for the shell's plugins and the Store's ones
    component PluginGrid: Box {
        id: grid
        property string entriesTitle: ""
        property string entriesHint: ""
        property var entries: []
        property bool builtIn: true
        property int page: 0
        readonly property int count: grid.entries.length
        readonly property int at: root.pluginAt(grid.count, grid.page)
        title: grid.entriesTitle
        hint: grid.entriesHint
        visible: root.section === "plugin"
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
                visible: grid.count === 0
                text: "Nothing here yet."
                color: root.theme.textMuted
                font.family: root.sans
                font.pixelSize: 11
            }
            Repeater {
                model: grid.count > 0 ? root.pluginRows(grid.entries, grid.page) : []
                delegate: RowLayout {
                    id: pluginRow
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 216
                    spacing: 8
                    Repeater {
                        model: pluginRow.modelData
                        delegate: PluginCard {
                            builtIn: grid.builtIn
                        }
                    }
                    Repeater {
                        model: 5 - pluginRow.modelData.length
                        delegate: Item {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 180
                            Layout.preferredHeight: 208
                        }
                    }
                }
            }
            RowLayout {
                visible: grid.count > 15
                spacing: 6
                Item { Layout.fillWidth: true }
                Text {
                    text: grid.count + " plugins"
                    color: root.theme.textMuted; font.family: root.mono; font.pixelSize: 11
                }
                StepBtn {
                    glyph: "‹"
                    enabled: grid.at > 0
                    onClicked: grid.page = grid.at / 15 - 1
                }
                Text {
                    text: (grid.at + 1) + "–" + Math.min(grid.at + 15, grid.count) + " of " + grid.count
                    color: root.theme.textMuted; font.family: root.mono; font.pixelSize: 11
                }
                StepBtn {
                    glyph: "›"
                    enabled: grid.at + 15 < grid.count
                    onClicked: grid.page = grid.at / 15 + 1
                }
            }
        }
    }

    // one tile for the other Get kinds, with the same preview slot and the
    // same calm two-row action layout as a plugin card
    component GetCard: Rectangle {
        id: gcard
        required property var modelData
        required property bool builtIn
        required property string kind
        readonly property var entry: gcard.modelData
        readonly property string label: gcard.entry.label || gcard.entry.name || gcard.entry.id
        readonly property string about: gcard.entry.about || gcard.entry.source || ""
        readonly property string icon: gcard.entry.icon || (root.sections.find(s => s.key === gcard.kind) || {}).glyph || "\u{F0431}"
        readonly property bool installed: !!gcard.entry.installed
        readonly property string preview: String(root.previewFor(gcard.kind, gcard.entry, gcard.builtIn) || "")
        readonly property string actionText: {
            if (gcard.builtIn) {
                if (gcard.kind === "cursor") return "Open Plume";
                if (gcard.kind === "look") return "Open Control Center";
                if (gcard.kind === "theme") return gcard.installed ? "Apply" : "Install";
                if (gcard.kind === "wallpaper") return gcard.installed ? "Set" : "Install";
            }
            if (!gcard.installed) return "Install";
            if (gcard.kind === "theme") return "Apply";
            if (gcard.kind === "cursor") return "Wear";
            if (gcard.kind === "wallpaper") return "Set";
            if (gcard.kind === "look") return "Wear all";
            return "Open";
        }
        height: 208
        Layout.fillWidth: true
        Layout.preferredWidth: 180
        Layout.minimumWidth: 120
        Layout.preferredHeight: 208
        radius: 6
        color: root.theme.bgBase
        border.width: 1
        border.color: root.theme.bgBorder
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 5
            CardPreview {
                preview: gcard.preview
                icon: gcard.icon
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 7
                Text {
                    Layout.fillWidth: true
                    text: gcard.label
                    color: root.theme.textPrimary
                    font.family: root.sans
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Rectangle {
                    Layout.preferredWidth: 6
                    Layout.preferredHeight: 6
                    radius: 3
                    color: gcard.installed ? root.theme.accentGreen : root.theme.textMuted
                }
            }
            Text {
                Layout.fillWidth: true
                text: (gcard.entry.by ? "by " + gcard.entry.by + " · " : "") + gcard.about
                color: root.theme.textSecondary
                font.family: root.sans
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
            Item { Layout.fillHeight: true }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 5
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 5
                    Btn {
                        Layout.fillWidth: true
                        implicitHeight: 24
                        text: gcard.actionText
                        primary: true
                        enabled: !root.busy && !gcard.entry.blocked
                        onClicked: {
                            if (!gcard.builtIn && !gcard.installed) root.installFromMarket(gcard.kind, gcard.entry);
                            else root.getPrimary(gcard.kind, gcard.entry, gcard.builtIn);
                        }
                    }
                    Btn {
                        visible: gcard.builtIn && gcard.installed && (gcard.kind === "theme" || gcard.kind === "wallpaper")
                        Layout.fillWidth: true
                        implicitHeight: 24
                        text: "Page"
                        onClicked: root.runSide(["qs", "ipc", "call", "aequalyn", "page", gcard.kind === "theme" ? "theme" : "wallpaper"])
                    }
                    // one row, as the built-in cards: Remove in words, or both as glyphs
                    // beside the first button when there is an Update too
                    Btn {
                        visible: !gcard.builtIn && gcard.installed && gcard.entry.newer !== false
                        Layout.preferredWidth: 28
                        implicitHeight: 24
                        icon: "\u{F06B0}"
                        Accessible.name: "Update"
                        enabled: !root.busy
                        onClicked: root.runJob("Updating " + gcard.entry.id, ["update", gcard.kind, gcard.entry.id])
                    }
                    Btn {
                        visible: !gcard.builtIn && gcard.installed
                        Layout.fillWidth: gcard.entry.newer === false
                        Layout.preferredWidth: gcard.entry.newer === false ? implicitWidth : 28
                        implicitHeight: 24
                        text: gcard.entry.newer === false ? "Remove" : ""
                        icon: gcard.entry.newer === false ? "" : "\u{F0A7A}"
                        Accessible.name: "Remove"
                        danger: true
                        enabled: !root.busy
                        onClicked: root.runJob("Removing " + gcard.entry.id, ["remove", gcard.kind, gcard.entry.id])
                    }
                }
            }
        }
    }

    // the same 5x3 grid, with Get-kind cards in place of plugin cards
    component GetGrid: Box {
        id: getGrid
        property string kind: ""
        property string entriesTitle: ""
        property string entriesHint: ""
        property var entries: []
        property bool builtIn: true
        property int page: 0
        readonly property int count: getGrid.entries.length
        readonly property int at: root.pluginAt(getGrid.count, getGrid.page)
        title: getGrid.entriesTitle
        hint: getGrid.entriesHint
        visible: getGrid.kind !== "" && root.section === getGrid.kind
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
                visible: getGrid.count === 0
                text: "Nothing here yet."
                color: root.theme.textMuted
                font.family: root.sans
                font.pixelSize: 11
            }
            Repeater {
                model: getGrid.count > 0 ? root.pluginRows(getGrid.entries, getGrid.page) : []
                delegate: RowLayout {
                    id: getRow
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 216
                    spacing: 8
                    Repeater {
                        model: getRow.modelData
                        delegate: GetCard {
                            kind: getGrid.kind
                            builtIn: getGrid.builtIn
                        }
                    }
                    Repeater {
                        model: 5 - getRow.modelData.length
                        delegate: Item {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 180
                            Layout.preferredHeight: 208
                        }
                    }
                }
            }
            RowLayout {
                visible: getGrid.count > 15
                spacing: 6
                Item { Layout.fillWidth: true }
                Text {
                    text: getGrid.count + " items"
                    color: root.theme.textMuted; font.family: root.mono; font.pixelSize: 11
                }
                StepBtn {
                    glyph: "‹"
                    enabled: getGrid.at > 0
                    onClicked: getGrid.page = getGrid.at / 15 - 1
                }
                Text {
                    text: (getGrid.at + 1) + "–" + Math.min(getGrid.at + 15, getGrid.count) + " of " + getGrid.count
                    color: root.theme.textMuted; font.family: root.mono; font.pixelSize: 11
                }
                StepBtn {
                    glyph: "›"
                    enabled: getGrid.at + 15 < getGrid.count
                    onClicked: getGrid.page = getGrid.at / 15 + 1
                }
            }
        }
    }

    // the form that installs one kind from a git URL, with Check beside Install
    component InstallBox: Box {
        id: ib
        property string kind: "plugin"
        title: "Install a " + root.kindWords[kind].one + " from git"
        hint: root.kindWords[kind].hint
        RowLayout {
            spacing: 8
            Field { id: urlField; placeholder: "https://github.com/someone/aequalyn-" + ib.kind + "-name   (or a folder)" }
            Field { id: atField; placeholder: "commit (optional)"; Layout.fillWidth: false; Layout.preferredWidth: 160 }
        }
        RowLayout {
            spacing: 8
            Btn {
                text: "Check"
                enabled: !root.busy && urlField.text.trim() !== ""
                onClicked: root.runJob("Checking " + urlField.text.trim(), ["check", ib.kind, urlField.text.trim()]
                                       .concat(atField.text.trim() !== "" ? ["--at", atField.text.trim()] : []))
            }
            Btn {
                text: "Install"
                primary: true
                enabled: !root.busy && urlField.text.trim() !== ""
                onClicked: root.runJob("Installing " + urlField.text.trim(), ["install", ib.kind, urlField.text.trim()]
                                       .concat(atField.text.trim() !== "" ? ["--at", atField.text.trim()] : []))
            }
        }
    }

    // ---- the window -------------------------------------------------------------------------
    PanelWindow {
        id: win
        visible: veil.shown
        focusable: true
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: veil.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace: veil.layerName("store")
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }

        MouseArea {
            anchors.fill: parent
            onClicked: { if (root.pickOpen) root.pickOpen = false; else root.open = false }
            Backdrop { id: veil; open: root.open; theme: root.theme; tintAlpha: 0.35 }
        }

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: Math.min(1320, parent.width * 0.9)
            height: Math.min(900, parent.height * 0.9)
            radius: 20
            color: root.theme.bgBase
            border.width: 1
            border.color: root.theme.bgBorder
            clip: true
            opacity: veil.progress
            scale: 0.97 + 0.03 * veil.progress
            focus: true
            Keys.onPressed: event => {
                if (event.key === Qt.Key_K && (event.modifiers & Qt.ControlModifier)) {
                    titleSearch.forceActiveFocus();
                    event.accepted = true;
                } else if (root.queryActive || root.pickOpen || root.appPage || titleSearch.activeFocus) {
                    // the search, the file picker and an app page own their keys;
                    // the chooser down the left is only for the plain page view
                    return;
                } else if (event.key === Qt.Key_Left) {
                    root.focusRail();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Right) {
                    root.focusSections();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Up) {
                    if (root.navSide === "rail") root.stepCategory(-1); else root.stepSection(-1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Down) {
                    if (root.navSide === "rail") root.stepCategory(1); else root.stepSection(1);
                    event.accepted = true;
                }
            }
            Keys.onEscapePressed: {
                // the picker over the page closes first, then an app page goes
                // back to where it was opened from, then the window.
                if (root.pickOpen) { root.pickOpen = false; return; }
                if (root.appPage) { root.backFromApp(); return; }
                root.open = false;
            }
            MouseArea { anchors.fill: parent }   // clicks inside never close it

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // title bar, as the control center's: the mark, the name, where
                // you are, the search and the close
                Item {
                    id: titleBar
                    Layout.fillWidth: true
                    Layout.preferredHeight: 68
                    Image {
                        id: mark
                        source: "root:/assets/ae-mark.svg"
                        x: 20
                        anchors.verticalCenter: parent.verticalCenter
                        width: 42; height: 28
                        sourceSize.width: 42; sourceSize.height: 28
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        layer.enabled: true
                        layer.effect: MultiEffect { colorization: 1.0; colorizationColor: root.theme.accentPrimary }
                    }
                    Text {
                        id: titleText
                        anchors.left: mark.right
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Store"
                        color: root.theme.textPrimary
                        font.family: root.sans
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                    }
                    Text {
                        id: sectionText
                        anchors.left: titleText.right
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, 220)
                        elide: Text.ElideRight
                        text: root.currentTitle()
                        color: root.theme.textMuted
                        font.family: root.sans
                        font.pixelSize: 13
                    }
                    // the control center's search, here for the Store's apps
                    Rectangle {
                        id: searchBox
                        anchors.left: sectionText.right
                        anchors.leftMargin: 28
                        anchors.right: closeButton.left
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        height: 42
                        radius: 12
                        color: root.theme.bgSurface
                        border.width: titleSearch.activeFocus ? 2 : 1
                        border.color: titleSearch.activeFocus ? root.theme.accentPrimary : root.theme.bgBorder
                        Text {
                            id: searchIcon
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            text: "\u{F0349}"
                            color: root.theme.accentPrimary
                            font.family: root.mono
                            font.pixelSize: 16
                        }
                        TextInput {
                            id: titleSearch
                            anchors.left: searchIcon.right
                            anchors.leftMargin: 10
                            anchors.right: keyHint.left
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            color: root.theme.textPrimary
                            font.family: root.sans
                            font.pixelSize: 14
                            clip: true
                            selectByMouse: true
                            onTextChanged: root.query = text
                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Escape && text !== "") {
                                    text = ""; event.accepted = true;
                                } else if (event.key === Qt.Key_Down) {
                                    root.pick = Math.min(root.resultShown.length - 1, root.pick + 1); event.accepted = true;
                                } else if (event.key === Qt.Key_Up) {
                                    root.pick = Math.max(0, root.pick - 1); event.accepted = true;
                                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    root.activateResult(root.resultShown[root.pick]);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                                    const srcs = root.resultSources.filter(s => s === "All" || root.resultCount(s) > 0);
                                    const i = srcs.indexOf(root.querySource);
                                    root.setQuerySource(srcs[(i + (event.key === Qt.Key_Tab ? 1 : srcs.length - 1)) % srcs.length]);
                                    event.accepted = true;
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: titleSearch.text === ""
                                text: "Search every app, like “obsidian”"
                                color: root.theme.textMuted
                                font: titleSearch.font
                            }
                        }
                        Text {
                            id: keyHint
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            text: "ctrl k"
                            color: root.theme.textMuted
                            font.family: root.mono
                            font.pixelSize: 11
                        }
                        MouseArea { anchors.fill: parent; onClicked: titleSearch.forceActiveFocus(); z: -1 }
                    }
                    Rectangle {
                        id: closeButton
                        anchors.right: parent.right
                        anchors.rightMargin: 18
                        anchors.verticalCenter: parent.verticalCenter
                        width: 34; height: 34; radius: 10
                        color: closeMa.containsMouse ? root.theme.bgHover : "transparent"
                        Accessible.role: Accessible.Button
                        Accessible.name: "Close"
                        Text { anchors.centerIn: parent; text: "✕"; color: root.theme.textSecondary; font.family: root.sans; font.pixelSize: 14 }
                        MouseArea { id: closeMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.open = false }
                    }
                }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: root.theme.bgBorder }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    // the categories, as the control center's: a short rail down the
                    // left, then the sections of the chosen one beside it
                    ColumnLayout {
                        Layout.preferredWidth: 96
                        Layout.maximumWidth: 96
                        Layout.fillHeight: true
                        Layout.leftMargin: 6
                        Layout.topMargin: 12
                        Layout.bottomMargin: 8
                        spacing: 2
                        Repeater {
                            model: [{ key: "", title: "Home", icon: "\u{F02DC}" }].concat(root.categories)
                            delegate: Item {
                                id: catItem
                                required property var modelData
                                readonly property bool on: root.category === modelData.key
                                Layout.fillWidth: true
                                Layout.preferredHeight: 64
                                Accessible.role: Accessible.PageTab
                                Accessible.name: modelData.title
                                Rectangle {
                                    id: catBox
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: 6
                                    width: 40; height: 34; radius: 10
                                    color: catItem.on ? root.theme.bgSelected : catMa.containsMouse ? root.theme.bgSurface : "transparent"
                                    border.width: catItem.on || (root.navSide === "rail" && !root.queryActive && !root.pickOpen && !root.appPage) ? 1 : 0
                                    border.color: catItem.on ? root.theme.accentPrimary : Cc.alpha(root.theme.accentPrimary, 0.35)
                                    Text {
                                        anchors.centerIn: parent
                                        text: catItem.modelData.icon
                                        color: catItem.on ? root.theme.accentPrimary : root.theme.textSecondary
                                        font.family: root.mono
                                        font.pixelSize: 17
                                    }
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.top: catBox.bottom
                                    anchors.topMargin: 4
                                    width: parent.width - 4
                                    text: catItem.modelData.title
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignHCenter
                                    color: catItem.on ? root.theme.textPrimary : root.theme.textMuted
                                    font.family: root.mono
                                    font.pixelSize: 11
                                    font.bold: catItem.on
                                }
                                MouseArea { id: catMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.openCategory(modelData.key) }
                            }
                        }
                        Item { Layout.fillHeight: true }
                    }
                    Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: root.theme.bgBorder }

                    // the sections of the category, like the control center's page list
                    ColumnLayout {
                        id: sectionNav
                        Layout.preferredWidth: root.categoryNow ? 214 : 0
                        Layout.maximumWidth: root.categoryNow ? 214 : 0
                        Layout.leftMargin: root.categoryNow ? 12 : 0
                        Layout.topMargin: 12
                        Layout.bottomMargin: 8
                        Layout.fillHeight: true
                        spacing: 2
                        visible: root.categoryNow !== null
                        clip: true
                        Text {
                            leftPadding: 8
                            text: root.categoryNow ? root.categoryNow.icon + "  " + root.categoryNow.title : ""
                            color: root.theme.accentPrimary
                            font.family: root.mono
                            font.pixelSize: 14
                            font.bold: true
                        }
                        Text {
                            leftPadding: 8
                            bottomPadding: 10
                            text: root.sectionNavItems.length + " sections"
                            color: root.theme.textMuted
                            font.family: root.mono
                            font.pixelSize: 11
                        }
                        Repeater {
                            model: root.sectionNavItems
                            delegate: Rectangle {
                                id: navItem
                                required property var modelData
                                readonly property var info: modelData
                                readonly property bool on: root.navIsOn(modelData)
                                Layout.fillWidth: true
                                Layout.preferredHeight: 38
                                radius: 8
                                color: navItem.on ? root.theme.bgSelected : navMa.containsMouse ? root.theme.bgSurface : "transparent"
                                border.width: root.navSide === "sections" && sectionNav.visible && !root.queryActive && !root.pickOpen && !root.appPage ? 1 : 0
                                border.color: Cc.alpha(root.theme.accentPrimary, 0.28)
                                Rectangle {
                                    visible: navItem.on
                                    width: 3; height: 20; radius: 2
                                    anchors.left: parent.left
                                    anchors.leftMargin: 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: root.theme.accentPrimary
                                }
                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 10
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 18
                                        horizontalAlignment: Text.AlignHCenter
                                        text: navItem.info.glyph || ""
                                        color: root.theme.accentPrimary
                                        font.family: root.mono
                                        font.pixelSize: 14
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: navItem.info.label || ""
                                        color: navItem.on ? root.theme.textPrimary : root.theme.textSecondary
                                        font.family: root.sans
                                        font.pixelSize: 13
                                        font.weight: navItem.on ? Font.DemiBold : Font.Normal
                                    }
                                }
                                MouseArea { id: navMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.openNav(modelData) }
                            }
                        }
                        Item { Layout.fillHeight: true }
                    }
                    Rectangle { visible: root.categoryNow !== null; Layout.preferredWidth: 1; Layout.fillHeight: true; color: root.theme.bgBorder }

                    // the page, and the report of the last job under it
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 0
                        Flickable {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            contentHeight: pageCol.implicitHeight + 40
                            boundsBehavior: Flickable.StopAtBounds
                            // a section's page comes in with the same rise the control
                            // center's pages use: what is drawn moves, nothing is
                            // laid out again
                            ColumnLayout {
                                id: pageCol
                                property real enter: 1
                                opacity: 0.35 + 0.65 * enter
                                transform: Translate { y: (1 - pageCol.enter) * 10 }
                                NumberAnimation { id: pageIn; target: pageCol; property: "enter"; from: 0; to: 1; duration: 170; easing.type: Easing.OutCubic }
                                x: 20; y: 20
                                width: parent.width - 40
                                spacing: 12

                                // Home
                                Box {
                                    visible: root.section === "home"
                                    title: "Everything here is checked before it is kept"
                                    hint: "Plugins, themes, cursors, wallpaper packs and looks come from git. Each one goes through the same checks first: its files, its syntax (qmllint), what it may run and where it may write. Nothing that fails is installed, and the report says why. Looks dress one piece of the desktop or several: the bar, the docks, the cursor, the lock screen, the lock and sleep timings, the login screen."
                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: 8
                                        Repeater {
                                            model: root.sections.filter(s => s.key !== "home")
                                            delegate: Btn {
                                                required property var modelData
                                                text: modelData.label
                                                onClicked: root.openSection(modelData.key)
                                            }
                                        }
                                    }
                                }

                                // community first, then the git form, then the shell's own
                                // plugins; each grid is fifteen tiles: five across, three rows
                                PluginGrid {
                                    entriesTitle: "Community"
                                    entriesHint: root.communityHint("plugin")
                                    entries: root.communityEntries("plugin")
                                    builtIn: false
                                }

                                GetGrid {
                                    kind: root.categoryOf(root.section) === "get" && root.section !== "plugin" ? root.section : ""
                                    entriesTitle: "Community"
                                    entriesHint: root.communityHint(root.section)
                                    entries: root.communityEntries(root.section)
                                    builtIn: false
                                }

                                InstallBox {
                                    visible: !!root.kindWords[root.section]
                                    kind: root.kindWords[root.section] ? root.section : "plugin"
                                }

                                PluginGrid {
                                    entriesTitle: "Built-in"
                                    entriesHint: "These ship with Aequalyn. Turn them on or open their page here; nothing to download."
                                    entries: root.builtInPlugins
                                    builtIn: true
                                }

                                GetGrid {
                                    kind: root.categoryOf(root.section) === "get" && root.section !== "plugin" ? root.section : ""
                                    entriesTitle: "Built-in"
                                    entriesHint: root.builtInHint(root.section)
                                    entries: root.builtInEntries(root.section)
                                    builtIn: true
                                }

                                // Apps: the four backends, then the popular apps, each from
                                // any backend that has it; installed packages are in All apps
                                Box {
                                    visible: root.section === "apps" && root.appCategory === "all"
                                    title: "Backends"
                                    hint: "Where apps come from. Arch's own repositories (multilib included) are always here; the AUR, Flathub and Snap are one click away."
                                    Repeater {
                                        model: [
                                            { key: "pacman", label: "Arch repositories", tool: "pacman", needs: "" },
                                            { key: "yay", label: "AUR", tool: "yay", needs: "" },
                                            { key: "flatpak", label: "Flathub", tool: "flatpak", needs: "" },
                                            { key: "snap", label: "Snap Store", tool: "snapd, from the AUR", needs: "yay" }
                                        ]
                                        delegate: RowLayout {
                                            required property var modelData
                                            readonly property bool ready: modelData.key === "pacman" || root.backends[modelData.key] === true
                                            Layout.fillWidth: true
                                            spacing: 10
                                            Text { text: modelData.label; color: root.theme.textPrimary; font.family: root.sans; font.pixelSize: 13; Layout.preferredWidth: 160 }
                                            Text { text: modelData.tool; color: root.theme.textMuted; font.family: root.mono; font.pixelSize: 11; Layout.fillWidth: true }
                                            Pill { visible: parent.ready; text: "Ready"; tone: root.theme.accentGreen }
                                            Btn {
                                                visible: !parent.ready
                                                text: "Install " + modelData.label
                                                enabled: !root.anyBusy() && (modelData.needs === "" || root.backends[modelData.needs] === true)
                                                onClicked: root.installBackend(modelData.key)
                                            }
                                        }
                                    }
                                    Text {
                                        visible: !root.backends.yay && !root.backends.snap
                                        text: "Snap comes from the AUR: install the AUR first."
                                        color: root.theme.textMuted; font.family: root.sans; font.pixelSize: 11
                                    }
                                }
                                Box {
                                    id: communityApps
                                    readonly property var apps: root.section === "apps" ? root.market.filter(m => m.kind === "app") : []
                                    visible: root.section === "apps" && root.appCategory === "all" && communityApps.apps.length > 0
                                    title: "Community"
                                    hint: "From the Market: built from source here, at the exact commit that was reviewed, in a terminal where sudo asks for your password."
                                    Repeater {
                                        model: communityApps.apps
                                        delegate: RowLayout {
                                            id: capp
                                            required property var modelData
                                            Layout.fillWidth: true
                                            spacing: 10
                                            Image {
                                                Layout.preferredWidth: 32
                                                Layout.preferredHeight: 32
                                                source: capp.modelData.preview || root.appIconUrl("", capp.modelData.name || capp.modelData.id)
                                                sourceSize.width: 64
                                                sourceSize.height: 64
                                                fillMode: Image.PreserveAspectFit
                                                asynchronous: true
                                            }
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 1
                                                Text { text: capp.modelData.name || capp.modelData.id; color: root.theme.textPrimary; font.family: root.sans; font.pixelSize: 13; font.weight: Font.DemiBold }
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: (capp.modelData.by ? "by " + capp.modelData.by + " · " : "") + (capp.modelData.about || "")
                                                    color: root.theme.textSecondary; font.family: root.sans; font.pixelSize: 11; elide: Text.ElideRight
                                                }
                                            }
                                            Pill { visible: capp.modelData.state === "installed"; text: "Installed"; tone: root.theme.accentGreen }
                                            Btn {
                                                visible: capp.modelData.state !== "installed"
                                                text: capp.modelData.state === "update available" ? "Update" : "Install"
                                                primary: true
                                                enabled: !root.anyBusy()
                                                onClicked: root.installFromMarket("app", capp.modelData)
                                            }
                                        }
                                    }
                                }
                                Box {
                                    visible: root.section === "apps" && root.appCategory === "all"
                                    title: "Popular apps"
                                    hint: "Every card shows all four ways to install it. A greyed button means that app has no build there; installs open in a terminal, where sudo asks for your password."
                                    SourceCards {
                                        model: root.section === "apps" ? root.popShown : []
                                        page: root.popPage
                                        onGoToPage: value => root.popPage = value
                                    }
                                }
                                // every app from every backend
                                Box {
                                    visible: root.section === "apps" && root.appCategory === "all"
                                    title: "All Apps"
                                    hint: "Pick a group in the side list, or here, to narrow the apps. " + (root.foundSource === "Installed"
                                        ? (root.installedQuery === ""
                                           ? "Everything installed from Arch, the AUR, Flathub and Snap, command-line tools included. Search to narrow this list."
                                           : "Installed packages matching \"" + root.installedQuery + "\".")
                                        : root.foundQuery === ""
                                          ? "Flathub's most installed and Snap's featured apps. Search to look through Arch, the AUR, Flathub and Snap at once."
                                          : "Everything that matches \"" + root.foundQuery + "\" in Arch, the AUR, Flathub and Snap.")
                                    RowLayout {
                                        spacing: 8
                                        Field {
                                            id: appSearch
                                            placeholder: "Search every app, like \"obsidian\""
                                            onAccepted: root.searchApps(appSearch.text.trim(), false)
                                        }
                                        Btn { text: root.searching ? "Searching…" : "Search"; primary: true; enabled: !root.searching; onClicked: root.searchApps(appSearch.text.trim(), false) }
                                    }
                                    // Super + I's groups, right in the app list: All first,
                                    // then the curated categories, then anything unmapped
                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: 6
                                        Repeater {
                                            model: [{ key: "all", label: "All" }].concat(root.appCategories)
                                            delegate: Btn {
                                                required property var modelData
                                                text: modelData.label + "  " + root.appCategoryCount(modelData.key)
                                                primary: root.appCategory === modelData.key
                                                implicitHeight: 26
                                                onClicked: {
                                                    root.appCategory = modelData.key;
                                                    root.foundAt = 0;
                                                }
                                            }
                                        }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6
                                        Repeater {
                                            model: ["All", "Installed", "Arch", "AUR", "Flatpak", "Snap"]
                                            delegate: Btn {
                                                required property string modelData
                                                readonly property int count: modelData === "All" ? root.appPool.length
                                                    : modelData === "Installed" ? root.installedResults.length
                                                    : root.appPool.filter(r => r.source === modelData).length
                                                Layout.fillWidth: true
                                                Layout.preferredWidth: 0
                                                Layout.minimumWidth: 0
                                                text: modelData + "  " + count + (root.foundErrors[modelData] ? "  ⚠" : "")
                                                primary: root.foundSource === modelData
                                                implicitHeight: 26
                                                onClicked: {
                                                    root.installedQuery = modelData === "Installed" ? appSearch.text.trim() : "";
                                                    root.foundSource = modelData;
                                                    root.appCategory = "all";
                                                    root.foundAt = 0;
                                                }
                                            }
                                        }
                                    }
                                    Text {
                                        visible: root.foundSource !== "Installed" && Object.keys(root.foundErrors).length > 0
                                        text: "Could not reach: " + Object.keys(root.foundErrors).join(", ") + ". Search again in a moment."
                                        color: root.theme.accentOrange; font.family: root.sans; font.pixelSize: 11
                                    }
                                    BrowseCards {
                                        model: root.foundShown
                                        page: Math.floor(root.foundAt / root.foundStep)
                                        onGoToPage: value => root.foundAt = value * root.foundStep
                                    }
                                    Btn {
                                        visible: root.foundPage > 0 && root.foundPage < root.flathubPages && (root.foundSource === "All" || root.foundSource === "Flatpak")
                                        text: root.searching ? "Loading…" : "More from Flathub (page " + (root.foundPage + 1) + " of " + root.flathubPages + ")"
                                        enabled: !root.searching
                                        onClicked: root.searchApps(root.foundQuery, true)
                                    }
                                }
                                // One page for the chosen Super + I category, with the
                                // same source-button cards and page opening as Popular apps.
                                Repeater {
                                    model: root.currentAppCategory ? [root.currentAppCategory] : []
                                    delegate: Box {
                                        required property var modelData
                                        property int cardPage: 0
                                        title: modelData.label + (modelData.key === "other" ? "" : " apps")
                                        hint: "Each app has its install-source buttons, as in Popular apps. Click the card itself to open the app's own page."
                                        SourceCards {
                                            model: root.categoryAppCards(modelData.key)
                                            page: cardPage
                                            limit: root.categoryAppLimit
                                            onGoToPage: value => cardPage = value
                                        }
                                        Text {
                                            visible: root.categoryAppCards(modelData.key).length === 0
                                            text: "No apps in this group yet. Search from the title bar to add more to the list."
                                            color: root.theme.textMuted; font.family: root.sans; font.pixelSize: 11
                                        }
                                    }
                                }
                                // Web apps: what you have, the form, and the browser
                                Box {
                                    visible: root.section === "web"
                                    title: "Your web apps"
                                    hint: root.webapps.length === 0
                                          ? "No web apps yet. Add one below; the default set can be seeded from a terminal with aequalyn-webapp seed."
                                          : root.webShown.length === 0 ? "No web apps in this category." : ""
                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: 6
                                        Btn {
                                            text: "All"
                                            primary: root.webFilter === "all"
                                            implicitHeight: 26
                                            onClicked: root.setWebFilter("all")
                                        }
                                        Repeater {
                                            model: root.webCategories.filter(c => root.webapps.some(a => a.category === c.id))
                                            delegate: Btn {
                                                required property var modelData
                                                text: modelData.label
                                                primary: root.webFilter === modelData.id
                                                implicitHeight: 26
                                                onClicked: root.setWebFilter(modelData.id)
                                            }
                                        }
                                        Btn {
                                            visible: root.webHasUncategorised
                                            text: "Uncategorised"
                                            primary: root.webFilter === "none"
                                            implicitHeight: 26
                                            onClicked: root.setWebFilter("none")
                                        }
                                    }
                                    // a few unfiltered: the plain list; filtered or more: cards
                                    Repeater {
                                        visible: !root.webUseCards
                                        model: root.section === "web" && !root.webUseCards ? root.webShown : []
                                        delegate: ColumnLayout {
                                            id: wrow
                                            required property var modelData
                                            required property int index
                                            readonly property string label: wrow.modelData.name || wrow.modelData.slug || "web app"
                                            readonly property string iconUrl: root.localAppIcon(wrow.modelData.iconFile, wrow.label)
                                            readonly property string initials: root.appInitials(wrow.label)
                                            readonly property color monogramColor: root.appMonogramColor(wrow.label)
                                            Layout.fillWidth: true
                                            spacing: 0
                                            Rectangle { visible: wrow.index > 0; Layout.fillWidth: true; Layout.preferredHeight: 1; color: root.theme.bgBorder }
                                            RowLayout {
                                                Layout.fillWidth: true
                                                Layout.leftMargin: 12
                                                Layout.rightMargin: 12
                                                Layout.topMargin: 9
                                                Layout.bottomMargin: 9
                                                spacing: 10
                                                Item {
                                                    Layout.preferredWidth: 30
                                                    Layout.preferredHeight: 30
                                                    Image {
                                                        id: wicon
                                                        anchors.fill: parent
                                                        visible: status === Image.Ready
                                                        source: wrow.iconUrl
                                                        sourceSize.width: 64; sourceSize.height: 64
                                                        fillMode: Image.PreserveAspectFit
                                                        asynchronous: true
                                                        smooth: true
                                                    }
                                                    Rectangle {
                                                        anchors.fill: parent
                                                        radius: 8
                                                        color: wrow.monogramColor
                                                        visible: !wicon.visible
                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: wrow.initials
                                                            color: "#ffffff"
                                                            font.family: root.sans
                                                            font.pixelSize: 11
                                                            font.weight: Font.DemiBold
                                                        }
                                                    }
                                                }
                                                ColumnLayout {
                                                    spacing: 2
                                                    Layout.fillWidth: true
                                                    RowLayout {
                                                        spacing: 8
                                                        Layout.fillWidth: true
                                                        Text { text: wrow.modelData.name; color: root.theme.textPrimary; font.family: root.sans; font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
                                                        Pill { visible: !!wrow.modelData.categoryLabel; text: wrow.modelData.categoryLabel; tone: root.theme.accentPrimary }
                                                        Pill { visible: !!wrow.modelData.shortcut; text: wrow.modelData.shortcut; tone: root.theme.textMuted }
                                                        Item { Layout.fillWidth: true }
                                                    }
                                                    Text {
                                                        text: wrow.modelData.url
                                                        color: root.theme.textMuted; font.family: root.mono; font.pixelSize: 11
                                                        elide: Text.ElideMiddle; Layout.fillWidth: true
                                                    }
                                                }
                                                Btn {
                                                    text: wrow.modelData.categoryLabel || "Category"
                                                    enabled: !root.busy
                                                    onClicked: root.categoryTarget = wrow.modelData
                                                }
                                                Btn {
                                                    text: "Open"
                                                    primary: true
                                                    onClicked: Quickshell.execDetached(["aequalyn-webapp", "launch", wrow.modelData.slug])
                                                }
                                                Btn {
                                                    text: "Remove"
                                                    danger: true
                                                    enabled: !root.busy
                                                    onClicked: root.runCmd("Removing " + wrow.modelData.name, ["aequalyn-webapp", "remove", "--slug", wrow.modelData.slug])
                                                }
                                            }
                                        }
                                    }
                                    // cards like the AppImages ones: five to a row, the
                                    // page holding its three rows, ‹ › to walk the pages
                                    Repeater {
                                        visible: root.webUseCards
                                        model: root.section === "web" && root.webUseCards ? root.webRows() : []
                                        delegate: RowLayout {
                                            id: webRow
                                            required property var modelData
                                            Layout.fillWidth: true
                                            // an all-ghost row keeps the card height, so the page
                                            // holds its shape even when nothing is in it
                                            Layout.preferredHeight: 150
                                            spacing: 10
                                            Repeater {
                                                model: webRow.modelData
                                                delegate: AppCard {
                                                    Layout.fillWidth: true
                                                    Layout.preferredWidth: 203
                                                    onOpenRequested: Quickshell.execDetached(["aequalyn-webapp", "launch", modelData.slug])
                                                    onRemoveRequested: root.runCmd("Removing " + modelData.name, ["aequalyn-webapp", "remove", "--slug", modelData.slug])
                                                    onCategoryRequested: root.categoryTarget = modelData
                                                }
                                            }
                                            Repeater {
                                                model: 5 - webRow.modelData.length
                                                delegate: Item { Layout.fillWidth: true; Layout.preferredWidth: 203 }
                                            }
                                        }
                                    }
                                    RowLayout {
                                        visible: root.webShown.length > 15
                                        spacing: 6
                                        Item { Layout.fillWidth: true }
                                        Text {
                                            text: root.webShown.length + (root.webShown.length === 1 ? " app" : " apps")
                                            color: root.theme.textMuted; font.family: root.mono; font.pixelSize: 11
                                        }
                                        StepBtn {
                                            glyph: "‹"
                                            enabled: root.webAt > 0
                                            onClicked: root.webPage = root.webAt / 15 - 1
                                        }
                                        Text {
                                            text: (root.webAt + 1) + "–" + Math.min(root.webAt + 15, root.webShown.length)
                                                  + " of " + root.webShown.length
                                            color: root.theme.textMuted; font.family: root.mono; font.pixelSize: 11
                                        }
                                        StepBtn {
                                            glyph: "›"
                                            enabled: root.webAt + 15 < root.webShown.length
                                            onClicked: root.webPage = root.webAt / 15 + 1
                                        }
                                    }
                                }
                                Box {
                                    visible: root.section === "web" && root.categoryTarget !== null
                                    title: "Category for " + (root.categoryTarget ? root.categoryTarget.name : "")
                                    hint: "Pick one of your categories, or None to leave it uncategorised. The launcher's keywords follow the name."
                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: 6
                                        Btn {
                                            text: "None"
                                            primary: root.categoryTarget && !root.categoryTarget.category
                                            enabled: !root.busy
                                            onClicked: root.setWebCategory("")
                                        }
                                        Repeater {
                                            model: root.webCategories
                                            delegate: Btn {
                                                required property var modelData
                                                text: modelData.label
                                                primary: root.categoryTarget && root.categoryTarget.category === modelData.id
                                                enabled: !root.busy
                                                onClicked: root.setWebCategory(modelData.id)
                                            }
                                        }
                                    }
                                    Btn { text: "Close"; onClicked: root.categoryTarget = null }
                                }
                                Box {
                                    visible: root.section === "web"
                                    title: "Categories"
                                    hint: "Yours to change: add one (it can stay empty until you put a web app in it), rename it, or remove it. A removed category leaves its web apps uncategorised."
                                    RowLayout {
                                        spacing: 8
                                        Field {
                                            id: newWebCategory
                                            placeholder: "New category, like Research"
                                            onAccepted: {
                                                const label = text.trim();
                                                if (label === "" || root.busy) return;
                                                text = "";
                                                root.runCmd("Adding category " + label, ["aequalyn-webapp", "category-add", label]);
                                            }
                                        }
                                        Btn {
                                            text: "Add"
                                            primary: true
                                            enabled: !root.busy && newWebCategory.text.trim() !== ""
                                            onClicked: {
                                                const label = newWebCategory.text.trim();
                                                newWebCategory.text = "";
                                                root.runCmd("Adding category " + label, ["aequalyn-webapp", "category-add", label]);
                                            }
                                        }
                                    }
                                    GridLayout {
                                        Layout.fillWidth: true
                                        columns: 4
                                        columnSpacing: 8
                                        rowSpacing: 8
                                        Repeater {
                                            model: root.section === "web" ? root.webCategories : []
                                            delegate: Rectangle {
                                                required property var modelData
                                                Layout.fillWidth: true
                                                Layout.preferredWidth: 0
                                                Layout.minimumWidth: 0
                                                Layout.preferredHeight: 88
                                                radius: 10
                                                color: root.theme.bgBase
                                                border.width: 1
                                                border.color: root.theme.bgBorder
                                                ColumnLayout {
                                                    anchors.fill: parent
                                                    anchors.margins: 10
                                                    spacing: 6
                                                    RowLayout {
                                                        Layout.fillWidth: true
                                                        spacing: 6
                                                        Text {
                                                            text: modelData.label
                                                            color: root.theme.textPrimary; font.family: root.sans; font.pixelSize: 13; font.weight: Font.DemiBold
                                                            elide: Text.ElideRight; Layout.fillWidth: true
                                                        }
                                                        Pill { text: (modelData.count || 0) + " apps"; tone: root.theme.textMuted }
                                                    }
                                                    RowLayout {
                                                        Layout.fillWidth: true
                                                        spacing: 6
                                                        Btn {
                                                            text: "Rename"
                                                            Layout.fillWidth: true
                                                            Layout.preferredWidth: 0
                                                            Layout.minimumWidth: 0
                                                            enabled: !root.busy
                                                            onClicked: {
                                                                root.renamingCategory = modelData.id;
                                                                renameWebCategoryField.text = modelData.label;
                                                                renameWebCategoryField.forceInput();
                                                            }
                                                        }
                                                        Btn {
                                                            text: "Remove"
                                                            danger: true
                                                            Layout.fillWidth: true
                                                            Layout.preferredWidth: 0
                                                            Layout.minimumWidth: 0
                                                            enabled: !root.busy
                                                            onClicked: root.runCmd("Removing category " + modelData.label,
                                                                                   ["aequalyn-webapp", "category-remove", modelData.id])
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    RowLayout {
                                        visible: root.renamingCategory !== ""
                                        spacing: 8
                                        Field {
                                            id: renameWebCategoryField
                                            placeholder: "New name"
                                            onAccepted: root.renameWebCategory(root.renamingCategory, renameWebCategoryField.text)
                                        }
                                        Btn {
                                            text: "Save"
                                            primary: true
                                            enabled: !root.busy && renameWebCategoryField.text.trim() !== ""
                                            onClicked: root.renameWebCategory(root.renamingCategory, renameWebCategoryField.text)
                                        }
                                        Btn { text: "Cancel"; onClicked: root.renamingCategory = "" }
                                    }
                                }
                                Box {
                                    visible: root.section === "web"
                                    title: "Add a web app"
                                    hint: "Name it as it should appear in the launcher, then the address, and a category if you like. Use one of the names in Categories below, or leave it empty. The icon comes from the site when it can."
                                    RowLayout {
                                        spacing: 8
                                        Field { id: webName; placeholder: "Reddit" }
                                        Field { id: webUrl; placeholder: "https://www.reddit.com/" }
                                        Field { id: webCat; Layout.preferredWidth: 170; Layout.fillWidth: false; placeholder: "category (optional)" }
                                    }
                                    Btn {
                                        text: "Add"
                                        primary: true
                                        enabled: !root.busy && webName.text.trim() !== "" && webUrl.text.trim() !== ""
                                        onClicked: {
                                            const cat = webCat.text.trim();
                                            root.runCmd("Adding " + webName.text.trim(),
                                                        ["aequalyn-webapp", "add", "--name", webName.text.trim(),
                                                         "--url", webUrl.text.trim()].concat(cat !== "" ? ["--category", cat] : []));
                                            webName.text = ""; webUrl.text = ""; webCat.text = "";
                                        }
                                    }
                                }
                                Box {
                                    visible: root.section === "web"
                                    title: "Browser"
                                    hint: "Chromium-based browsers open a web app as its own app window. Firefox-based browsers use a separate profile with the browser chrome hidden, so the window reads as an app too."
                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: 8
                                        Repeater {
                                            model: root.section === "web" ? root.webBrowsers : []
                                            delegate: Btn {
                                                required property var modelData
                                                text: modelData.label
                                                primary: modelData.id === root.webBrowser
                                                enabled: !root.busy && modelData.available
                                                onClicked: root.runCmd("Opening web apps with " + modelData.label,
                                                                       ["aequalyn-webapp", "set-browser", modelData.id])
                                            }
                                        }
                                    }
                                }

                                // AI lives here: desktop apps from the AI catalogue use
                                // the All Apps cards, and the coding agents keep their
                                // own lifecycle in the same card shape.
                                Box {
                                    visible: root.section === "ai"
                                    title: "AI apps"
                                    hint: "Desktop AI apps from the same catalogue as All Apps. The agents below are command-line tools with their own update and remove actions."
                                    BrowseCards {
                                        model: root.aiAppResults()
                                        page: root.aiAppPage
                                        onGoToPage: value => root.aiAppPage = value
                                    }
                                    Text {
                                        visible: root.aiAppResults().length === 0
                                        text: "No AI apps in the catalogue yet."
                                        color: root.theme.textMuted; font.family: root.sans; font.pixelSize: 11
                                    }
                                }
                                // AI tools: the coding agents, in the same 5x3 card grid
                                Box {
                                    visible: root.section === "ai"
                                    title: "Coding agents"
                                    hint: "Open launches the agent in a terminal. Tools installed by Arch or a system-wide npm package can be updated and removed here too; those need sudo. Sign-in stays with each provider."
                                    Repeater {
                                        model: root.section === "ai" ? root.aiRows() : []
                                        delegate: RowLayout {
                                            id: aiRow
                                            required property var modelData
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 150
                                            spacing: 10
                                            Repeater {
                                                model: aiRow.modelData
                                                delegate: AiCard {
                                                    Layout.fillWidth: true
                                                    Layout.preferredWidth: 203
                                                    onOpened: root.openAiApp(modelData)
                                                    onOpenRequested: root.aiLaunch(modelData.command)
                                                    onInstallRequested: root.runCmd("Installing " + (modelData.name || modelData.id),
                                                                                   ["aequalyn-ai-tool", "install", modelData.id])
                                                    onUpdateRequested: {
                                                        if (modelData.systemManager)
                                                            root.aiSystemAction(modelData, "update");
                                                        else
                                                            root.runCmd("Updating " + (modelData.name || modelData.id),
                                                                        ["aequalyn-ai-tool", "update", modelData.id]);
                                                    }
                                                    onRemoveRequested: {
                                                        if (modelData.systemManager)
                                                            root.aiSystemAction(modelData, "remove");
                                                        else
                                                            root.runCmd("Removing " + (modelData.name || modelData.id),
                                                                        ["aequalyn-ai-tool", "remove", modelData.id]);
                                                    }
                                                }
                                            }
                                            Repeater {
                                                model: 5 - aiRow.modelData.length
                                                delegate: Item { Layout.fillWidth: true; Layout.preferredWidth: 203 }
                                            }
                                        }
                                    }
                                    RowLayout {
                                        visible: root.aiTools.length > root.aiPerPage
                                        spacing: 6
                                        Item { Layout.fillWidth: true }
                                        Text {
                                            text: root.aiTools.length + (root.aiTools.length === 1 ? " tool" : " tools")
                                            color: root.theme.textMuted; font.family: root.mono; font.pixelSize: 11
                                        }
                                        StepBtn {
                                            glyph: "‹"
                                            enabled: root.aiAt > 0
                                            onClicked: root.aiPage = root.aiAt / root.aiPerPage - 1
                                        }
                                        Text {
                                            text: (root.aiAt + 1) + "–" + Math.min(root.aiAt + root.aiPerPage, root.aiTools.length)
                                                  + " of " + root.aiTools.length
                                            color: root.theme.textMuted; font.family: root.mono; font.pixelSize: 11
                                        }
                                        StepBtn {
                                            glyph: "›"
                                            enabled: root.aiAt + root.aiPerPage < root.aiTools.length
                                            onClicked: root.aiPage = root.aiAt / root.aiPerPage + 1
                                        }
                                    }
                                    Text {
                                        visible: root.aiTools.length === 0 && root.aiError === ""
                                        text: "Reading the AI tool list…"
                                        color: root.theme.textMuted; font.family: root.sans; font.pixelSize: 11
                                    }
                                    Text {
                                        visible: root.aiError !== ""
                                        text: root.aiError
                                        color: root.theme.accentOrange; font.family: root.sans; font.pixelSize: 11
                                        Layout.fillWidth: true
                                    }
                                }

                                // AppImages: what is imported, the form, and the default handler
                                Box {
                                    visible: root.section === "appimage"
                                    title: "Imported"
                                    hint: root.importedApps.length === 0
                                          ? "No AppImages imported yet. One file is the whole app: check one below, or open it in your file manager."
                                          : "Remove takes one out of the launcher and out of this list. Its file is kept where it is, never deleted: delete it yourself when you truly want it gone."
                                    // a few: the plain list; more: cards, six to a page
                                    Repeater {
                                        visible: root.importedApps.length <= 5
                                        model: root.section === "appimage" && root.importedApps.length <= 5 ? root.importedApps : []
                                        delegate: ItemRow {}
                                    }
                                    // five to a row (a RowLayout shares its width out,
                                    // a positioner's own children never size it), three
                                    // rows to a page
                                    Repeater {
                                        visible: root.importedApps.length > 5
                                        model: root.section === "appimage" && root.importedApps.length > 5
                                               ? root.importedRows() : []
                                        delegate: RowLayout {
                                            id: cardRow
                                            required property var modelData
                                            Layout.fillWidth: true
                                            // an all-ghost row keeps the card height, so the page
                                            // holds its 5x3 shape even when nothing is in it
                                            Layout.preferredHeight: 150
                                            spacing: 10
                                            Repeater {
                                                model: cardRow.modelData
                                                delegate: AppCard {
                                                    Layout.fillWidth: true
                                                    Layout.preferredWidth: 203
                                                    onOpenRequested: Quickshell.execDetached([modelData.path])
                                                    onRemoveRequested: root.runJob("Removing " + modelData.id, ["remove", "appimage", modelData.id])
                                                }
                                            }
                                            // the row keeps all five of its slots, each the same
                                            // preferred width so the fifths come out equal: what the
                                            // page does not show holds a fifth unseen, and a short
                                            // page sits its cards top-left instead of stretching them
                                            Repeater {
                                                model: 5 - cardRow.modelData.length
                                                delegate: Item { Layout.fillWidth: true; Layout.preferredWidth: 203 }
                                            }
                                        }
                                    }
                                    // the pages of cards, ‹ and › to walk them
                                    RowLayout {
                                        visible: root.importedApps.length > root.importedPerPage
                                        spacing: 6
                                        Item { Layout.fillWidth: true }
                                        Text {
                                            text: root.importedApps.length + (root.importedApps.length === 1 ? " app" : " apps")
                                            color: root.theme.textMuted; font.family: root.mono; font.pixelSize: 11
                                        }
                                        StepBtn {
                                            glyph: "‹"
                                            enabled: root.importedAt > 0
                                            // walk from the page actually shown, never from a stored
                                            // out-of-range value (the jump after an import leaves one)
                                            onClicked: root.importedPage = root.importedAt / root.importedPerPage - 1
                                        }
                                        Text {
                                            text: (root.importedAt + 1) + "–" + Math.min(root.importedAt + root.importedPerPage, root.importedApps.length)
                                                  + " of " + root.importedApps.length
                                            color: root.theme.textMuted; font.family: root.mono; font.pixelSize: 11
                                        }
                                        StepBtn {
                                            glyph: "›"
                                            enabled: root.importedAt + root.importedPerPage < root.importedApps.length
                                            onClicked: root.importedPage = root.importedAt / root.importedPerPage + 1
                                        }
                                    }
                                }
                                Box {
                                    visible: root.section === "appimage"
                                    title: "Import an AppImage"
                                    RowLayout {
                                        spacing: 8
                                        Field {
                                            id: appField
                                            placeholder: "~/Downloads/Something.AppImage   (an .AppImage opened in your file manager lands here)"
                                            onAccepted: root.importField()
                                        }
                                        Btn {
                                            text: "Check"
                                            enabled: !root.busy && appField.text.trim() !== ""
                                            onClicked: root.runJob("Checking " + appField.text.trim(), ["check-appimage", appField.text.trim()])
                                        }
                                        Btn {
                                            text: "Import"
                                            primary: true
                                            enabled: !root.busy
                                            onClicked: root.pickBegin()
                                        }
                                    }
                                    Text {
                                        visible: root.appimageHandler !== "ours"
                                        text: "Opening .AppImage files here instead of asking every time: make the Store their default handler below."
                                        color: root.theme.textMuted; font.family: root.sans; font.pixelSize: 11; Layout.fillWidth: true
                                    }
                                }
                                Box {
                                    visible: root.section === "appimage"
                                    title: "The default .AppImage handler"
                                    RowLayout {
                                        spacing: 8
                                        Pill {
                                            visible: root.appimageHandler !== "unknown"
                                            text: root.appimageHandler === "ours" ? "Default handler"
                                                : root.appimageHandler === "none" ? "No default set" : "Another handler"
                                            tone: root.appimageHandler === "ours" ? root.theme.accentGreen
                                                : root.appimageHandler === "none" ? root.theme.textMuted : root.theme.accentOrange
                                        }
                                        Item { Layout.fillWidth: true }
                                        Btn {
                                            text: root.appimageHandler === "ours" ? "Set again" : "Make the Store the default"
                                            primary: root.appimageHandler !== "ours"
                                            enabled: !root.busy
                                            onClicked: root.runJob("Becoming the default AppImage handler", ["set-appimage-handler"])
                                        }
                                    }
                                }

                                // Market: the catalog, every item pinned to the commit (an AppImage: the
                                // sha256 of the exact file) that was checked
                                Box {
                                    visible: root.section === "market"
                                    title: "The Market"
                                    hint: root.market.length > 0
                                        ? "Published by others, reviewed, and installed at the exact commit that was checked. AppImages too: each pinned by the sha256 of the exact file."
                                        : root.marketLoaded ? "The catalog is empty for now. Publish yours: github.com/Aequalyn/aequalyn-market."
                                        : "The catalog could not be read yet (it is fetched from github.com/Aequalyn/aequalyn-market). Install from a git URL on each section's page meanwhile: the same checks run."
                                    Btn {
                                        text: "Refresh the catalog"
                                        enabled: !root.busy
                                        onClicked: root.runJob("Refreshing the catalog", ["refresh"])
                                    }
                                    Repeater {
                                        model: root.section === "market" ? root.market : []
                                        delegate: Rectangle {
                                            id: mrow
                                            required property var modelData
                                            Layout.fillWidth: true
                                            implicitHeight: mcol.implicitHeight + 20
                                            radius: 10
                                            color: root.theme.bgBase
                                            RowLayout {
                                                id: mcol
                                                anchors.fill: parent
                                                anchors.margins: 10
                                                spacing: 10
                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 2
                                                    RowLayout {
                                                        spacing: 8
                                                        Text { text: mrow.modelData.name || mrow.modelData.id; color: root.theme.textPrimary; font.family: root.sans; font.pixelSize: 13; font.weight: Font.DemiBold }
                                                        Pill { text: mrow.modelData.kind; tone: root.theme.accentPrimary }
                                                        Pill {
                                                            visible: mrow.modelData.state !== "not installed"
                                                            text: mrow.modelData.state === "installed" ? "Installed"
                                                                : mrow.modelData.state === "another installed" ? "Installed from elsewhere" : "Update available"
                                                            tone: mrow.modelData.state === "installed" ? root.theme.accentGreen : root.theme.accentOrange
                                                        }
                                                    }
                                                    Text { text: mrow.modelData.about || ""; color: root.theme.textSecondary; font.family: root.sans; font.pixelSize: 11; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                                                    Text {
                                                        text: (mrow.modelData.by ? "by " + mrow.modelData.by + "  ·  " : "") + String(mrow.modelData.commit || "").slice(0, 12)
                                                              + (mrow.modelData.license ? "  ·  " + mrow.modelData.license : "") + "  ·  " + (mrow.modelData.repo || "")
                                                        color: root.theme.textMuted; font.family: root.mono; font.pixelSize: 10; elide: Text.ElideMiddle; Layout.fillWidth: true
                                                    }
                                                }
                                                Btn {
                                                    visible: mrow.modelData.state !== "installed" && mrow.modelData.state !== "another installed"
                                                    text: mrow.modelData.state === "update available" ? "Update" : "Install"
                                                    primary: true
                                                    enabled: !root.busy
                                                    onClicked: root.installFromMarket(mrow.modelData.kind, { id: mrow.modelData.id, label: mrow.modelData.name })
                                                }
                                            }
                                        }
                                    }
                                }

                                // Updates: what came from git, newest commit fetched and checked
                                // again. AppImages are not here -- one file, no source to fetch;
                                // their own page manages them.
                                Box {
                                    visible: root.section === "updates"
                                    title: "Updates"
                                    hint: root.updatable.length === 0 ? "Nothing that updates from git yet."
                                        : "Update fetches the newest commit of each source and runs every check again; a source that fails keeps what you have."
                                    Btn {
                                        visible: root.updatable.length > 0
                                        text: "Update all " + root.updatable.length
                                        primary: true
                                        enabled: !root.busy
                                        onClicked: root.runJob("Updating everything", ["update-all"])
                                    }
                                    Repeater {
                                        model: root.section === "updates" ? root.updatable : []
                                        delegate: ItemRow {}
                                    }
                                }
                            }
                        }

                        // the report
                        Rectangle {
                            visible: root.jobTitle !== ""
                            Layout.fillWidth: true
                            Layout.preferredHeight: 170
                            radius: 6
                            color: Cc.alpha(root.theme.textPrimary, 0.03)
                            Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: Cc.alpha(root.theme.textPrimary, 0.08) }
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 6
                                RowLayout {
                                    Text {
                                        text: root.jobTitle
                                        color: root.theme.textPrimary; font.family: root.sans; font.pixelSize: 12; font.weight: Font.DemiBold
                                        elide: Text.ElideMiddle; Layout.fillWidth: true
                                    }
                                    Pill {
                                        visible: root.busy
                                        text: "Running"
                                        tone: root.theme.accentOrange
                                    }
                                    Pill {
                                        visible: !root.busy && root.jobCode !== 0
                                        text: "Failed"
                                        tone: root.theme.accentRed
                                    }
                                    Btn {
                                        // the report closes when the job is through: Done, or Close on a failure
                                        visible: !root.busy
                                        text: root.jobCode === 0 ? "Done" : "Close"
                                        primary: root.jobCode === 0
                                        implicitHeight: 26
                                        onClicked: root.jobTitle = ""
                                    }
                                }
                                ListView {
                                    id: logView
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    clip: true
                                    model: logModel
                                    onCountChanged: positionViewAtEnd()
                                    delegate: Text {
                                        required property string line
                                        width: logView.width
                                        text: line
                                        textFormat: Text.PlainText
                                        wrapMode: Text.WrapAnywhere
                                        color: line.startsWith("FAIL") ? root.theme.accentRed : line.startsWith("OK") ? root.theme.accentGreen : root.theme.textSecondary
                                        font.family: root.mono
                                        font.pixelSize: 11
                                    }
                                }
                            }
                        }
                    }
                }

                // the footer, as the control center's: the keys on the left, the
                // one thing worth remembering on the right
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    color: "transparent"
                    Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: root.theme.bgBorder }
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.queryActive
                            ? "↑ ↓  move     ⏎  open or change     tab  filter     esc  clear"
                            : root.appPage ? "esc  back to the previous page" : "↑ ↓  move     ← →  rail / list     esc  close"
                        color: root.theme.textMuted
                        font.family: root.mono
                        font.pixelSize: 10
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Nothing is kept that has not been checked"
                        color: root.theme.textMuted
                        font.family: root.sans
                        font.pixelSize: 11
                    }
                }

            }
            // ---- the search: every match, in place of the page -------------------------
            // the control center's results view: the rail stays, the page becomes a
            // list of what matched, with a source chip and keys to move and install
            Rectangle {
                id: resultsView
                visible: root.queryActive
                // past the rail (6 + 96) and its hairline, below the title (68 + 1)
                anchors.left: parent.left
                anchors.leftMargin: 103
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 69
                anchors.bottom: parent.bottom
                color: root.theme.bgBase
                z: 20
                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 30
                    anchors.rightMargin: 22
                    anchors.topMargin: 18
                    anchors.bottomMargin: 8
                    spacing: 10

                    Flow {
                        Layout.fillWidth: true
                        spacing: 6
                        Repeater {
                            model: root.resultSources
                            delegate: Rectangle {
                                id: chip
                                required property var modelData
                                readonly property int n: root.resultCount(modelData)
                                readonly property bool on: root.querySource === modelData
                                visible: modelData === "All" || n > 0 || on
                                width: chipText.implicitWidth + 20
                                height: 28
                                radius: 8
                                color: chip.on ? root.theme.bgSelected
                                    : chipMa.containsMouse ? root.theme.bgHover : root.theme.bgSurface
                                border.width: 1
                                border.color: chip.on ? root.theme.accentPrimary : root.theme.bgBorder
                                Text {
                                    id: chipText
                                    anchors.centerIn: parent
                                    text: root.resultLabel(chip.modelData) + "  " + chip.n
                                    color: chip.on ? root.theme.accentPrimary : root.theme.textSecondary
                                    font.family: root.mono
                                    font.pixelSize: 11
                                }
                                MouseArea {
                                    id: chipMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { root.setQuerySource(chip.modelData); titleSearch.forceActiveFocus(); }
                                }
                            }
                        }
                    }
                    Text {
                        text: root.searching ? "Searching…"
                            : root.resultShown.length + (root.resultShown.length === 1 ? " result" : " results")
                        color: root.theme.textMuted
                        font.family: root.mono
                        font.pixelSize: 11
                    }
                    Text {
                        visible: !root.searching && root.resultShown.length === 0
                        Layout.fillWidth: true
                        text: "Nothing matches “" + root.query.trim() + "”. Try another app name or a setting, like “dark”."
                        color: root.theme.textMuted
                        font.family: root.sans
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                    }
                    ListView {
                        id: resultList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 2
                        model: root.resultShown
                        currentIndex: root.pick
                        highlightMoveDuration: 120
                        boundsBehavior: Flickable.StopAtBounds
                        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                        highlight: Rectangle {
                            radius: 8
                            color: root.theme.bgSelected
                            Rectangle {
                                width: 3; height: 24; radius: 2
                                anchors.left: parent.left
                                anchors.leftMargin: 2
                                anchors.verticalCenter: parent.verticalCenter
                                color: root.theme.accentPrimary
                            }
                        }
                        delegate: Item {
                            id: res
                            required property var modelData
                            required property int index
                            readonly property bool isApp: res.modelData.kind === "app"
                            readonly property bool isInstall: res.modelData.kind === "install"
                            readonly property var io: res.isInstall ? res.modelData.option : null
                            readonly property var removeCmd: res.io ? InstallOptions.uninstall(res.io) : []
                            readonly property var g: res.isApp ? res.modelData.group : null
                            readonly property var sr: res.isApp || res.isInstall ? null : res.modelData.result
                            readonly property var e: res.sr ? res.sr.entry : null
                            readonly property bool editable: !!res.e && !!res.e.setting
                            readonly property bool have: res.isApp && !!res.g.installed
                            readonly property var via: res.isApp ? root.preferredSource(res.g) : null
                            readonly property bool on: root.pick === res.index
                            width: resultList.width
                            height: 54
                            MouseArea {
                                anchors.fill: parent
                                z: 1
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPositionChanged: root.pick = res.index
                                onClicked: { root.pick = res.index; root.activateResult(res.modelData); }
                            }
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 12
                                spacing: 12
                                Image {
                                    visible: res.isApp
                                    Layout.preferredWidth: 28; Layout.preferredHeight: 28
                                    source: res.g ? res.g.icon : ""
                                    sourceSize.width: 56; sourceSize.height: 56
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                }
                                Text {
                                    visible: !res.isApp
                                    Layout.preferredWidth: 28
                                    horizontalAlignment: Text.AlignHCenter
                                    text: res.isInstall ? (res.io ? res.io.icon : "") : (res.sr ? res.sr.icon : "")
                                    color: root.theme.accentPrimary
                                    font.family: root.mono
                                    font.pixelSize: 16
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    Text {
                                        text: res.isApp ? (res.g ? res.g.name : "")
                                            : res.isInstall ? (res.io ? res.io.label : "")
                                            : (res.sr ? res.sr.label : "")
                                        color: res.on ? root.theme.textPrimary : root.theme.textSecondary
                                        font.family: root.sans
                                        font.pixelSize: 13
                                        font.weight: res.on ? Font.DemiBold : Font.Normal
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        text: res.isApp
                                            ? (res.g ? res.g.sources.map(s => s.source === "Flatpak" ? "Flathub" : s.source).join(", ") : "")
                                                + (res.g && res.g.about ? "  ·  " + res.g.about : "")
                                            : res.isInstall
                                            ? (res.io ? InstallOptions.categoryLabel(res.io.category) + " · " + res.io.source : "")
                                            : (res.sr ? res.sr.where : "")
                                        color: root.theme.textMuted
                                        font.family: root.mono
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }
                                Pill {
                                    visible: res.have
                                    z: 2
                                    text: "Installed"
                                    tone: root.theme.accentGreen
                                }
                                Btn {
                                    visible: res.isInstall && res.removeCmd.length > 0
                                    z: 2
                                    text: "Remove"
                                    danger: true
                                    enabled: !root.busy
                                    onClicked: root.installRemove(res.io)
                                }
                                Btn {
                                    visible: (res.isApp && !res.have && !!res.via) || res.isInstall
                                    z: 2
                                    text: "Install"
                                    primary: true
                                    enabled: !res.isInstall || !root.busy
                                    onClicked: {
                                        if (res.isInstall) root.installActivate(res.io);
                                        else root.installFound(res.via);
                                    }
                                }
                                CcSwitch {
                                    visible: res.editable && res.e && res.e.kind === "toggle"
                                    z: 2
                                    checked: res.e ? !!AequalynSettings[res.e.setting] : false
                                    onToggled: v => { if (res.e) AequalynSettings.apply(res.e.setting, v); }
                                }
                                RowLayout {
                                    visible: res.editable && res.e && res.e.kind !== "toggle"
                                    z: 2
                                    spacing: 6
                                    StepBtn { glyph: "‹"; onClicked: { if (res.e) root.adjustSetting(res.e, -1); } }
                                    Text {
                                        Layout.preferredWidth: 120
                                        horizontalAlignment: Text.AlignHCenter
                                        text: root.settingValue(res.e)
                                        color: root.theme.accentPrimary
                                        font.family: root.mono
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                    }
                                    StepBtn { glyph: "›"; onClicked: { if (res.e) root.adjustSetting(res.e, 1); } }
                                }
                                Text {
                                    visible: !res.isApp && !res.isInstall && !res.editable
                                    text: "Open  ›"
                                    color: res.on ? root.theme.accentPrimary : root.theme.textMuted
                                    font.family: root.mono
                                    font.pixelSize: 11
                                }
                                Text {
                                    visible: res.have
                                    text: "Open  ›"
                                    color: res.on ? root.theme.accentPrimary : root.theme.textMuted
                                    font.family: root.mono
                                    font.pixelSize: 11
                                }
                            }
                        }
                    }
                }
            }
            // ---- one app, one whole page ---------------------------------------------------
            // Back returns to the exact page or search results this came from. Everything
            // fits at once: information on the left, every way to install on the right.
            Rectangle {
                id: appView
                visible: root.appPage !== null
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 69
                anchors.bottom: parent.bottom
                color: root.theme.bgBase
                z: 30
                MouseArea { anchors.fill: parent }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 28
                    anchors.rightMargin: 28
                    anchors.topMargin: 18
                    anchors.bottomMargin: 18
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 66
                        spacing: 14
                        Btn { text: "‹ Back"; onClicked: root.backFromApp() }
                        Item {
                            Layout.preferredWidth: 50; Layout.preferredHeight: 50
                            Rectangle {
                                anchors.fill: parent
                                radius: 10
                                color: root.appMonogramColor(root.appPage ? root.appPage.name : "app")
                                visible: pageIcon.status !== Image.Ready
                                Text {
                                    anchors.centerIn: parent
                                    text: root.appInitials(root.appPage ? root.appPage.name : "app")
                                    color: "#ffffff"
                                    font.family: root.sans
                                    font.pixelSize: 17
                                    font.weight: Font.DemiBold
                                }
                            }
                            Image {
                                id: pageIcon
                                anchors.fill: parent
                                source: root.appPage ? root.appIconUrl(root.appPage.icon, root.appPage.name) : ""
                                sourceSize.width: 100; sourceSize.height: 100
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                visible: status === Image.Ready
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                Layout.fillWidth: true
                                text: root.appPage ? root.appPage.name : ""
                                color: root.theme.textPrimary
                                font.family: root.sans
                                font.pixelSize: 20
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: (root.appDetail && root.appDetail.about) || (root.appPage ? root.appPage.about : "")
                                color: root.theme.textMuted
                                font.family: root.sans
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                        }
                        Pill {
                            visible: !!root.appPage && !!root.appPage.installed
                            text: "Installed"
                            tone: root.theme.accentGreen
                        }
                        Text {
                            text: root.appDetailBusy ? "Fetching details…"
                                : root.detailSources().length + (root.detailSources().length === 1 ? " source" : " sources")
                            color: root.appDetailBusy ? root.theme.accentCyan : root.theme.textMuted
                            font.family: root.mono
                            font.pixelSize: 11
                        }
                    }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: root.theme.bgBorder }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 20

                        // the left side: what the app is, in one calm block
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 10
                            Text {
                                text: "About this app"
                                color: root.theme.textPrimary
                                font.family: root.sans
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 172
                                radius: 6
                                color: root.theme.bgSurface
                                border.width: 1
                                border.color: root.theme.bgBorder
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 14
                                    spacing: 8
                                    Text {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        text: (root.appDetail && root.appDetail.description) || (root.appPage ? root.appPage.about : "")
                                        color: root.theme.textSecondary
                                        font.family: root.sans
                                        font.pixelSize: 12
                                        wrapMode: Text.WordWrap
                                        elide: Text.ElideRight
                                    }
                                    Flow {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 88
                                        Layout.maximumHeight: 88
                                        visible: !!(root.appDetail && root.appDetail.screenshots && root.appDetail.screenshots.length > 0)
                                        spacing: 8
                                        clip: true
                                        Repeater {
                                            model: root.appDetail && root.appDetail.screenshots ? root.appDetail.screenshots.slice(0, 3) : []
                                            delegate: Rectangle {
                                                required property var modelData
                                                width: 148; height: 88
                                                radius: 8
                                                color: root.theme.bgBase
                                                clip: true
                                                Image {
                                                    anchors.fill: parent
                                                    source: modelData
                                                    sourceSize.width: 296; sourceSize.height: 176
                                                    fillMode: Image.PreserveAspectCrop
                                                    asynchronous: true
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            Text {
                                text: "At a glance"
                                color: root.theme.textPrimary
                                font.family: root.sans
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                Layout.topMargin: 4
                            }
                            GridLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                columns: 2
                                rowSpacing: 4
                                columnSpacing: 18
                                Repeater {
                                    model: root.appFacts()
                                    delegate: RowLayout {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 26
                                        spacing: 8
                                        Text {
                                            Layout.preferredWidth: 88
                                            text: modelData.label || ""
                                            color: root.theme.textMuted
                                            font.family: root.mono
                                            font.pixelSize: 10
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.value || ""
                                            color: root.theme.textSecondary
                                            font.family: root.mono
                                            font.pixelSize: 10
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }
                        }

                        // the right side: one card per manager that can install it
                        ColumnLayout {
                            Layout.preferredWidth: 430
                            Layout.fillHeight: true
                            spacing: 10
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    Layout.fillWidth: true
                                    text: "Ways to install"
                                    color: root.theme.textPrimary
                                    font.family: root.sans
                                    font.pixelSize: 14
                                    font.weight: Font.DemiBold
                                }
                                Text {
                                    text: root.detailSources().length + " available"
                                    color: root.theme.textMuted
                                    font.family: root.mono
                                    font.pixelSize: 10
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 8
                                Repeater {
                                    model: root.detailSources()
                                    delegate: Rectangle {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        Layout.minimumHeight: 150
                                        radius: 6
                                        color: root.theme.bgSurface
                                        border.width: 1
                                        border.color: root.theme.bgBorder
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 14
                                            spacing: 16

                                            ColumnLayout {
                                                Layout.preferredWidth: 190
                                                Layout.fillHeight: true
                                                spacing: 5
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: modelData.source === "Flatpak" ? "Flathub" : (modelData.source || "")
                                                    color: root.theme.accentPrimary
                                                    font.family: root.mono
                                                    font.pixelSize: 14
                                                    font.weight: Font.DemiBold
                                                    elide: Text.ElideRight
                                                }
                                                Rectangle {
                                                    Layout.preferredWidth: 44
                                                    Layout.preferredHeight: 3
                                                    radius: 2
                                                    color: root.theme.accentPrimary
                                                }
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: "version " + (modelData.version || "unknown")
                                                    color: root.theme.textSecondary
                                                    font.family: root.mono
                                                    font.pixelSize: 11
                                                    wrapMode: Text.WordWrap
                                                }
                                                Pill {
                                                    visible: !!modelData.installed
                                                    text: "Installed"
                                                    tone: root.theme.accentGreen
                                                }
                                                Text {
                                                    Layout.fillWidth: true
                                                    Layout.topMargin: 2
                                                    text: modelData.about || ""
                                                    color: root.theme.textMuted
                                                    font.family: root.sans
                                                    font.pixelSize: 10
                                                    wrapMode: Text.WordWrap
                                                    maximumLineCount: 4
                                                    elide: Text.ElideRight
                                                }
                                                Item { Layout.fillHeight: true }
                                            }

                                            Rectangle {
                                                Layout.preferredWidth: 1
                                                Layout.fillHeight: true
                                                color: root.theme.bgBorder
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                Layout.fillHeight: true
                                                spacing: 6
                                                GridLayout {
                                                    Layout.fillWidth: true
                                                    columns: 2
                                                    rowSpacing: 4
                                                    columnSpacing: 16
                                                    Repeater {
                                                        model: root.sourceDetails(modelData)
                                                        delegate: RowLayout {
                                                            required property var modelData
                                                            Layout.fillWidth: true
                                                            Layout.preferredHeight: 18
                                                            spacing: 6
                                                            Text {
                                                                Layout.preferredWidth: 78
                                                                text: modelData.label || ""
                                                                color: root.theme.textMuted
                                                                font.family: root.mono
                                                                font.pixelSize: 9
                                                                elide: Text.ElideRight
                                                            }
                                                            Text {
                                                                Layout.fillWidth: true
                                                                text: modelData.value || ""
                                                                color: root.theme.textSecondary
                                                                font.family: root.mono
                                                                font.pixelSize: 10
                                                                elide: Text.ElideRight
                                                            }
                                                        }
                                                    }
                                                }
                                                Item { Layout.fillHeight: true; Layout.minimumHeight: 0 }
                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 8
                                                    Btn {
                                                        visible: !modelData.installed
                                                        Layout.fillWidth: true
                                                        implicitHeight: 30
                                                        text: "Install"
                                                        primary: true
                                                        onClicked: root.installFound(modelData)
                                                    }
                                                    Btn {
                                                        visible: !!modelData.installed
                                                        Layout.fillWidth: true
                                                        implicitHeight: 30
                                                        text: "Update"
                                                        onClicked: root.appAction(modelData, "update")
                                                    }
                                                    Btn {
                                                        visible: !!modelData.installed
                                                        Layout.fillWidth: true
                                                        implicitHeight: 30
                                                        text: "Remove"
                                                        danger: true
                                                        onClicked: root.appAction(modelData, "remove")
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: root.detailErrorText !== ""
                                text: "Not reached: " + root.detailErrorText
                                color: root.theme.accentRed
                                font.family: root.mono
                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
            // the picker, drawn inside this window: a layer-shell panel sits over
            // every normal window, so the desktop's own dialog cannot be seen above
            // it -- this one is part of the panel, over the page, under nothing
            Rectangle {
                visible: root.pickOpen
                anchors.fill: parent
                z: 10
                color: root.theme.bgBase
                Accessible.role: Accessible.Dialog
                Accessible.name: "Pick an AppImage"
                MouseArea { anchors.fill: parent }   // a click on the room around never leaves

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    // the head: what this is, and how to leave
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text {
                            text: "Pick an AppImage"
                            color: root.theme.textPrimary
                            font.family: root.sans; font.pixelSize: 14; font.weight: Font.DemiBold
                            Layout.fillWidth: true
                        }
                        Btn { text: "Cancel"; onClicked: root.pickOpen = false }
                    }
                    // where we are: the home, one up, the path
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Btn { text: "Home"; onClicked: root.pickNavigate(Quickshell.env("HOME")) }
                        Btn {
                            text: "Up"
                            enabled: root.pickDir !== "/"
                            onClicked: root.pickUp()
                        }
                        Text {
                            text: root.pickDir
                            color: root.theme.textSecondary
                            font.family: root.mono; font.pixelSize: 11
                            elide: Text.ElideMiddle
                            Layout.fillWidth: true
                        }
                    }
                    // the entries: folders to walk in, .AppImages to pick
                    ListView {
                        id: pickList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 2
                        model: root.pickEntries
                        boundsBehavior: Flickable.StopAtBounds
                        delegate: Rectangle {
                            id: entry
                            required property var modelData
                            width: pickList.width
                            implicitHeight: 38
                            radius: 8
                            color: entryMa.containsMouse ? root.theme.bgSelected : "transparent"
                            Accessible.role: Accessible.Button
                            Accessible.name: modelData.name
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 10
                                Text {
                                    text: entry.modelData.dir ? "\u{F0770}" : "\u{F01D4}"
                                    color: entry.modelData.dir ? root.theme.accentPrimary : root.theme.accentGreen
                                    font.family: root.mono; font.pixelSize: 15
                                }
                                Text {
                                    text: entry.modelData.name
                                    color: root.theme.textPrimary
                                    font.family: root.sans; font.pixelSize: 13
                                    elide: Text.ElideMiddle
                                    Layout.fillWidth: true
                                }
                                Pill { visible: !entry.modelData.dir; text: "AppImage"; tone: root.theme.accentPrimary }
                            }
                            MouseArea {
                                id: entryMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (entry.modelData.dir) {
                                        root.pickNavigate(root.pickChild(entry.modelData.name));
                                        return;
                                    }
                                    const file = root.pickChild(entry.modelData.name);
                                    root.pickOpen = false;
                                    appField.text = file;
                                    root.runJob("Importing " + file, ["import-appimage", file]);
                                }
                            }
                        }
                    }
                    Text {
                        visible: root.pickBusy
                        text: "Looking…"
                        color: root.theme.textMuted; font.family: root.sans; font.pixelSize: 11
                    }
                    Text {
                        visible: !root.pickBusy && root.pickEntries.length === 0
                        text: "No folders and no AppImages here."
                        color: root.theme.textMuted; font.family: root.sans; font.pixelSize: 11
                    }
                    Text {
                        visible: root.pickEntries.length > 0
                        text: "Click a folder to walk in, an AppImage to import it."
                        color: root.theme.textMuted; font.family: root.sans; font.pixelSize: 11
                    }
                }
            }
        }
    }
}
