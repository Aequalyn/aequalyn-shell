// The look every quick panel shares (the gear's panel, and the panels bar widgets open
// with a right click): the bar's palette and font, set by the bar (Bar.qml), so the
// parts in this folder need nothing passed to them.
pragma Singleton
import QtQuick
import Quickshell
import ".."

Singleton {
    readonly property var fallback: DefaultTheme { }
    property var theme: fallback
    property string mono: "JetBrainsMono Nerd Font"
    readonly property string sans: "sans-serif"
    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
}
