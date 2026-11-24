import QtQuick
import "root:/settings"

// Spartan loading indicator: a rotating Nerd glyph, no morphing shape.
Item {
    id: li

    property bool running: true
    property real size: 24

    implicitWidth: li.size
    implicitHeight: li.size
    width: li.size
    height: li.size

    Text {
        anchors.centerIn: parent
        text: "\u{F04CE}"
        color: Theme.accent
        font.family: AequalynSettings.monoFont
        font.pixelSize: li.size
        rotation: li.running ? 360 : 0
        Behavior on rotation { NumberAnimation { duration: 900; loops: Animation.Infinite } }
    }
}
