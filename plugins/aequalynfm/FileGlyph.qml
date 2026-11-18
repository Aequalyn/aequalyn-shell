import QtQuick
import Quickshell
import Quickshell.Widgets
import "root:/plugins/aequalynfm/compat"

// how one file looks: its thumbnail when there is one, else the system theme's
// icon that the daemon resolved, with the same soft mat for pictures as before
Item {
    id: glyph

    property string slot: "file"
    property string icon: ""
    property string thumb: ""
    property string kind: "file"
    property real size: Theme.dp(64)
    property bool hovered: false
    // kept for callers: Aequalyn always uses system icons, so it has no effect
    property bool legacy: false
    readonly property bool rig: (Quickshell.env("AEQUALYN_FM_SHOT") || "") !== ""
    readonly property bool showThumb: glyph.thumb !== "" && thumbImg.status !== Image.Error

    implicitWidth: glyph.size
    implicitHeight: glyph.size

    TonalIcon {
        anchors.centerIn: parent
        size: glyph.size
        slot: glyph.slot
        iconPath: glyph.icon
        hovered: glyph.hovered
        visible: !glyph.showThumb
    }

    // a picture keeps its own shape, on a soft mat with rounded corners. offscreen
    // grabs cannot draw a clipping rectangle, so the rig gets the plain picture
    Image {
        anchors.centerIn: parent
        width: thumbImg.paintedWidth
        height: thumbImg.paintedHeight
        visible: glyph.rig && glyph.showThumb && thumbImg.status === Image.Ready
        source: glyph.rig ? thumbImg.source : ""
        smooth: true
    }

    // a picture fades in as it arrives, rather than popping over the icon
    ClippingRectangle {
        visible: opacity > 0
        opacity: !glyph.rig && glyph.showThumb && thumbImg.status === Image.Ready ? 1 : 0
        anchors.centerIn: parent
        width: Math.max(1, thumbImg.paintedWidth)
        height: Math.max(1, thumbImg.paintedHeight)
        radius: Math.max(Theme.dp(4), Math.min(width, height) * 0.08)
        color: Theme.surfaceHigh

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durMedium
            }
        }

        Image {
            anchors.fill: parent
            source: thumbImg.source
            fillMode: Image.Stretch
            asynchronous: true
            smooth: true
            mipmap: true
        }
    }

    // measures the picture's fit without being drawn itself
    Image {
        id: thumbImg

        anchors.fill: parent
        anchors.margins: glyph.size * 0.04
        visible: false
        source: glyph.thumb !== "" ? "file://" + glyph.thumb : ""
        sourceSize: Qt.size(Math.ceil(glyph.size * 2), Math.ceil(glyph.size * 2))
        fillMode: Image.PreserveAspectFit
        asynchronous: true
    }
}
