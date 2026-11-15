// Atelier -- the engine behind the look of the desktop: the theme and wallpaper picker,
// and the panes the control center shows for wallpapers, the bar, docks and window
// layouts.
//
//   Super + T: themes. A theme is its colours and its own wallpapers: picking one
//              applies both.
//   Super + W: wallpapers, the current theme's and your own. Picking one changes only
//              the wallpaper; the theme's colours stay.
// Everything else that used to be a tab here is a page of the control center; asking
// Atelier for one opens that page:
//     layouts -> Arranging windows     rotation -> Wallpaper, over time
//     palette, panel -> Theme          bar -> Bar      docks -> Dock
//
// IPC:  qs ipc call atelier toggle [themes|wallpapers|layouts|rotation|palette|bar|docks|panel]
//       qs ipc call atelier open <tab> | close
//       qs ipc call wallpaper next | prev | random | set <file> | mode <mode>

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "root:/settings"

Scope {
    id: root
    // No DefaultTheme fallback: Atelier drives the live Theme singleton (with
    // methods like setWallpaperMode/folderTheme), so it must inherit the shared
    // theme from PluginManager even when loaded as a plugin.
    property var theme: null
    property string font: "JetBrainsMono Nerd Font"

    property string collection: "themes"
    property string searchText: ""
    property int currentIndex: 0

    // "" (closed) or "switcher": the picker over the blurred desktop
    property string surface: ""
    readonly property bool shown: surface !== ""

    onSurfaceChanged: {
        AtelierHost.shown = shown;
        AtelierHost.shownCollection = shown ? collection : "";
        if (!shown && theme) theme.previewPalette = null;
    }
    onCollectionChanged: AtelierHost.shownCollection = shown ? collection : ""

    // what the picker shows
    readonly property var collections: [
        { key: "themes", icon: "󰏘", name: "Themes" },
        { key: "wallpapers", icon: "󰸉", name: "Wallpapers" }
    ]
    readonly property bool livePreview: AequalynSettings.atelierCfg.livePreview !== false

    // ---- items ---------------------------------------------------------
    // Themes: the ones with their own colours and wallpapers.
    readonly property var themeItems: {
        const t = root.theme;
        if (!t || !t.folderThemes) return [];
        return t.folderThemes.filter(f => f.hasPalette && (f.backgrounds || []).length > 0).map(f => ({
            key: "theme:" + f.id, kind: "folder", id: f.id,
            title: f.name, subtitle: f.family,
            image: f.preview || f.backgrounds[0],
            palette: f, backgrounds: f.backgrounds, dir: f.dir || "",
            active: t.currentFolderId === f.id
        }));
    }

    // Wallpapers: the current theme's first, then your own (your wallpaper folder);
    // other themes' wallpapers come with their theme, from Super + T.
    readonly property string currentThemeId: root.theme ? root.theme.currentFolderId : ""
    function ownedByTheme(w, id) { return id !== "" && w.path.indexOf("/" + id + "/backgrounds/") >= 0; }
    readonly property var wallpaperItems: {
        const id = currentThemeId;
        const theirs = AtelierService.wallpapers.filter(w => w.theme && ownedByTheme(w, id));
        const yours = AtelierService.wallpapers.filter(w => !w.theme && !w.generated);
        return theirs.concat(yours).map(w => ({
            key: w.path, kind: "image", path: w.path,
            title: w.name, subtitle: w.folder,
            image: w.thumb, video: w.video,
            active: w.path === AtelierService.current
        }));
    }

    readonly property var items: {
        const src = collection === "themes" ? themeItems : collection === "wallpapers" ? wallpaperItems : [];
        const q = searchText.toLowerCase();
        if (q === "") return src;
        return src.filter(it => (it.title + " " + it.subtitle).toLowerCase().indexOf(q) >= 0);
    }

    readonly property var currentItem: items[currentIndex] || null

    // ---- favourites and recently used (per collection, kept in settings) ----
    readonly property var favorites: (AequalynSettings.atelierCfg.favorites || {})[collection] || []
    readonly property var recentKeys: (AequalynSettings.atelierCfg.recent || {})[collection] || []
    function isFavorite(it) { return !!it && !!it.key && favorites.indexOf(it.key) >= 0; }
    function toggleFavorite(it) {
        if (!it || !it.key) return;
        const all = Object.assign({}, AequalynSettings.atelierCfg.favorites || {});
        const list = (all[collection] || []).slice();
        const at = list.indexOf(it.key);
        if (at >= 0) list.splice(at, 1); else list.push(it.key);
        all[collection] = list;
        AequalynSettings.setIn("atelier", "favorites", all);
    }
    function noteRecent(it) {
        if (!it || !it.key) return;
        const all = Object.assign({}, AequalynSettings.atelierCfg.recent || {});
        all[collection] = [it.key].concat((all[collection] || []).filter(k => k !== it.key)).slice(0, 12);
        AequalynSettings.setIn("atelier", "recent", all);
    }

    // ---- opening and closing -------------------------------------------
    // The picker for themes and wallpapers; a page of the control center for the rest
    // (center/Pages.js maps Atelier's old tab names to its pages).
    function open(which) {
        const c = which && which !== "" ? which : "themes";
        if (c === "themes" || c === "wallpapers") {
            setCollection(c);
            if (c === "wallpapers" || AtelierService.wallpapers.length === 0) AtelierService.refresh();
            LayoutService.refresh();
            surface = "switcher";
            return;
        }
        close();
        openPage(c);
    }
    function openPage(name) {
        Quickshell.execDetached(["qs", "ipc", "call", "aequalyn", "page", name]);
    }
    // Ctrl + , in the picker: where its type, shape and place are set
    function openSettings() {
        close();
        openPage("panel");
    }
    function close() { surface = ""; }
    function toggle(which) {
        const c = which && which !== "" ? which : "themes";
        if (shown && c === collection) close();
        else open(c);
    }

    function setCollection(c) {
        if (collections.every(x => x.key !== c)) return;
        if (root.theme) root.theme.previewPalette = null;
        collection = c;
        searchText = "";
        selectActive();
        if (c === "wallpapers") AtelierService.refresh();
    }

    function search(text) { searchText = text; currentIndex = 0; preview(); }

    function selectActive() {
        const list = items;
        for (let i = 0; i < list.length; i++) if (list[i].active) { currentIndex = i; return; }
        currentIndex = 0;
    }

    function move(delta) {
        const n = items.length;
        if (n === 0) return;
        currentIndex = Math.max(0, Math.min(n - 1, currentIndex + delta));
    }

    onCurrentIndexChanged: preview()
    onItemsChanged: if (currentIndex >= items.length) currentIndex = Math.max(0, items.length - 1)

    // Live preview: the whole shell takes the colours of the theme under the
    // cursor until you pick one or close the picker.
    function preview() {
        if (!shown || !root.theme || collection !== "themes" || !livePreview) return;
        // Read items directly: currentItem may not have re-evaluated yet
        // when this runs from onCurrentIndexChanged.
        const it = items[currentIndex];
        root.theme.previewPalette = it && it.palette ? it.palette : null;
    }

    function apply(index, closeAfter) {
        const it = items[index];
        if (!it) return;
        currentIndex = index;
        noteRecent(it);
        const t = root.theme;
        switch (it.kind) {
        case "folder":
            // its colours, and its first wallpaper unless one of its own is on already
            t.setFolderTheme(it.id);
            break;
        case "image":
            // only the wallpaper: the theme's colours stay
            if (AtelierService.mode === "workspace" && AtelierService.focusedWorkspace !== "")
                AtelierService.assignWorkspace(AtelierService.focusedWorkspace, it.path);
            else
                AtelierService.setWallpaper(it.path);
            break;
        }
        if (closeAfter) close();
    }

    // ---- bar buttons and docks ---------------------------------------------
    Connections {
        target: AtelierHost
        function onToggleRequested(collection, anchorItem, screenName) { root.toggle(collection); }
        function onOpenRequested(collection, screenName) { root.open(collection); }
        function onActionRequested(action) {
            switch (action) {
            case "next-layout": LayoutService.run(["aequalyn-layout", "next"]); break;
            case "prev-layout": LayoutService.run(["aequalyn-layout", "prev"]); break;
            case "next-wallpaper": AtelierService.next(); break;
            case "random-wallpaper": AtelierService.random(); break;
            case "themes": root.toggle("themes"); break;
            }
        }
    }

    // ---- IPC -------------------------------------------------------------
    IpcHandler {
        target: "atelier"
        function toggle(collection: string): void { root.toggle(collection); }
        function open(collection: string): void { root.open(collection); }
        function close(): void { root.close(); }
    }

    IpcHandler {
        target: "wallpaper"
        function toggle(): void { root.toggle("wallpapers"); }
        function next(): void { AtelierService.next(); }
        function prev(): void { AtelierService.prev(); }
        function random(): void { AtelierService.random(); }
        function set(path: string): void { AtelierService.setWallpaper(path); }
        function mode(name: string): void { AtelierService.setMode(name); }
    }

    // The switcher: the picker alone over the whole screen. Hyprland blurs every
    // aequalyn-* layer, so the desktop shows through blurred and dimmed.
    PanelWindow {
        id: switcherWin
        visible: root.surface === "switcher"
        focusable: true
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "aequalyn-switcher"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }

        Loader {
            anchors.fill: parent
            active: switcherWin.visible
            sourceComponent: Switcher { host: root }
            onLoaded: item.forceActiveFocus()
        }
    }
}
