import QtQuick
import Quickshell
import "Icons.js" as Icons
import "root:/settings"

// Folder and drive types are drawn as Nerd Font glyphs in the theme's accent
// colour, so they follow the palette the way the settings app's icons do. Other
// types (files, apps) keep the system icon theme's own art.
Item {
    id: ic

    property string slot: "file"
    property string iconPath: ""
    property string iconName: ""
    property real size: Theme.dp(64)
    property bool hovered: false

    implicitWidth: ic.size
    implicitHeight: ic.size
    width: ic.size
    height: ic.size

    readonly property string g: Icons.glyph(ic.slot)
    readonly property bool useGlyph: Icons.isGlyphSlot(ic.slot)

    function url(p) {
        if (!p) return "";
        return p.indexOf("file:") === 0 || p.indexOf("qrc:") === 0 ? p : "file://" + p;
    }

    // glyph path
    Text {
        visible: ic.useGlyph
        anchors.centerIn: parent
        text: ic.g
        color: ic.hovered ? Theme.accent : (ic.slot.indexOf("folder") === 0 || ic.slot === "home" || ic.slot === "desktop" ? Theme.accent : Theme.text)
        font.family: AequalynSettings.monoFont
        font.pixelSize: Math.round(ic.size * 0.72)
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    // system icon path (files, apps, network shares with their own art)
    Image {
        visible: !ic.useGlyph
        anchors.centerIn: parent
        width: ic.size
        height: ic.size
        source: ic.url(ic.iconPath !== "" ? ic.iconPath : (Quickshell.iconPath(ic.resolvedName(), true) || ""))
        sourceSize: Qt.size(Math.ceil(ic.size * 2), Math.ceil(ic.size * 2))
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
    }

    function resolvedName() {
        if (ic.iconName !== "") return ic.iconName;
        var map = ({
            "file": "text-x-generic",
            "app": "application-x-executable"
        });
        return map[ic.slot] || ic.slot || "text-x-generic";
    }
}
