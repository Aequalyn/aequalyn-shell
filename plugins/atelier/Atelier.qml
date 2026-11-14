// Atelier -- the engine behind the look of the desktop: the theme and wallpaper picker,
// and the panes the control center shows for wallpapers, colours, the bar, docks,
// window layouts and the picker itself.
//
//   Super + T / Super + W (and the bar's Themes button) open the picker alone over the
//   blurred desktop. Everything else that used to be a tab here is a page of the
//   control center now; asking Atelier for one opens that page:
//     layouts -> Arranging windows     rotation -> Wallpaper, over time
//     palette -> Theme, colours        bar -> Bar      docks -> Dock
//     panel   -> Theme picker
//
// IPC:  qs ipc call atelier toggle [themes|wallpapers|layouts|rotation|palette|bar|docks|panel]
//       qs ipc call atelier open <tab> | close | layout <picker type>
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
    property string filter: "all"
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
    readonly property var layoutKeys: ["grid", "carousel", "filmstrip", "radial", "list", "spotlight", "showcase"]
    readonly property bool browsing: true
    readonly property string layout: {
        const l = (AequalynSettings.atelierCfg.layouts || {})[collection];
        return layoutKeys.indexOf(l) >= 0 ? l : "showcase";
    }
    readonly property bool spotlight: browsing && layout === "spotlight"
    readonly property bool livePreview: AequalynSettings.atelierCfg.livePreview !== false

    // ---- items ---------------------------------------------------------
    readonly property var themeItems: {
        const t = root.theme;
        if (!t) return [];
        const out = [];
        const wp = AtelierService.current;
        const cf = t.currentFolderId !== "" ? t.folderTheme(t.currentFolderId) : null;
        out.push({
            key: "wallpaper", kind: "wallpaper",
            title: "Wallpaper colours",
            subtitle: "Follows whatever is on screen",
            detail: "Colours are generated from the current wallpaper with matugen and change with it.",
            image: wp && !/\.(mp4|webm|mkv|mov)$/i.test(wp) ? wp : "",
            palette: t.wallpaperTheme && t.wallpaperTheme.bgBase ? t.wallpaperTheme : null,
            active: t.wallpaperMode && !(cf && cf.kind === "pack"),
            badge: "DYNAMIC", group: "dynamic"
        });
        for (const f of t.folderThemes) {
            const n = (f.backgrounds || []).length;
            out.push({
                key: "theme:" + f.id, kind: "folder", id: f.id,
                title: f.name,
                subtitle: f.family + (n ? " · " + n + (n === 1 ? " background" : " backgrounds") : ""),
                detail: f.dir + (f.author ? "\nby " + f.author : ""),
                image: f.preview || ((f.backgrounds || [])[0] || ""),
                palette: f.hasPalette ? f : null,
                backgrounds: f.backgrounds || [], dir: f.dir || "",
                active: t.currentFolderId === f.id && (f.hasPalette ? !t.wallpaperMode : true),
                badge: f.kind === "pack" ? "PACK" : (f.family && f.family !== "Aequalyn" ? f.family.toUpperCase() : ""),
                group: f.kind === "pack" ? "pack" : "theme",
                light: f.hasPalette ? t.isLightColor(f.bgBase) : false
            });
        }
        for (let i = 0; i < t.themes.length; i++) {
            const p = t.themes[i];
            out.push({
                key: "palette:" + i, kind: "palette", index: i,
                title: p.name, subtitle: p.family,
                detail: "Palette only: keeps your current wallpaper.",
                image: "", palette: p,
                active: !t.wallpaperMode && t.currentFolderId === "" && t.currentIndex === i,
                badge: "", group: "palette",
                light: t.isLightColor(p.bgBase)
            });
        }
        return out;
    }

    readonly property var wallpaperItems: AtelierService.wallpapers.map(w => ({
        key: w.path, kind: "image", path: w.path,
        title: w.name, subtitle: w.folder,
        detail: w.path,
        image: w.thumb, video: w.video,
        active: w.path === AtelierService.current,
        badge: w.video ? "LIVE" : w.generated ? "PAINTED" : w.theme ? "THEME" : "",
        group: w.video ? "live" : w.generated ? "painted" : w.theme ? "theme" : "image"
    }))

    readonly property var filters: collection === "themes"
        ? [["all", "All"], ["fav", "★ Favourites"], ["recent", "Recent"], ["theme", "With backgrounds"], ["palette", "Palettes"], ["dark", "Dark"], ["light", "Light"]]
        : [["all", "All"], ["fav", "★ Favourites"], ["recent", "Recent"], ["image", "Images"], ["live", "Live"], ["theme", "Theme"], ["painted", "Painted"]]

    readonly property var items: {
        const src = collection === "themes" ? themeItems : collection === "wallpapers" ? wallpaperItems : [];
        const q = searchText.toLowerCase();
        return src.filter(it => {
            if (q !== "" && (it.title + " " + it.subtitle).toLowerCase().indexOf(q) < 0) return false;
            switch (root.filter) {
            case "all": return true;
            case "theme": return collection === "themes" ? (it.group === "theme" || it.group === "pack") : it.group === "theme";
            case "dark": return it.group === "dynamic" || (it.palette && !it.light);
            case "fav": return root.isFavorite(it);
            case "recent": return root.recentKeys.indexOf(it.key) >= 0;
            case "light": return !!it.light;
            default: return it.group === root.filter;
            }
        });
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
        filter = "all";
        selectActive();
        if (c === "wallpapers") AtelierService.refresh();
    }

    function search(text) { searchText = text; currentIndex = 0; preview(); }
    function setFilter(f) { filter = f; currentIndex = 0; preview(); }

    function setLayout(l) {
        if (!browsing || layoutKeys.indexOf(l) < 0) return;
        const next = Object.assign({}, AequalynSettings.atelierCfg.layouts || {});
        next[collection] = l;
        AequalynSettings.setIn("atelier", "layouts", next);
    }

    function selectActive() {
        const list = items;
        for (let i = 0; i < list.length; i++) if (list[i].active) { currentIndex = i; return; }
        currentIndex = 0;
    }

    function move(delta) {
        const n = items.length;
        if (n === 0) return;
        const wraps = layout === "carousel" || layout === "radial";
        let i = currentIndex + delta;
        i = wraps ? (i % n + n) % n : Math.max(0, Math.min(n - 1, i));
        currentIndex = i;
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
        case "wallpaper":
            t.previewPalette = null;
            t.setWallpaperMode();
            AequalynSettings.retheme();
            break;
        case "folder":
            t.setFolderTheme(it.id);
            break;
        case "palette":
            t.setTheme(it.index);
            break;
        case "image":
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

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, root.spotlight ? 0 : 0.35)
            MouseArea { anchors.fill: parent; onClicked: root.close() }
        }
        Loader {
            anchors.fill: parent
            active: switcherWin.visible
            sourceComponent: Switcher { host: root }
            onLoaded: item.forceActiveFocus()
        }
    }
}
