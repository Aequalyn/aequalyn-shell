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
    readonly property string sans: "sans-serif"
    readonly property string mono: "JetBrainsMono Nerd Font"

    // the picture on the desktop right now (empty while unknown)
    property string wallpaper: ""

    // non visual helpers that outlive a page: default apps, updates, backup
    property var apps: null
    property var updates: null
    property var backup: null

    // pages ask the window for these
    signal goRequested(string page)
    signal closeRequested()
    function go(page) { goRequested(page); }
    function close() { closeRequested(); }

    // a colour, see-through
    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }

    function run(args) { Quickshell.execDetached(args); }
    // another part of the shell, through its IPC; the control center closes first
    // when that part opens over the screen
    function ipc(args, closeFirst) {
        if (closeFirst) close();
        Quickshell.execDetached(["qs", "ipc", "call"].concat(args));
    }
}
