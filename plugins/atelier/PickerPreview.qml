// The theme and wallpaper picker as Super + T / Super + W shows it, small: the real
// layouts with your themes (or wallpapers) over your blurred, dimmed desktop, so the
// control center's Theme picker page shows exactly what its settings do. Look, don't
// touch: clicks don't reach it.
import QtQuick
import QtQuick.Effects
import "layouts"
import "root:/settings"

Item {
    id: pv
    property var theme
    property string font: "JetBrainsMono Nerd Font"
    property string wallpaper: ""
    property string collection: "themes"       // "themes" | "wallpapers"
    clip: true

    // the screen the picker opens on, laid out at a real size and scaled to fit
    readonly property real screenW: 1440
    readonly property real screenH: 810
    readonly property real k: Math.min(width / screenW, height / screenH)

    readonly property var layoutKeys: ["slices", "showcase", "carousel", "grid", "filmstrip", "radial", "list", "spotlight"]
    readonly property string type: {
        const l = (AequalynSettings.atelierCfg.layouts || {})[collection];
        return layoutKeys.indexOf(l) >= 0 ? l : "slices";
    }

    // ---- the items, listed the way the picker lists them (Atelier.qml) ------------------
    readonly property var themeItems: {
        const t = pv.theme;
        if (!t || !t.folderThemes) return [];
        const wp = AtelierService.current;
        return [{
            key: "wallpaper", kind: "wallpaper", title: "Wallpaper colours", subtitle: "Made from whatever wallpaper is on",
            image: wp && !/\.(mp4|webm|mkv|mov)$/i.test(wp) ? wp : "",
            palette: t.wallpaperTheme && t.wallpaperTheme.bgBase ? t.wallpaperTheme : null,
            active: !!t.wallpaperMode
        }].concat(t.folderThemes.filter(f => f.hasPalette && (f.backgrounds || []).length > 0).map(f => ({
            key: "theme:" + f.id, kind: "folder", id: f.id, title: f.name, subtitle: f.family,
            image: f.preview || f.backgrounds[0], palette: f, backgrounds: f.backgrounds, dir: f.dir || "",
            active: !t.wallpaperMode && t.currentFolderId === f.id
        })));
    }
    readonly property var wallpaperItems: AtelierService.wallpapers.map(w => ({
        key: w.path, kind: "image", path: w.path, title: w.name, subtitle: w.folder,
        image: w.thumb, video: w.video, active: w.path === AtelierService.current,
        badge: w.video ? "LIVE" : w.generated ? "PAINTED" : w.theme ? "THEME" : "",
        group: w.video ? "live" : w.generated ? "painted" : w.theme ? "theme" : "image"
    }))
    readonly property var items: collection === "wallpapers" ? wallpaperItems : themeItems
    readonly property int current: Math.max(0, items.findIndex(it => it.active))
    Component.onCompleted: if (AtelierService.wallpapers.length === 0) AtelierService.refresh()

    // what the layouts ask of the picker around them
    QtObject {
        id: host
        property string collection: pv.collection
        property string surface: "switcher"
        function isFavorite(it) {
            const favs = (AequalynSettings.atelierCfg.favorites || {})[pv.collection] || [];
            return !!it && favs.indexOf(it.key) >= 0;
        }
        function toggleFavorite(it) {}
    }

    // ---- the screen -----------------------------------------------------------------
    // the desktop around the screen too, so the picture fills its space
    Desk {
        anchors.fill: parent
        theme: pv.theme
        source: pv.wallpaper
        radius: 14
        layer.enabled: true
        layer.effect: MultiEffect { blurEnabled: true; blur: 0.8; blurMax: 32 }
    }
    Rectangle {
        anchors.fill: parent
        radius: 14
        color: Qt.rgba(0, 0, 0, 0.45)
    }
    Item {
        id: screen
        width: pv.screenW
        height: pv.screenH
        scale: pv.k
        transformOrigin: Item.TopLeft
        x: (pv.width - pv.screenW * pv.k) / 2
        y: (pv.height - pv.screenH * pv.k) / 2

        // the desktop, blurred and dimmed the way the picker shows it
        Desk {
            id: desk
            anchors.fill: parent
            theme: pv.theme
            source: pv.wallpaper
            radius: 0
            layer.enabled: true
            layer.effect: MultiEffect { blurEnabled: true; blur: 0.7; blurMax: 48 }
        }
        Rectangle {
            anchors.fill: parent
            // Slices dims the desktop itself, Spotlight not at all
            color: Qt.rgba(0, 0, 0, pv.type === "spotlight" || pv.type === "slices" ? 0 : 0.35)
        }

        Loader {
            anchors.fill: parent
            anchors.margins: pv.type === "spotlight" || pv.type === "slices" ? 0 : 48
            anchors.bottomMargin: pv.type === "spotlight" || pv.type === "slices" ? 0 : 72
            sourceComponent: {
                switch (pv.type) {
                case "slices": return slicesC;
                case "grid": return gridC;
                case "carousel": return carouselC;
                case "filmstrip": return filmstripC;
                case "radial": return radialC;
                case "list": return listC;
                case "spotlight": return spotlightC;
                default: return showcaseC;
                }
            }
        }
        Text {
            visible: pv.type !== "slices"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 18
            text: (pv.collection === "themes" ? "Themes" : "Wallpapers")
                + "   ·   enter apply   ·   esc close   ·   type to filter   ·   tab "
                + (pv.collection === "themes" ? "wallpapers" : "themes")
            color: Qt.rgba(1, 1, 1, 0.6)
            font.family: pv.font
            font.pixelSize: 11
        }
        // look, don't touch
        MouseArea { anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.AllButtons; onWheel: w => w.accepted = false }
    }

    Component { id: slicesC
        SlicePicker { theme: pv.theme; items: pv.items; currentIndex: pv.current
            readonly property var own: AequalynSettings.pickerCfg("slices", pv.collection)
            readonly property var shared: ((AequalynSettings.atelierCfg.cards || {})[pv.collection]) || ({})
            shape: shared.shape !== undefined ? shared.shape : (own.shape || "original")
            position: own.position || "center"
            size: Number(own.size) || 100 } }
    Component { id: showcaseC
        LayoutShowcase { theme: pv.theme; font: pv.font; items: pv.items; currentIndex: pv.current; host: host } }
    Component { id: gridC
        LayoutGrid { theme: pv.theme; font: pv.font; collection: pv.collection; items: pv.items; currentIndex: pv.current } }
    Component { id: carouselC
        LayoutCarousel { theme: pv.theme; font: pv.font; collection: pv.collection; items: pv.items; currentIndex: pv.current } }
    Component { id: filmstripC
        LayoutFilmstrip { theme: pv.theme; font: pv.font; collection: pv.collection; items: pv.items; currentIndex: pv.current } }
    Component { id: radialC
        LayoutRadial { theme: pv.theme; font: pv.font; collection: pv.collection; items: pv.items; currentIndex: pv.current } }
    Component { id: listC
        LayoutList { theme: pv.theme; font: pv.font; collection: pv.collection; items: pv.items; currentIndex: pv.current } }
    Component { id: spotlightC
        LayoutSpotlight { theme: pv.theme; font: pv.font; collection: pv.collection; items: pv.items; currentIndex: pv.current } }
}
