// Atelier -- one place for everything that sets the look of the desktop.
//
//   Themes      folder themes (palette + backgrounds), wallpaper colours and
//               the curated palettes, with live preview while browsing
//   Wallpapers  images, videos, theme backgrounds and painted wallpapers
//   Layouts     33 window layouts plus Hyprland's own, per workspace, with
//               the Super + L cycle (aequalyn-layout)
//   Rotation    how wallpapers change (static, theme set, slideshow, time of
//               day, per workspace, live) and the transition between them
//   Palette     where colours come from and how they are generated
//   Bar         the bar's shape and look: 32 ready made looks and every part
//   Docks       up to 16 docks, styled with the bar or each on its own
//   Panel       how Atelier opens and what its two bar buttons do
//
// It opens three ways, set in the Panel tab and switched live with the
// header's Pop out / Dock / Full screen buttons:
//   panel       docked under the Atelier or Layouts button on the bar
//   window      a window of its own ("Atelier", for window rules)
//   overlay     full screen over everything
// All three show the same AtelierView; the state lives here, so switching
// keeps the tab, search and selection.
//
// IPC:  qs ipc call atelier toggle [themes|wallpapers|layouts|rotation|palette|bar|docks|panel]
//       qs ipc call atelier open <tab> | close | layout <name>
//       qs ipc call atelier popout | dock | fullscreen
//       qs ipc call wallpaper next | prev | random | set <file> | mode <mode>

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
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

    // "" (closed), "panel", "window", "overlay" or "switcher" (themes and wallpapers
    // alone over the blurred desktop)
    property string surface: ""
    readonly property bool shown: surface !== ""
    property var anchorButton: null
    readonly property string openAs: AequalynSettings.atelierCfg.openAs || "panel"
    // themes and wallpapers open in the switcher instead of the full Atelier
    readonly property bool useSwitcher: AequalynSettings.atelierCfg.switcher !== false
    readonly property bool canDock: anchorButton !== null || Object.keys(AtelierHost.buttons).length > 0

    onSurfaceChanged: {
        AtelierHost.shown = shown;
        AtelierHost.shownCollection = shown ? collection : "";
        if (!shown && theme) theme.previewPalette = null;
    }
    onCollectionChanged: AtelierHost.shownCollection = shown ? collection : ""

    readonly property var collections: [
        { key: "themes", icon: "󰏘", name: "Themes" },
        { key: "wallpapers", icon: "󰸉", name: "Wallpapers" },
        { key: "layouts", icon: "󰕰", name: "Layouts" },
        { key: "rotation", icon: "󰑓", name: "Rotation" },
        { key: "palette", icon: "󰌁", name: "Palette" },
        { key: "bar", icon: "󰍜", name: "Bar" },
        { key: "docks", icon: "󱂬", name: "Docks" },
        { key: "panel", icon: "󰕮", name: "Panel" }
    ]
    readonly property var layoutKeys: ["grid", "carousel", "filmstrip", "radial", "list", "spotlight", "showcase"]
    readonly property bool browsing: collection === "themes" || collection === "wallpapers"
    readonly property bool searchable: browsing || collection === "layouts"
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

    // One line under the title: where you are and what is running.
    readonly property string statusLine: {
        const ws = LayoutService.focusedWorkspace;
        const lay = LayoutService.find(LayoutService.layoutOf(ws));
        const t = root.theme;
        const look = !t ? "" : t.wallpaperMode ? "Wallpaper colours" : (t.committed ? t.committed.name : "");
        const m = AtelierService.modeInfo(AtelierService.mode).name;
        return "Workspace " + ws + " · " + (lay ? lay.name : "…") + " · " + look + " · " + m;
    }

    // Settings that differ from their defaults, for the footer and Reset all.
    readonly property int changed: {
        let n = 0;
        const pairs = [
            [AequalynSettings.wallpaperCfg, AequalynSettings.wallpaperDefaults],
            [AequalynSettings.paletteCfg, AequalynSettings.paletteDefaults],
            [AequalynSettings.atelierCfg, AequalynSettings.atelierDefaults]
        ];
        for (const [cur, def] of pairs)
            for (const k in cur)
                if (k in def && JSON.stringify(cur[k]) !== JSON.stringify(def[k])) n++;
        return n;
    }

    property bool confirmReset: false
    Timer { id: resetTimer; interval: 3000; onTriggered: root.confirmReset = false }
    function resetAll() {
        if (!confirmReset) { confirmReset = true; resetTimer.restart(); return; }
        confirmReset = false;
        AequalynSettings.resetSections(["wallpaper", "palette", "atelier", "barStyle"]);
    }

    // ---- opening and closing -------------------------------------------
    function focusedScreenName() {
        const m = Hyprland.focusedMonitor;
        return m ? m.name : "";
    }

    // Open on a tab, the way the Panel tab says (or `how`).
    function open(which, anchor, how) {
        if (which && which !== "") setCollection(which);
        if (collection === "wallpapers" || AtelierService.wallpapers.length === 0) AtelierService.refresh();
        LayoutService.refresh();
        searchText = "";
        filter = "all";
        selectActive();
        if (!how && useSwitcher && browsing) { surface = "switcher"; return; }
        show(how || openAs, anchor || null);
    }

    // From the switcher: the full Atelier on the same tab, where its look is set.
    function openSettings() {
        const c = collection;
        surface = "";
        show(openAs, null);
        collection = c;
    }

    function show(how, anchor) {
        if (how === "panel") {
            const btn = anchor || AtelierHost.buttonOn(focusedScreenName(), collection);
            if (btn) {
                anchorButton = btn;
                surface = "panel";
                return;
            }
            // No button on the bar to hang from: use the window instead.
            how = "window";
        }
        surface = how === "window" ? "window" : "overlay";
    }

    function close() { surface = ""; }

    function toggle(which, anchor) {
        if (shown && (!which || which === "" || which === collection)) close();
        else if (surface === "switcher" && which && which !== "themes" && which !== "wallpapers") open(which, anchor);
        else if (shown && which) { setCollection(which); if (anchor && surface === "panel") anchorButton = anchor; }
        else open(which, anchor);
    }

    function popOut() { show("window", null); }
    function dock() { show("panel", anchorButton); }
    function fullscreen() { show("overlay", null); }

    function setCollection(c) {
        if (collections.every(x => x.key !== c)) return;
        if (root.theme) root.theme.previewPalette = null;
        collection = c;
        searchText = "";
        filter = "all";
        selectActive();
        if (c === "wallpapers") AtelierService.refresh();
        if (c === "layouts") { LayoutService.refresh(); collectionOpened(c); }
    }
    signal collectionOpened(string c)

    function cycleCollection(d) {
        const keys = collections.map(c => c.key);
        setCollection(keys[(keys.indexOf(collection) + d + keys.length) % keys.length]);
    }

    function search(text) { searchText = text; currentIndex = 0; preview(); }
    function setFilter(f) { filter = f; currentIndex = 0; preview(); }

    // ‹ › in the header: layouts on the Layouts tab, wallpapers elsewhere.
    function step(d) {
        if (collection === "layouts")
            LayoutService.run(["aequalyn-layout", d > 0 ? "next" : "prev", "--workspace", LayoutService.focusedWorkspace]);
        else if (d > 0) AtelierService.next();
        else AtelierService.prev();
    }

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
    // cursor until you pick one or close Atelier.
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

    // ---- bar buttons ---------------------------------------------------
    Connections {
        target: AtelierHost
        function onToggleRequested(collection, anchorItem, screenName) {
            root.toggle(collection, anchorItem);
        }
        function onOpenRequested(collection, screenName) {
            if (root.shown) root.setCollection(collection);
            else root.open(collection, AtelierHost.buttonOn(screenName || root.focusedScreenName(), "bar"));
        }
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
        function popout(): void { root.shown ? root.popOut() : root.open("", null, "window"); }
        function dock(): void { root.shown ? root.dock() : root.open("", null, "panel"); }
        function fullscreen(): void { root.shown ? root.fullscreen() : root.open("", null, "overlay"); }
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

    // ---- surface 1: docked panel under the bar button ----------------------
    // Anchored to the bar window's bottom edge right under the button, sliding
    // along the bar only. A click outside or Esc closes it.
    PopupWindow {
        id: popup
        visible: root.surface === "panel" && root.anchorButton !== null
        color: "transparent"

        readonly property var barWin: root.anchorButton ? root.anchorButton.QsWindow.window : null
        readonly property var scr: barWin ? barWin.screen : null
        implicitWidth: Math.min(AequalynSettings.atelierCfg.panelWidth || 1180, (scr ? scr.width : 1920) - 16)
        implicitHeight: Math.min(AequalynSettings.atelierCfg.panelHeight || 780, (scr ? scr.height : 1080) - (barWin ? barWin.height : 32) - 16)

        anchor.window: barWin
        anchor.rect.x: root.anchorButton ? root.anchorButton.mapToItem(null, 0, 0).x : 0
        anchor.rect.y: barWin ? barWin.height - 1 : 0
        anchor.rect.width: root.anchorButton ? root.anchorButton.width : 1
        anchor.rect.height: 1
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.adjustment: PopupAdjustment.SlideX

        Loader {
            id: panelView
            anchors.fill: parent
            anchors.topMargin: 6
            active: popup.visible
            sourceComponent: AtelierView { host: root; surface: "panel" }
            onLoaded: Qt.callLater(() => item.focusInput())
        }
    }

    HyprlandFocusGrab {
        windows: [popup]
        active: popup.visible
        onCleared: if (root.surface === "panel") root.close()
    }

    // ---- surface 2: a window of its own -------------------------------------
    FloatingWindow {
        id: win
        title: "Atelier"
        visible: root.surface === "window"
        color: "transparent"
        implicitWidth: AequalynSettings.atelierCfg.panelWidth || 1180
        implicitHeight: AequalynSettings.atelierCfg.panelHeight || 780
        // closed by the compositor (Super + Q): forget it
        onVisibleChanged: if (!visible && root.surface === "window") root.close()

        Loader {
            anchors.fill: parent
            active: win.visible
            sourceComponent: AtelierView { host: root; surface: "window" }
            onLoaded: Qt.callLater(() => item.focusInput())
        }
    }

    // ---- surface 3: full screen ------------------------------------------
    PanelWindow {
        id: overlay
        visible: root.surface === "overlay"
        focusable: true
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "aequalyn-atelier"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }

        Rectangle {
            anchors.fill: parent
            color: root.theme ? root.theme.bgOverlay : "#88000000"
            opacity: root.spotlight ? 0 : 1
            MouseArea { anchors.fill: parent; onClicked: root.close() }
        }

        Loader {
            id: overlayView
            anchors.centerIn: parent
            width: root.spotlight ? parent.width : Math.min(parent.width * 0.84, 1520)
            height: root.spotlight ? parent.height : Math.min(parent.height * 0.82, 940)
            active: overlay.visible
            sourceComponent: AtelierView { host: root; surface: "overlay" }
            onLoaded: Qt.callLater(() => item.focusInput())
            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        }
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
