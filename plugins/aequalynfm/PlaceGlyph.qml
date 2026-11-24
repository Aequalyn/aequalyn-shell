import QtQuick
import "root:/plugins/aequalynfm/compat"
import "root:/plugins/aequalynfm/compat/Icons.js" as Icons
import "root:/settings"

// Sidebar glyphs are Nerd Font codepoints in the row's own colour, so they
// follow the palette and the active-row accent the way the settings app's do.
Item {
    id: glyph

    property string slot: "folder"
    property string fallback: "folder"
    property real size: Theme.dp(20)
    property real fill: 1
    property color color: Theme.text
    property bool animateColor: true

    readonly property string g: Icons.glyph(glyph.slot !== "" ? glyph.slot : glyph.fallback)

    implicitWidth: glyph.size
    implicitHeight: glyph.size
    width: glyph.size
    height: glyph.size

    Text {
        anchors.centerIn: parent
        text: glyph.g
        color: glyph.color
        font.family: AequalynSettings.monoFont
        font.pixelSize: glyph.size
        Behavior on color { enabled: glyph.animateColor; ColorAnimation { duration: 120 } }
    }
}
