// Atelier -- the engine behind the look of the desktop: the theme and wallpaper picker,
// and the panes the control center shows for wallpapers, the bar, docks and window
// layouts.
//
//   Super + T: themes. A theme is its colours and its own wallpapers: picking one
//              applies both (its colours only, if "A theme brings its wallpapers" is
//              off). "Wallpaper colours", first, makes colours from the wallpaper.
//   Super + W: wallpapers. With a theme's colours: the theme's and your own, and the
//              colours stay. With wallpaper colours: every wallpaper, and the colours
//              follow it.
// Everything else that used to be a tab here is a page of the control center; asking
// Atelier for one opens that page:
//     layouts -> Arranging windows     rotation -> Wallpaper, over time
//     palette, panel -> Theme          bar -> Bar      docks -> Dock
//
// The type of picker (Slices, Showcase, Carousel, Grid...) is set per collection on the
// control center's Theme picker page.
//
// IPC:  qs ipc call atelier toggle [themes|wallpapers|layouts|rotation|palette|bar|docks|panel]
//       qs ipc call atelier open <tab> | close | layout <picker type>
//       qs ipc call wallpaper next | prev | random | set <file> | mode <mode>

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "root:/settings"
import "root:/style/backdrop"

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
        // (the surface itself, not `shown`: in this handler `shown` may not have caught up
        // yet, and a preview left behind would cover the theme you picked until next time)
        if (surface === "" && theme) theme.previewPalette = null;
    }
    onCollectionChanged: AtelierHost.shownCollection = shown ? collection : ""

    // what the picker shows
    readonly property var collections: [
        { key: "themes", icon: "󰏘", name: "Themes" },
        { key: "wallpapers", icon: "󰸉", name: "Wallpapers" }
    ]
    readonly property var layoutKeys: ["slices", "showcase", "carousel", "grid", "filmstrip", "radial", "list", "spotlight"]
    readonly property string layout: {
        const l = (AequalynSettings.atelierCfg.layouts || {})[collection];
        return layoutKeys.indexOf(l) >= 0 ? l : "slices";
    }
    readonly property bool spotlight: layout === "spotlight"
    readonly property bool livePreview: AequalynSettings.atelierCfg.livePreview !== false

    // ---- items ---------------------------------------------------------
    // Themes: "Wallpaper colours" first, then the ones with their own colours and
    // wallpapers.
    readonly property var themeItems: {
        const t = root.theme;
        if (!t || !t.folderThemes) return [];
        const wp = AtelierService.current;
        const dynamic = [{
            key: "wallpaper", kind: "wallpaper", title: "Wallpaper colours",
            subtitle: "Made from whatever wallpaper is on",
            image: wp && !/\.(mp4|webm|mkv|mov)$/i.test(wp) ? wp : "",
            palette: t.wallpaperTheme && t.wallpaperTheme.bgBase ? t.wallpaperTheme : null,
            active: t.wallpaperMode
        }];
        return dynamic.concat(t.folderThemes.filter(f => f.hasPalette && (f.backgrounds || []).length > 0).map(f => ({
            key: "theme:" + f.id, kind: "folder", id: f.id,
            title: f.name, subtitle: f.family,
            image: f.preview || f.backgrounds[0],
            palette: f, backgrounds: f.backgrounds, dir: f.dir || "",
            active: !t.wallpaperMode && t.currentFolderId === f.id
        })));
    }

    // Wallpapers: the current theme's first, then your own (your wallpaper folder);
    // other themes' wallpapers come with their theme, from Super + T.
    readonly property string currentThemeId: root.theme ? root.theme.currentFolderId : ""
    function ownedByTheme(w, id) { return id !== "" && w.path.indexOf("/" + id + "/backgrounds/") >= 0; }
    readonly property var wallpaperItems: {
        const id = currentThemeId;
        const all = AtelierService.wallpapers;
        // colours from the wallpaper: any wallpaper; from a theme: its own and yours
        const list = root.theme && root.theme.wallpaperMode ? all
            : all.filter(w => w.theme && ownedByTheme(w, id)).concat(all.filter(w => !w.theme && !w.generated));
        return list.map(w => ({
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

    function search(text) { searchText = text; currentKey = ""; currentIndex = 0; preview(); }

    function setLayout(l) {
        if (layoutKeys.indexOf(l) < 0) return;
        const next = Object.assign({}, AequalynSettings.atelierCfg.layouts || {});
        next[collection] = l;
        AequalynSettings.setIn("atelier", "layouts", next);
    }

    function selectActive() {
        const list = items;
        let at = 0;
        for (let i = 0; i < list.length; i++) if (list[i].active) { at = i; break; }
        currentIndex = at;
        // the active one is your item now, also while the list is still settling
        currentKey = list[at] ? list[at].key : "";
    }

    function move(delta) {
        const n = items.length;
        if (n === 0) return;
        const wraps = layout === "carousel" || layout === "radial";
        const i = currentIndex + delta;
        currentIndex = wraps ? (i % n + n) % n : Math.max(0, Math.min(n - 1, i));
    }

    // The item you are on, by its key, so it stays chosen when the list is made again (the
    // wallpapers read in as the picker opens, a theme applied marking another one active).
    // A view given a new list jumps to its first item (a carousel does); that jump isn't you
    // browsing, so it previews nothing, and you're put back on your item once the list settles.
    property string currentKey: ""
    property bool settling: false
    onCurrentIndexChanged: {
        if (settling) return;
        const it = items[currentIndex];
        currentKey = it ? it.key : "";
        preview();
    }
    onItemsChanged: {
        if (currentIndex >= items.length) currentIndex = Math.max(0, items.length - 1);
        settling = true;
        Qt.callLater(root.settle);
    }
    function settle() {
        settling = false;
        const i = currentKey === "" ? -1 : items.findIndex(it => it.key === currentKey);
        if (i >= 0 && i !== currentIndex) currentIndex = i;
        else if (i < 0) { const it = items[currentIndex]; currentKey = it ? it.key : ""; }
    }

    // Live preview: the whole shell takes the colours of the theme under the
    // cursor until you pick one or close the picker.
    function preview() {
        if (surface === "" || !root.theme || collection !== "themes" || !livePreview) return;
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
        case "wallpaper":
            // colours made from the wallpaper from now on
            t.previewPalette = null;
            t.setWallpaperMode();
            AequalynSettings.retheme();
            break;
        case "folder":
            // its colours, and its first wallpaper unless one of its own is on already
            t.setFolderTheme(it.id);
            break;
        case "image":
            // the wallpaper; the colours stay, unless they follow the wallpaper
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
        function layout(name: string): void { root.setLayout(name); }
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

    // The switcher: the picker alone over the whole screen, the desktop behind it blurred
    // and dimmed as Window look sets (style/backdrop).
    PanelWindow {
        id: switcherWin
        visible: veil.shown
        focusable: true
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: veil.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None   // none while it fades away
        WlrLayershell.namespace: veil.layerName("switcher")
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }

        // the desktop behind: Slices shades it in the theme's own colour, Spotlight not at all
        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
            Backdrop {
                id: veil
                open: root.surface === "switcher"
                theme: root.theme
                tintAlpha: root.layout === "slices" ? 0.72 : root.spotlight ? 0 : 0.35
            }
        }
        Loader {
            anchors.fill: parent
            opacity: veil.progress
            active: switcherWin.visible
            sourceComponent: Switcher { host: root }
            onLoaded: item.forceActiveFocus()
        }
    }
}
