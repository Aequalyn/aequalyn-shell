// The link between the bar buttons and Atelier: buttons register where they
// sit, and ask for Atelier to open on a tab. Atelier decides how (docked
// panel under the button, its own window, or full screen) from the Panel tab.
pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    // "<screen>:<tab>" -> the Atelier / Layouts button on that screen's bar
    property var buttons: ({})

    // Atelier.qml listens to these.
    signal toggleRequested(string collection, var anchorItem, string screenName)
    signal actionRequested(string action)
    signal openRequested(string collection, string screenName)

    // The docks service, once it is up (for Atelier -> Docks), and the dock
    // whose settings to show.
    property var docks: null
    property int dockFocus: 0

    // Set by Atelier.qml: what is showing right now, for the buttons' look.
    property bool shown: false
    property string shownCollection: ""

    function register(screenName, item) {
        const next = Object.assign({}, buttons);
        next[screenName] = item;
        buttons = next;
    }
    function unregister(screenName, item) {
        if (buttons[screenName] !== item) return;
        const next = Object.assign({}, buttons);
        delete next[screenName];
        buttons = next;
    }
    // The button to dock under: the one for this tab on this screen, else
    // any button on this screen, else any button at all.
    function buttonOn(screenName, tab) {
        const exact = buttons[screenName + ":" + tab];
        if (exact) return exact;
        const fallbackTab = tab === "layouts" ? "layouts" : "themes";
        if (buttons[screenName + ":" + fallbackTab]) return buttons[screenName + ":" + fallbackTab];
        for (const k in buttons) if (k.indexOf(screenName + ":") === 0) return buttons[k];
        for (const k in buttons) return buttons[k];
        return null;
    }

    // Open on a tab (never closes, unlike toggle): a dock's right click.
    function open(collection, screenName) {
        openRequested(collection || "", screenName || "");
    }
    function toggle(collection, anchorItem, screenName) {
        toggleRequested(collection || "", anchorItem || null, screenName || "");
    }
    // What a right or middle click on a bar button does:
    // "next-layout", "prev-layout", "next-wallpaper", "random-wallpaper", "themes", "none"
    function act(action) {
        if (action && action !== "none") actionRequested(action);
    }
}
