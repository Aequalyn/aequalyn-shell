// The Store: plugins, themes, cursors, wallpaper packs and looks from git, every one
// checked before it is kept (bin/aequalyn-store does the work; this is its window);
// the way to search apps in Arch, the AUR, Flathub and Snap; web apps and AI tools
// (aequalyn-webapp and aequalyn-ai-tool do the work, the same live report shows it);
// and the way AppImages come in: checked without anything inside them ever running,
// moved to ~/Applications with a menu entry of their own. Super + Alt + S, or
// `qs ipc call store open` (`section <name>` opens it on a section,
// `install <kind> <git-url>` installs, `appimage <path>` brings one over).
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
import "root:/style/backdrop"
import "../../Plugins.js" as PluginRegistry
import "../../PluginInfo.js" as PluginInfo

Scope {
    id: root
    // the live palette, bound by the shell's PluginManager; the fallback is the one
    // every module uses, so the Store dresses like the control center on any theme
    property var theme: AequalynDefaultTheme {}
    // words in a plain sans, numbers, paths, keys and icons in the shell's mono
    readonly property string sans: "sans-serif"
    readonly property string mono: "JetBrainsMono Nerd Font"
    property bool open: false
    property string section: "home"

    readonly property var sections: [
        { key: "home",      label: "Home",       glyph: "\u{F02DC}" },
        { key: "plugin",    label: "Plugins",    glyph: "\u{F0431}" },
        { key: "theme",     label: "Themes",     glyph: "\u{F03D8}" },
        { key: "cursor",    label: "Cursors",    glyph: "\u{F01BE}" },
        { key: "wallpaper", label: "Wallpapers", glyph: "\u{F02E9}" },
        { key: "look",      label: "Looks",      glyph: "\u{F0E09}" },
        { key: "apps",      label: "Apps",       glyph: "\u{F003B}" },
        { key: "web",       label: "Web apps",   glyph: "\u{F0595}" },
        { key: "ai",        label: "AI tools",   glyph: "\u{F06A9}" },
        { key: "appimage",  label: "AppImages",  glyph: "\u{F01D4}" },
        { key: "market",    label: "Market",     glyph: "\u{F0110}" },
        { key: "updates",   label: "Updates",    glyph: "\u{F06B0}" }
    ]
    // the shell's own plugins, as the control center lists them; the control center
    // itself is left out because turning it off would lock you out
    readonly property var builtInPlugins: PluginRegistry.list.filter(p => p.id !== "settings")
    function builtInInfo(id) {
        // the registry's clipscape id and PluginInfo's clipboard key are one plugin
        return PluginInfo.of(id === "clipscape" ? "clipboard" : id);
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
    readonly property var updatable: root.installed.filter(i => i.kind !== "appimage")
    // the plugin grids hold fifteen tiles per page, in rows of five
    function pluginAt(count, page) {
        return Math.min(page, Math.max(0, Math.ceil(count / 15) - 1)) * 15;
    }
    function pluginRows(items, page) {
        const at = root.pluginAt(items.length, page);
        const shown = items.slice(at, at + 15);
        const rows = [];
        for (let i = 0; i < shown.length; i += 5) rows.push(shown.slice(i, i + 5));
        while (rows.length < 3) rows.push([]);
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

    // ---- apps: the curated grid (apps.json) and the four backends ----------------------
    // pacman always; yay (the AUR), flatpak (Flathub) and snap when they are installed.
    // Installs run in a terminal, where sudo asks for the password.
    property var apps: []
    // the popular grid, fifteen to a page like the cards everywhere else; each
    // card carries its own four install buttons, greyed where there is no build
    property int popPage: 0
    readonly property var popShown: root.apps
    readonly property int popAt: Math.min(root.popPage, Math.max(0, Math.ceil(root.popShown.length / 15) - 1)) * 15
    // the page's apps, as rows of five, the page always holding its three rows
    function popRows() {
        const shown = root.popShown.slice(root.popAt, root.popAt + 15);
        const rows = [];
        for (let i = 0; i < shown.length; i += 5) rows.push(shown.slice(i, i + 5));
        while (rows.length < 3) rows.push([]);
        return rows;
    }
    property var backends: ({ yay: false, flatpak: false, snap: false })
    property var installedPkgs: ({ pacman: [], flatpak: [], snap: [] })
    // explicitly installed packages from every backend; many are CLI tools, so
    // All apps' Installed filter shows them instead of a separate apps section
    property var installedApps: []
    property string installedQuery: ""
    readonly property var installedResults: root.installedApps
        .filter(a => root.installedQuery === "" ||
                     (a.name + " " + a.id).toLowerCase().indexOf(root.installedQuery.toLowerCase()) >= 0)
        .map(a => ({ source: a.source, id: a.id, name: a.name, version: a.version,
                     about: a.version !== "" ? "Version " + a.version : "Installed",
                     icon: "", installed: true }))
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
    // a command in a terminal, kept open at the end so its output can be read
    Process {
        id: terminal
        onExited: root.detectApps()
    }
    function inTerminal(cmd) {
        if (terminal.running) return;
        const tail = cmd + '; echo; read -rp "Done. Press Enter to close " _';
        terminal.command = ["sh", "-c", 'if command -v kitty >/dev/null; then exec kitty sh -c "$1"; '
            + 'elif command -v foot >/dev/null; then exec foot sh -c "$1"; else exec alacritty -e sh -c "$1"; fi', "sh", tail];
        terminal.running = true;
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
    readonly property var foundShown: root.foundSource === "Installed"
        ? root.installedResults
        : root.found.filter(r => root.foundSource === "All" || r.source === root.foundSource)
    // the page's found apps, as rows of five, the page always holding its three rows
    function foundRows() {
        const shown = root.foundShown.slice(root.foundAt, root.foundAt + root.foundStep);
        const rows = [];
        for (let i = 0; i < shown.length; i += 5) rows.push(shown.slice(i, i + 5));
        while (rows.length < 3) rows.push([]);
        return rows;
    }
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
        if (via === "Arch") root.inTerminal("sudo pacman -S --needed " + a.pacman);
        else if (via === "AUR") root.inTerminal("yay -S --needed " + a.aur);
        else if (via === "Flatpak") root.inTerminal(root.flathub + " && flatpak install --user -y flathub " + a.flatpak);
        else if (via === "Snap") root.inTerminal("sudo snap install " + a.snap + (a.snapClassic ? " --classic" : ""));
    }
    // Installed filter: the matching update or remove command in a terminal, where
    // sudo can ask. Only the plain id from the package manager reaches the shell.
    function appAction(r, action) {
        const id = r.id;
        if (!/^[A-Za-z0-9@._+-]{1,128}$/.test(id)) return;
        if (r.source === "Arch")
            root.inTerminal(action === "update" ? "sudo pacman -S --needed " + id : "sudo pacman -Rns " + id);
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
        if (open && section === "apps") detectApps();
        if (open && section === "web") loadWebapps();
        if (open && section === "ai") loadAi();
        if (open && section === "appimage") checkHandler();
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
    function loadAi() { if (!aiProc.running) aiProc.running = true; }
    // a coding agent in a terminal: they are terminal programs
    function aiLaunch(command) {
        const q = "'" + String(command).replace(/'/g, "'\\''") + "'";
        const script = "if command -v xdg-terminal-exec >/dev/null 2>&1; then exec xdg-terminal-exec " + q
            + "; elif command -v kitty >/dev/null 2>&1; then exec kitty sh -lc " + q
            + "; elif command -v foot >/dev/null 2>&1; then exec foot sh -lc " + q
            + "; elif command -v alacritty >/dev/null 2>&1; then exec alacritty -e sh -lc " + q
            + "; else echo 'No terminal emulator found.'; fi";
        Quickshell.execDetached(["sh", "-c", script]);
    }
    Process {
        id: aiProc
        command: ["aequalyn-ai-tool", "list", "--json"]
        stdout: StdioCollector {
            onStreamFinished: { try { root.aiTools = JSON.parse(text.trim()); } catch (e) { root.aiTools = []; } }
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
        if (section === "market") { loadMarket(); if (!busy) runJob("Refreshing the catalog", ["refresh"]); }
        if (section === "apps") { detectApps(); if (root.foundPage === 0) searchApps("", false); }
        if (section === "web") loadWebapps();
        if (section === "ai") loadAi();
        if (section === "appimage") checkHandler();
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
        // open on a section: home, plugin, theme, cursor, wallpaper, look, apps, appimage, market, updates
        function section(name: string): string {
            const section = name;
            if (!root.sections.some(s => s.key === section)) return "no section " + section;
            root.section = section; root.open = true; root.refresh(); return "ok";
        }
        // look for apps in Arch, the AUR, Flathub and Snap
        function search(words: string): void {
            root.section = "apps"; root.open = true; root.detectApps(); root.searchApps(words, false);
        }
        // an .AppImage opened in a file manager (the handler's menu entry runs
        // aequalyn-store open-appimage): this page, its import form filled in and
        // the file already checked, so Enter (or Import) is all that is left
        function appimage(path: string): string {
            root.section = "appimage"; root.open = true; root.refresh();
            appField.text = path;
            root.runJob("Checking " + path, ["check-appimage", path]);
            return "ok";
        }
        // install from a git URL (or a folder), with every check first
        function install(kind: string, source: string): string {
            if (!root.kindWords[kind]) return "no kind " + kind;
            root.section = kind; root.open = true;
            root.runJob("Installing " + source, ["install", kind, source]);
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
        implicitHeight: 32
        implicitWidth: row.implicitWidth + 26
        radius: 8
        color: primary ? (ma.containsMouse ? root.theme.bgHover : root.theme.bgSelected)
             : ma.containsMouse ? root.theme.bgHover : root.theme.bgSurface
        border.width: 1
        border.color: danger && ma.containsMouse ? root.theme.accentRed : primary ? root.theme.accentPrimary : root.theme.bgBorder
        opacity: enabled ? 1 : 0.45
        Behavior on color { ColorAnimation { duration: 120 } }
        Accessible.role: Accessible.Button
        Accessible.name: text
        readonly property color ink: danger && ma.containsMouse ? root.theme.accentRed
                       : primary ? root.theme.accentPrimary : root.theme.textPrimary
        Row {
            id: row
            anchors.centerIn: parent
            spacing: 7
            Text { visible: btn.icon !== ""; text: btn.icon; color: btn.ink; font.family: root.mono; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
            Text { visible: btn.text !== ""; text: btn.text; color: btn.ink; font.family: root.sans; font.pixelSize: 12; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
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
        implicitHeight: 38
        radius: 10
        color: root.theme.bgBase
        border.width: 1
        border.color: input.activeFocus ? root.theme.accentPrimary : root.theme.bgBorder
        Behavior on border.color { ColorAnimation { duration: 120 } }
        MouseArea { anchors.fill: parent; onClicked: input.forceActiveFocus() }
        TextInput {
            id: input
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 12
            verticalAlignment: TextInput.AlignVCenter
            color: root.theme.textPrimary
            selectionColor: root.theme.accentPrimary
            selectedTextColor: root.theme.bgBase
            font.family: root.sans
            font.pixelSize: 13
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
        spacing: 8
        Text {
            visible: box.title !== ""
            text: box.title
            color: root.theme.textSecondary
            font.family: root.sans
            font.pixelSize: 13
            font.weight: Font.DemiBold
            Layout.fillWidth: true
            Layout.leftMargin: 2
        }
        Text {
            visible: box.hint !== ""
            text: box.hint
            color: root.theme.textMuted
            font.family: root.sans
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            Layout.leftMargin: 2
            Layout.topMargin: -4
        }
        // the group: a quiet box around the content
        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 2
            implicitHeight: body.implicitHeight + 8
            radius: 12
            color: root.theme.bgSurface
            border.width: 1
            border.color: root.theme.bgBorder
            ColumnLayout {
                id: body
                x: 4
                y: 4
                width: parent.width - 8
                spacing: 8
            }
        }
    }
    component Pill: Rectangle {
        property string text: ""
        property color tone: root.theme.accentGreen
        implicitWidth: pt.implicitWidth + 16
        implicitHeight: 22
        radius: 8
        color: Qt.rgba(tone.r, tone.g, tone.b, 0.14)
        Text { id: pt; anchors.centerIn: parent; text: parent.text; color: parent.tone; font.family: root.mono; font.pixelSize: 11; font.weight: Font.DemiBold }
    }

    // ‹ and ›, as the control center steps its choices
    component StepBtn: Rectangle {
        id: sb
        property string glyph: ""
        signal clicked()
        Layout.preferredWidth: 26
        Layout.preferredHeight: 26
        radius: 7
        color: sbMa.containsMouse ? root.theme.bgHover : root.theme.bgSurface
        border.width: 1
        border.color: root.theme.bgBorder
        Accessible.role: Accessible.Button
        Text { anchors.centerIn: parent; text: sb.glyph; color: root.theme.textSecondary; font.family: root.mono; font.pixelSize: 14 }
        MouseArea { id: sbMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: sb.clicked() }
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
        readonly property bool canOpen: card.isWeb ? !!modelData.slug : !!modelData.path
        signal openRequested()
        signal removeRequested()
        signal categoryRequested()
        radius: 12
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
                    source: card.iconPath ? "file://" + card.iconPath : ""
                    sourceSize.width: 112; sourceSize.height: 112
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                    visible: card.iconPath !== "" && status === Image.Ready
                }
                Text {
                    anchors.centerIn: parent
                    visible: !cardIcon.visible
                    text: card.isWeb ? "\u{F0595}" : "\u{F01D4}"
                    color: root.theme.textMuted; font.family: root.mono; font.pixelSize: 26
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

    // one installed item: its name, where it came from, its state and its actions.
    // Rows sit together as the control center's rows do: on the group's colour, a
    // hairline between them, no card of their own.
    component ItemRow: ColumnLayout {
        id: row
        required property var modelData
        required property int index
        readonly property string kind: modelData.kind
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
                    visible: row.kind === "appimage" && !!row.modelData.icon && status === Image.Ready
                    source: row.modelData.icon ? "file://" + row.modelData.icon : ""
                    sourceSize.width: 64
                    sourceSize.height: 64
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                }
                Text {
                    anchors.centerIn: parent
                    visible: row.kind !== "appimage" || !row.modelData.icon || rowIcon.status === Image.Error
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
                    Text { text: row.modelData.label || row.modelData.id; color: root.theme.textPrimary; font.family: root.sans; font.pixelSize: 13; font.weight: Font.DemiBold }
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

    // one plugin tile, used for both the built-in and the community grids
    component PluginCard: Rectangle {
        id: card
        required property var modelData
        required property bool builtIn
        readonly property var info: root.pluginInfoOf(card.modelData, card.builtIn)
        readonly property bool on: (AequalynSettings.enabledPlugins || []).indexOf(card.modelData.id) >= 0
        height: 112
        Layout.fillWidth: true
        Layout.preferredWidth: 180
        Layout.minimumWidth: 120
        Layout.preferredHeight: 112
        radius: 12
        color: root.theme.bgBase
        border.width: 1
        border.color: card.on ? root.theme.accentPrimary : root.theme.bgBorder
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 9
            spacing: 4
            RowLayout {
                Layout.fillWidth: true
                spacing: 7
                Rectangle {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    radius: 7
                    color: root.theme.bgSurface
                    border.width: 1
                    border.color: root.theme.bgBorder
                    Text {
                        anchors.centerIn: parent
                        text: card.info.icon || "\u{F0431}"
                        color: root.theme.accentPrimary
                        font.family: root.mono
                        font.pixelSize: 14
                    }
                }
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
                text: card.info.about || card.modelData.source || ""
                color: root.theme.textSecondary
                font.family: root.sans
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
            Item { Layout.fillHeight: true }
            RowLayout {
                Layout.fillWidth: true
                spacing: 5
                Btn {
                    Layout.fillWidth: true
                    implicitHeight: 24
                    text: card.on ? "Turn off" : "Turn on"
                    onClicked: AequalynSettings.togglePlugin(card.modelData.id, !card.on)
                }
                Btn {
                    visible: card.builtIn
                    Layout.fillWidth: true
                    implicitHeight: 24
                    text: "Details"
                    primary: true
                    onClicked: root.runSide(["qs", "ipc", "call", "aequalyn", "pluginPage", card.modelData.id])
                }
                Btn {
                    visible: !card.builtIn
                    Layout.fillWidth: true
                    implicitHeight: 24
                    text: "Update"
                    enabled: !root.busy
                    onClicked: root.runJob("Updating " + card.modelData.id, ["update", "plugin", card.modelData.id])
                }
                Btn {
                    visible: !card.builtIn
                    Layout.fillWidth: true
                    implicitHeight: 24
                    text: "Remove"
                    danger: true
                    enabled: !root.busy
                    onClicked: root.runJob("Removing " + card.modelData.id, ["remove", "plugin", card.modelData.id])
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
                    Layout.preferredHeight: 112
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
                            Layout.preferredHeight: 112
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
            Keys.onEscapePressed: {
                // the picker over the page closes first, then the window
                if (root.pickOpen) { root.pickOpen = false; return; }
                root.open = false;
            }
            MouseArea { anchors.fill: parent }   // clicks inside never close it

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // title bar, as the control center's: the mark, the name, the close
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
                        anchors.left: titleText.right
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: (root.sections.find(s => s.key === root.section) || {}).label || ""
                        color: root.theme.textMuted
                        font.family: root.sans
                        font.pixelSize: 13
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

                    // the rail of sections, as the control center's category rail:
                    // an icon tile above each name, the chosen one accented
                    ColumnLayout {
                        Layout.preferredWidth: 96
                        Layout.maximumWidth: 96
                        Layout.fillHeight: true
                        Layout.leftMargin: 6
                        Layout.topMargin: 12
                        Layout.bottomMargin: 8
                        spacing: 2
                        Repeater {
                            model: root.sections
                            delegate: Item {
                                id: railItem
                                required property var modelData
                                readonly property bool on: root.section === modelData.key
                                Layout.fillWidth: true
                                Layout.preferredHeight: 56
                                Accessible.role: Accessible.PageTab
                                Accessible.name: modelData.label
                                Rectangle {
                                    id: railBox
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: 4
                                    width: 36; height: 30; radius: 8
                                    color: railItem.on ? root.theme.bgSelected : railMa.containsMouse ? root.theme.bgSurface : "transparent"
                                    border.width: railItem.on ? 1 : 0
                                    border.color: root.theme.accentPrimary
                                    Text {
                                        anchors.centerIn: parent
                                        text: railItem.modelData.glyph
                                        color: railItem.on ? root.theme.accentPrimary : root.theme.textSecondary
                                        font.family: root.mono
                                        font.pixelSize: 15
                                    }
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.top: railBox.bottom
                                    anchors.topMargin: 3
                                    width: parent.width - 4
                                    text: railItem.modelData.label
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignHCenter
                                    color: railItem.on ? root.theme.textPrimary : root.theme.textMuted
                                    font.family: root.mono
                                    font.pixelSize: 10
                                    font.bold: railItem.on
                                }
                                MouseArea { id: railMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.section = modelData.key }
                            }
                        }
                        Item { Layout.fillHeight: true }
                    }
                    Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: root.theme.bgBorder }

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
                                                onClicked: root.section = modelData.key
                                            }
                                        }
                                    }
                                }

                                // the other kinds keep their installed list above the form
                                Box {
                                    visible: !!root.kindWords[root.section] && root.section !== "plugin"
                                    title: "Installed"
                                    hint: root.kindWords[root.section] && root.itemsOf(root.section).length === 0
                                          ? "No " + root.kindWords[root.section].one + " from the Store yet." : ""
                                    Repeater {
                                        model: root.kindWords[root.section] && root.section !== "plugin" ? root.itemsOf(root.section) : []
                                        delegate: ItemRow {}
                                    }
                                }
                                // community first, then the git form, then the shell's own
                                // plugins; each grid is fifteen tiles: five across, three rows
                                PluginGrid {
                                    entriesTitle: "Community"
                                    entriesHint: root.itemsOf("plugin").length === 0
                                        ? "No community plugins from the Store yet. Add one with the form below."
                                        : "Plugins installed from git, with update and remove on each tile."
                                    entries: root.itemsOf("plugin")
                                    builtIn: false
                                }

                                InstallBox { visible: !!root.kindWords[root.section]; kind: root.kindWords[root.section] ? root.section : "plugin" }

                                PluginGrid {
                                    entriesTitle: "Built-in"
                                    entriesHint: "These ship with Aequalyn. Turn them on or open their page here; nothing to download."
                                    entries: root.builtInPlugins
                                    builtIn: true
                                }

                                // Apps: the four backends, then the popular apps, each from
                                // any backend that has it; installed packages are in All apps
                                Box {
                                    visible: root.section === "apps"
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
                                                enabled: !terminal.running && (modelData.needs === "" || root.backends[modelData.needs] === true)
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
                                    visible: root.section === "apps"
                                    title: "Popular apps"
                                    hint: "Every card shows all four ways to install it. A greyed button means that app has no build there; installs open in a terminal, where sudo asks for your password."
                                    // five to a row (a RowLayout shares its width out), three
                                    // rows to a page, ghost slots keeping every page's shape
                                    Repeater {
                                        model: root.section === "apps" ? root.popRows() : []
                                        delegate: RowLayout {
                                            id: popRow
                                            required property var modelData
                                            Layout.fillWidth: true
                                            // an all-ghost row keeps the card height, so the page
                                            // holds its 5x3 shape even when nothing is in it
                                            Layout.preferredHeight: 150
                                            spacing: 10
                                            Repeater {
                                                model: popRow.modelData
                                                delegate: Rectangle {
                                                    id: appCard
                                                    required property var modelData
                                                    readonly property string via: root.installedVia(modelData)
                                                    Layout.fillWidth: true
                                                    Layout.preferredWidth: 203
                                                    height: 150
                                                    radius: 12
                                                    color: root.theme.bgBase
                                                    border.width: 1
                                                    border.color: root.theme.bgBorder
                                                ColumnLayout {
                                                    anchors.fill: parent
                                                    anchors.margins: 12
                                                    spacing: 6
                                                    RowLayout {
                                                        spacing: 10
                                                        Image {
                                                            source: "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/" + appCard.modelData.icon + ".png"
                                                            sourceSize.width: 64; sourceSize.height: 64
                                                            Layout.preferredWidth: 34; Layout.preferredHeight: 34
                                                            fillMode: Image.PreserveAspectFit
                                                            asynchronous: true
                                                            smooth: true
                                                        }
                                                        ColumnLayout {
                                                            spacing: 1
                                                            Layout.fillWidth: true
                                                            Text { text: appCard.modelData.name; color: root.theme.textPrimary; font.family: root.sans; font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
                                                            Pill { visible: appCard.via !== ""; text: "Installed · " + appCard.via; tone: root.theme.accentGreen }
                                                        }
                                                    }
                                                    Text { text: appCard.modelData.about; color: root.theme.textSecondary; font.family: root.sans; font.pixelSize: 11; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                                                    Item { Layout.fillHeight: true }
                                                    Flow {
                                                        Layout.fillWidth: true
                                                        spacing: 4
                                                        Repeater {
                                                            model: [
                                                                { via: "Arch", has: !!appCard.modelData.pacman, ready: true },
                                                                { via: "AUR", has: !!appCard.modelData.aur, ready: root.backends.yay === true },
                                                                { via: "Flatpak", has: !!appCard.modelData.flatpak, ready: root.backends.flatpak === true },
                                                                { via: "Snap", has: !!appCard.modelData.snap, ready: root.backends.snap === true }
                                                            ]
                                                            delegate: Btn {
                                                                required property var modelData
                                                                text: modelData.via
                                                                implicitHeight: 24
                                                                primary: modelData.has && modelData.ready && appCard.via === ""
                                                                enabled: modelData.has && modelData.ready && !terminal.running
                                                                onClicked: root.installApp(appCard.modelData, modelData.via)
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        Repeater {
                                            model: 5 - popRow.modelData.length
                                            delegate: Item { Layout.fillWidth: true; Layout.preferredWidth: 203 }
                                        }
                                    }
                                    }

                                    // the pages of the popular grid, ‹ and › to walk them
                                    RowLayout {
                                        visible: root.popShown.length > 15
                                        spacing: 6
                                        Item { Layout.fillWidth: true }
                                        Text {
                                            text: root.popShown.length + " apps"
                                            color: root.theme.textMuted; font.family: root.mono; font.pixelSize: 11
                                        }
                                        StepBtn {
                                            glyph: "‹"
                                            enabled: root.popAt > 0
                                            onClicked: root.popPage = root.popAt / 15 - 1
                                        }
                                        Text {
                                            text: (root.popAt + 1) + "–" + Math.min(root.popAt + 15, root.popShown.length)
                                                  + " of " + root.popShown.length
                                            color: root.theme.textMuted; font.family: root.mono; font.pixelSize: 11
                                        }
                                        StepBtn {
                                            glyph: "›"
                                            enabled: root.popAt + 15 < root.popShown.length
                                            onClicked: root.popPage = root.popAt / 15 + 1
                                        }
                                    }
                                }
                                // every app from every backend
                                Box {
                                    visible: root.section === "apps"
                                    title: "All apps"
                                    hint: root.foundSource === "Installed"
                                        ? (root.installedQuery === ""
                                           ? "Everything installed from Arch, the AUR, Flathub and Snap, command-line tools included. Search to narrow this list."
                                           : "Installed packages matching \"" + root.installedQuery + "\".")
                                        : root.foundQuery === ""
                                          ? "Flathub's most installed and Snap's featured apps. Search to look through Arch, the AUR, Flathub and Snap at once."
                                          : "Everything that matches \"" + root.foundQuery + "\" in Arch, the AUR, Flathub and Snap."
                                    RowLayout {
                                        spacing: 8
                                        Field {
                                            id: appSearch
                                            placeholder: "Search every app, like \"obsidian\""
                                            onAccepted: root.searchApps(appSearch.text.trim(), false)
                                        }
                                        Btn { text: root.searching ? "Searching…" : "Search"; primary: true; enabled: !root.searching; onClicked: root.searchApps(appSearch.text.trim(), false) }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6
                                        Repeater {
                                            model: ["All", "Installed", "Arch", "AUR", "Flatpak", "Snap"]
                                            delegate: Btn {
                                                required property string modelData
                                                readonly property int count: modelData === "All" ? root.found.length
                                                    : modelData === "Installed" ? root.installedApps.length
                                                    : root.found.filter(r => r.source === modelData).length
                                                Layout.fillWidth: true
                                                Layout.preferredWidth: 0
                                                Layout.minimumWidth: 0
                                                text: modelData + "  " + count + (root.foundErrors[modelData] ? "  ⚠" : "")
                                                primary: root.foundSource === modelData
                                                implicitHeight: 26
                                                onClicked: {
                                                    root.installedQuery = modelData === "Installed" ? appSearch.text.trim() : "";
                                                    root.foundSource = modelData;
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
                                    // five to a row, three rows to a page, ghost slots
                                    // keeping every page's shape -- the same view as the rest
                                    Repeater {
                                        model: root.section === "apps" ? root.foundRows() : []
                                        delegate: RowLayout {
                                            id: foundRow
                                            required property var modelData
                                            Layout.fillWidth: true
                                            // an all-ghost row keeps the card height, so the page
                                            // holds its 5x3 shape even when nothing is in it
                                            Layout.preferredHeight: 150
                                            spacing: 10
                                            Repeater {
                                                model: foundRow.modelData
                                                delegate: Rectangle {
                                                    id: fcard
                                                    required property var modelData
                                                    readonly property bool have: root.foundInstalled(modelData)
                                                    readonly property bool installedHere: !!modelData.installed
                                                    readonly property bool ready: modelData.source === "Arch" || (modelData.source === "AUR" && root.backends.yay)
                                                        || (modelData.source === "Flatpak" && root.backends.flatpak) || (modelData.source === "Snap" && root.backends.snap)
                                                    Layout.fillWidth: true
                                                    Layout.preferredWidth: 203
                                                    height: 150
                                                    radius: 12
                                                    color: root.theme.bgBase
                                                    border.width: 1
                                                    border.color: root.theme.bgBorder
                                                    ColumnLayout {
                                                        anchors.fill: parent
                                                        anchors.margins: 10
                                                        spacing: 6
                                                        RowLayout {
                                                            spacing: 8
                                                            Item {
                                                                Layout.preferredWidth: 30; Layout.preferredHeight: 30
                                                                Image {
                                                                    id: ficon
                                                                    anchors.fill: parent
                                                                    source: fcard.modelData.icon || ""
                                                                    sourceSize.width: 64; sourceSize.height: 64
                                                                    fillMode: Image.PreserveAspectFit
                                                                    asynchronous: true
                                                                    visible: status === Image.Ready
                                                                }
                                                                Text {
                                                                    anchors.centerIn: parent
                                                                    visible: ficon.status !== Image.Ready
                                                                    text: "\u{F03D6}"
                                                                    color: root.theme.textMuted; font.family: root.mono; font.pixelSize: 20
                                                                }
                                                            }
                                                            ColumnLayout {
                                                                spacing: 1
                                                                Layout.fillWidth: true
                                                                Text {
                                                                    text: fcard.modelData.name
                                                                    color: root.theme.textPrimary; font.family: root.sans; font.pixelSize: 12; font.weight: Font.DemiBold
                                                                    elide: Text.ElideRight; Layout.fillWidth: true
                                                                }
                                                                Text {
                                                                    text: fcard.modelData.source === "Flatpak" ? "Flathub" : fcard.modelData.source
                                                                    color: root.theme.textMuted; font.family: root.mono; font.pixelSize: 10
                                                                }
                                                            }
                                                        }
                                                        Text {
                                                            text: fcard.modelData.about
                                                            color: root.theme.textSecondary; font.family: root.sans; font.pixelSize: 11
                                                            wrapMode: Text.WordWrap; elide: Text.ElideRight
                                                            maximumLineCount: 2; Layout.fillWidth: true
                                                        }
                                                        Item { Layout.fillHeight: true }
                                                        // Installed cards keep the badge and both actions inside the
                                                        // 203px card: badge above, two half-width buttons below
                                                        ColumnLayout {
                                                            visible: fcard.installedHere
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
                                                                    enabled: !terminal.running
                                                                    onClicked: root.appAction(fcard.modelData, "update")
                                                                }
                                                                Btn {
                                                                    Layout.fillWidth: true
                                                                    implicitHeight: 26
                                                                    text: "Remove"
                                                                    danger: true
                                                                    enabled: !terminal.running
                                                                    onClicked: root.appAction(fcard.modelData, "remove")
                                                                }
                                                            }
                                                        }
                                                        RowLayout {
                                                            visible: !fcard.installedHere
                                                            Layout.fillWidth: true
                                                            spacing: 6
                                                            Pill { visible: fcard.have; text: "Installed"; tone: root.theme.accentGreen }
                                                            Item { Layout.fillWidth: true }
                                                            Btn {
                                                                visible: !fcard.have
                                                                implicitHeight: 26
                                                                text: fcard.ready ? "Install" : "Needs " + (fcard.modelData.source === "AUR" ? "the AUR" : fcard.modelData.source === "Flatpak" ? "Flathub" : "Snap")
                                                                primary: fcard.ready
                                                                enabled: fcard.ready && !terminal.running
                                                                onClicked: root.installFound(fcard.modelData)
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                            Repeater {
                                                model: 5 - foundRow.modelData.length
                                                delegate: Item { Layout.fillWidth: true; Layout.preferredWidth: 203 }
                                            }
                                        }
                                    }
                                    // a page of results at a time, ‹ and › to walk them
                                    RowLayout {
                                        visible: root.foundShown.length > root.foundStep
                                        spacing: 6
                                        Item { Layout.fillWidth: true }
                                        Text {
                                            visible: root.foundShown.length > 0
                                            text: root.foundShown.length + (root.foundShown.length === 1 ? " app" : " apps")
                                            color: root.theme.textMuted; font.family: root.mono; font.pixelSize: 11
                                        }
                                        StepBtn {
                                            glyph: "‹"
                                            enabled: root.foundAt > 0
                                            onClicked: root.foundAt -= root.foundStep
                                        }
                                        Text {
                                            text: (root.foundAt + 1) + "–" + Math.min(root.foundAt + root.foundStep, root.foundShown.length)
                                                  + " of " + root.foundShown.length
                                            color: root.theme.textMuted; font.family: root.mono; font.pixelSize: 11
                                        }
                                        StepBtn {
                                            glyph: "›"
                                            enabled: root.foundAt + root.foundStep < root.foundShown.length
                                            onClicked: root.foundAt += root.foundStep
                                        }
                                    }
                                    Btn {
                                        visible: root.foundPage > 0 && root.foundPage < root.flathubPages && (root.foundSource === "All" || root.foundSource === "Flatpak")
                                        text: root.searching ? "Loading…" : "More from Flathub (page " + (root.foundPage + 1) + " of " + root.flathubPages + ")"
                                        enabled: !root.searching
                                        onClicked: root.searchApps(root.foundQuery, true)
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
                                                        visible: !!wrow.modelData.iconFile && status === Image.Ready
                                                        source: wrow.modelData.iconFile ? "file://" + wrow.modelData.iconFile : ""
                                                        sourceSize.width: 64; sourceSize.height: 64
                                                        fillMode: Image.PreserveAspectFit
                                                        asynchronous: true
                                                        smooth: true
                                                    }
                                                    Text {
                                                        anchors.centerIn: parent
                                                        visible: !wicon.visible
                                                        text: "\u{F0595}"
                                                        color: root.theme.accentPrimary; font.family: root.mono; font.pixelSize: 16
                                                    }
                                                }
                                                ColumnLayout {
                                                    spacing: 2
                                                    Layout.fillWidth: true
                                                    RowLayout {
                                                        spacing: 8
                                                        Layout.fillWidth: true
                                                        Text { text: wrow.modelData.name; color: root.theme.textPrimary; font.family: root.sans; font.pixelSize: 13; font.weight: Font.DemiBold }
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
                                    Repeater {
                                        model: root.section === "web" ? root.webCategories : []
                                        delegate: RowLayout {
                                            required property var modelData
                                            Layout.fillWidth: true
                                            spacing: 8
                                            Text {
                                                text: modelData.label
                                                color: root.theme.textPrimary; font.family: root.sans; font.pixelSize: 13
                                                elide: Text.ElideRight; Layout.fillWidth: true
                                            }
                                            Pill { text: (modelData.count || 0) + " apps"; tone: root.theme.textMuted }
                                            Btn {
                                                text: "Rename"
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
                                                enabled: !root.busy
                                                onClicked: root.runCmd("Removing category " + modelData.label,
                                                                       ["aequalyn-webapp", "category-remove", modelData.id])
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

                                // AI tools: the coding agents, each one click away
                                Box {
                                    visible: root.section === "ai"
                                    title: "Coding agents"
                                    hint: "Most tools use their publisher's npm package; Antigravity uses Google's official installer. Sign-in stays with each provider."
                                    Repeater {
                                        model: root.section === "ai" ? root.aiTools : []
                                        delegate: ColumnLayout {
                                            id: arow
                                            required property var modelData
                                            required property int index
                                            Layout.fillWidth: true
                                            spacing: 0
                                            Rectangle { visible: arow.index > 0; Layout.fillWidth: true; Layout.preferredHeight: 1; color: root.theme.bgBorder }
                                            RowLayout {
                                                Layout.fillWidth: true
                                                Layout.leftMargin: 12
                                                Layout.rightMargin: 12
                                                Layout.topMargin: 9
                                                Layout.bottomMargin: 9
                                                spacing: 10
                                                ColumnLayout {
                                                    spacing: 2
                                                    Layout.fillWidth: true
                                                    Text { text: arow.modelData.name; color: root.theme.textPrimary; font.family: root.sans; font.pixelSize: 13; font.weight: Font.DemiBold }
                                                    Text {
                                                        text: (arow.modelData.description || "")
                                                            + (arow.modelData.installed ? "  ·  " + arow.modelData.command + " " + (arow.modelData.version || "")
                                                               : arow.modelData.availableElsewhere ? "  ·  already at " + arow.modelData.availablePath
                                                               : arow.modelData.launcherConflict ? "  ·  the " + arow.modelData.command + " command is taken"
                                                               : "  ·  " + arow.modelData.command)
                                                        color: root.theme.textSecondary; font.family: root.sans; font.pixelSize: 11
                                                        wrapMode: Text.WordWrap; Layout.fillWidth: true
                                                    }
                                                }
                                                Btn {
                                                    text: arow.modelData.installed ? "Update"
                                                        : arow.modelData.availableElsewhere ? "Open"
                                                        : arow.modelData.launcherConflict ? "In use" : "Install"
                                                    primary: !arow.modelData.installed && !arow.modelData.availableElsewhere && !arow.modelData.launcherConflict
                                                    enabled: !root.busy && (arow.modelData.installed || arow.modelData.availableElsewhere || !arow.modelData.launcherConflict)
                                                    onClicked: {
                                                        if (arow.modelData.installed)
                                                            root.runCmd("Updating " + arow.modelData.name, ["aequalyn-ai-tool", "update", arow.modelData.id]);
                                                        else if (arow.modelData.availableElsewhere)
                                                            root.aiLaunch(arow.modelData.command);
                                                        else if (!arow.modelData.launcherConflict)
                                                            root.runCmd("Installing " + arow.modelData.name, ["aequalyn-ai-tool", "install", arow.modelData.id]);
                                                    }
                                                }
                                                Btn {
                                                    visible: !!arow.modelData.installed
                                                    text: "Remove"
                                                    danger: true
                                                    enabled: !root.busy
                                                    onClicked: root.runCmd("Removing " + arow.modelData.name, ["aequalyn-ai-tool", "remove", arow.modelData.id])
                                                }
                                            }
                                        }
                                    }
                                    Text {
                                        visible: root.aiTools.length === 0
                                        text: "Reading the AI tool list…"
                                        color: root.theme.textMuted; font.family: root.sans; font.pixelSize: 11
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
                                                            text: mrow.modelData.state === "installed" ? "Installed" : "Update available"
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
                                                    visible: mrow.modelData.state !== "installed"
                                                    text: mrow.modelData.state === "update available" ? "Update" : "Install"
                                                    primary: true
                                                    enabled: !root.busy
                                                    onClicked: root.runJob((mrow.modelData.state === "update available" ? "Updating " : "Installing ") + (mrow.modelData.name || mrow.modelData.id),
                                                                           ["install-market", mrow.modelData.id])
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
                            color: root.theme.bgSurface
                            Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: root.theme.bgBorder }
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
                        text: "super alt s  open     esc  close"
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
