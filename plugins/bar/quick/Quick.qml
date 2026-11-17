// The look every quick panel shares (the gear's panel, and the panels bar widgets
// open): the bar's palette and font, set by the bar (Bar.qml), so the parts in this
// folder need nothing passed to them. Drawn like the Applications menu: one mono font,
// the name in the accent colour, a chosen thing on the selected colour with an accent
// edge.
pragma Singleton
import QtQuick
import Quickshell
import ".."

Singleton {
    readonly property var fallback: DefaultTheme { }
    property var theme: fallback
    property string mono: "JetBrainsMono Nerd Font"
    readonly property string sans: mono
    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
}
