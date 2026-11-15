// The theme and wallpaper switcher: just the picker, over the blurred desktop. No
// header, tabs or settings around it: its type, shape and place are set on the control
// center's Theme picker page, and Ctrl+, opens it from here.
//
// Slices (the default type): ← → / Tab / Shift+Tab move, Enter apply, type to filter,
// Esc clears the filter or closes. The other types:
//   ← → (↑ ↓ when vertical)  move        ↑ ↓ (← → when vertical)  pick a background
//   Enter  apply and close (Shift+Enter keeps it open)       Esc  close
//   type   filter            Tab  themes ⇄ wallpapers        Ctrl+F  favourite
//   Ctrl+1..8  another type of picker                        click outside  close
//   Ctrl+, the Theme picker page of the control center
import QtQuick
import Quickshell
import "root:/settings"
import "layouts"

FocusScope {
    id: sw
    property var host
    readonly property var theme: host.theme
    readonly property string font: host.font
    readonly property bool hasItems: host.items.length > 0
    readonly property bool slices: host.layout === "slices"

    // the type of picker is the layout chosen for this tab in Atelier
    Loader {
        id: layout
        anchors.fill: parent
        anchors.margins: sw.host.layout === "spotlight" || sw.slices ? 0 : 48
        anchors.bottomMargin: sw.host.layout === "spotlight" || sw.slices ? 0 : 72
        sourceComponent: {
            switch (sw.host.layout) {
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

    // what you typed, and the keys (Slices shows what you typed itself)
    Column {
        visible: !sw.slices
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 18
        spacing: 8
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: sw.host.searchText !== "" || !sw.hasItems
            height: 26
            width: searchText.implicitWidth + 28
            radius: 13
            color: Qt.rgba(0, 0, 0, 0.55)
            Text {
                id: searchText
                anchors.centerIn: parent
                text: !sw.hasItems && sw.host.searchText !== "" ? "Nothing matches “" + sw.host.searchText + "”"
                    : !sw.hasItems ? "Nothing here yet"
                    : "⌕  " + sw.host.searchText
                color: "#ffffff"
                font.family: sw.font
                font.pixelSize: 12
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: (sw.host.collection === "themes" ? "Themes" : "Wallpapers")
                + "   ·   enter apply   ·   esc close   ·   type to filter   ·   tab "
                + (sw.host.collection === "themes" ? "wallpapers" : "themes") + "   ·   ctrl+, settings"
            color: Qt.rgba(1, 1, 1, 0.6)
            font.family: sw.font
            font.pixelSize: 11
        }
    }

    function handleKey(event) {
        const ctrl = event.modifiers & Qt.ControlModifier;
        const shift = event.modifiers & Qt.ShiftModifier;
        const l = layout.item;
        if (event.key === Qt.Key_Escape) {
            if (host.searchText !== "") host.search("");
            else host.close();
            return true;
        }
        if (ctrl && event.key === Qt.Key_Comma) { host.openSettings(); return true; }
        // Slices: Tab moves, like the arrows; Enter applies and closes
        if (sw.slices) {
            const count = host.items.length;
            if (count && (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab)) { host.move(-1); return true; }
            if (count && (event.key === Qt.Key_Right || event.key === Qt.Key_Tab)) { host.move(1); return true; }
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { if (count) host.apply(host.currentIndex, true); return true; }
        }
        // Ctrl + 1..8: another type of picker for this collection
        if (ctrl && event.key >= Qt.Key_1 && event.key <= Qt.Key_8) {
            host.setLayout(host.layoutKeys[event.key - Qt.Key_1]);
            return true;
        }
        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            host.setCollection(host.collection === "themes" ? "wallpapers" : "themes");
            return true;
        }
        if (l && l.handleKey && l.handleKey(event)) return true;
        const n = host.items.length;
        if (n && (event.key === Qt.Key_Left || event.key === Qt.Key_Up)) { host.move(-1); return true; }
        if (n && (event.key === Qt.Key_Right || event.key === Qt.Key_Down)) { host.move(1); return true; }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { host.apply(host.currentIndex, !shift); return true; }
        if (ctrl && event.key === Qt.Key_F) { host.toggleFavorite(host.currentItem); return true; }
        if (event.key === Qt.Key_Backspace) { host.search(host.searchText.slice(0, -1)); return true; }
        if (!ctrl && event.text && event.text.length === 1 && event.text > " ") { host.search(host.searchText + event.text); return true; }
        return false;
    }
    focus: true
    Keys.onPressed: event => { if (handleKey(event)) event.accepted = true; }

    // ---- the layouts --------------------------------------------------------------
    Component { id: slicesC
        SlicePicker { theme: sw.theme; items: sw.host.items; currentIndex: sw.host.currentIndex; filterText: sw.host.searchText
            // this picker's own place, size and shape (themes or wallpapers)
            readonly property var own: AequalynSettings.pickerCfg("slices", sw.host.collection)
            shape: own.shape || "original"
            position: own.position || "center"
            size: Number(own.size) || 100
            onHovered: i => sw.host.currentIndex = i; onPicked: i => sw.host.apply(i, true); onCancelled: sw.host.close() } }
    // picking an item applies it and closes the switcher
    Component { id: showcaseC
        LayoutShowcase { theme: sw.theme; font: sw.font; items: sw.host.items; currentIndex: sw.host.currentIndex; host: sw.host
            onHovered: i => sw.host.currentIndex = i; onPicked: i => sw.host.apply(i, true) } }
    Component { id: gridC
        LayoutGrid { theme: sw.theme; font: sw.font; items: sw.host.items; currentIndex: sw.host.currentIndex
            onHovered: i => sw.host.currentIndex = i; onPicked: i => sw.host.apply(i, true) } }
    Component { id: carouselC
        LayoutCarousel { theme: sw.theme; font: sw.font; items: sw.host.items; currentIndex: sw.host.currentIndex
            onHovered: i => sw.host.currentIndex = i; onPicked: i => sw.host.apply(i, true) } }
    Component { id: filmstripC
        LayoutFilmstrip { theme: sw.theme; font: sw.font; items: sw.host.items; currentIndex: sw.host.currentIndex
            onHovered: i => sw.host.currentIndex = i; onPicked: i => sw.host.apply(i, true) } }
    Component { id: radialC
        LayoutRadial { theme: sw.theme; font: sw.font; items: sw.host.items; currentIndex: sw.host.currentIndex
            onHovered: i => sw.host.currentIndex = i; onPicked: i => sw.host.apply(i, true) } }
    Component { id: listC
        LayoutList { theme: sw.theme; font: sw.font; items: sw.host.items; currentIndex: sw.host.currentIndex
            onHovered: i => sw.host.currentIndex = i; onPicked: i => sw.host.apply(i, true) } }
    Component { id: spotlightC
        LayoutSpotlight { theme: sw.theme; font: sw.font; items: sw.host.items; currentIndex: sw.host.currentIndex
            onHovered: i => sw.host.currentIndex = i; onPicked: i => sw.host.apply(i, true) } }
}
