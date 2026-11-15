// The theme and wallpaper picker, over the dimmed desktop: Super + T for themes,
// Super + W for wallpapers. A theme brings its colours and its wallpaper; a wallpaper
// changes only the wallpaper and keeps the theme.
//
//   ← → / Tab / Shift+Tab  move          Enter  apply and close
//   type                   filter        Backspace  remove a letter
//   Esc                    clear the filter, or close
//   Ctrl+,                 the Theme page of the control center
import QtQuick
import Quickshell

FocusScope {
    id: sw
    property var host

    SlicePicker {
        anchors.fill: parent
        theme: sw.host.theme
        items: sw.host.items
        currentIndex: sw.host.currentIndex
        filterText: sw.host.searchText
        onHovered: i => sw.host.currentIndex = i
        onPicked: i => sw.host.apply(i, true)
        onCancelled: sw.host.close()
    }

    function handleKey(event) {
        const ctrl = event.modifiers & Qt.ControlModifier;
        const n = host.items.length;
        if (event.key === Qt.Key_Escape) {
            if (host.searchText !== "") host.search("");
            else host.close();
            return true;
        }
        if (ctrl && event.key === Qt.Key_Comma) { host.openSettings(); return true; }
        if (n && (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab)) { host.move(-1); return true; }
        if (n && (event.key === Qt.Key_Right || event.key === Qt.Key_Tab)) { host.move(1); return true; }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { if (n) host.apply(host.currentIndex, true); return true; }
        if (event.key === Qt.Key_Backspace) { host.search(host.searchText.slice(0, -1)); return true; }
        if (!ctrl && event.text && event.text.length === 1 && event.text > " ") { host.search(host.searchText + event.text); return true; }
        return false;
    }
    focus: true
    Keys.onPressed: event => { if (handleKey(event)) event.accepted = true; }
}
