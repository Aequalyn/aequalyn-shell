// What every control center page shares: the colours, the two fonts, and a way to
// open another page or run a command. Set up by ControlCenter.qml.
pragma Singleton

import QtQuick
import Quickshell
import "root:/settings"

Singleton {
    id: cc
    // the shell's live palette (ControlCenter binds it); a fallback until then
    property var theme: fallback
    readonly property QtObject fallback: AequalynDefaultTheme {}

    // words in a plain sans, numbers, keys and icons in the shell's mono
    readonly property string sans: (AequalynSettings.uiFont && AequalynSettings.uiFont.length) ? AequalynSettings.uiFont : "sans-serif"
    readonly property string mono: (AequalynSettings.monoFont && AequalynSettings.monoFont.length) ? AequalynSettings.monoFont : "JetBrainsMono Nerd Font"

    // the picture on the desktop right now (empty while unknown)
    property string wallpaper: ""

    // non visual helpers that outlive a page: default apps, updates, backup
    property var apps: null
    property var updates: null
    property var backup: null
    property var webapps: null

    // the sub page a page opens on (set by the window before it makes the page)
    property int startTab: 0

    // pages ask the window for these
    signal goRequested(string page)
    signal closeRequested()
    function go(page) { goRequested(page); }
    function close() { closeRequested(); }

    // a colour, see-through
    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }

    // ---- the one pattern every setting follows ---------------------------------------
    // A section (CcSection) holds its settings in one rounded group, a row each (CcToggle,
    // CcSlider, CcRow): its name and explanation on the left, its control on the right,
    // a hairline between rows. A row outside a section is a group of its own.
    // the section a row sits in, or null
    function sectionOf(item) {
        for (let p = item ? item.parent : null; p; p = p.parent) if (p.ccSection === true) return p;
        return null;
    }
    // in a section's group (one that draws its box), at any depth: on the box's colour
    function inGroup(item) { const s = sectionOf(item); return !!s && s.boxed; }
    // directly in a group's box (not inside a row of it): it needs room of its own
    function inGroupBody(item) {
        const body = item ? item.parent : null, box = body ? body.parent : null, sec = box ? box.parent : null;
        return !!sec && sec.ccSection === true && sec.boxed;
    }
    // the first shown item among `item`'s siblings: the row that gets no line above it
    function firstShown(parentItem) {
        if (!parentItem) return null;
        const c = parentItem.children;
        for (let i = 0; i < c.length; i++) if (c[i].visible && c[i].height > 0) return c[i];
        return null;
    }

    function run(args) { Quickshell.execDetached(args); }
    // another part of the shell, through its IPC; the control center closes first
    // when that part opens over the screen
    function ipc(args, closeFirst) {
        if (closeFirst) close();
        Quickshell.execDetached(["qs", "ipc", "call"].concat(args));
    }
}
