// Clipscape in the bar. Clicking it opens the same picker as Super + Ctrl + V.
import QtQuick
import Quickshell
import "root:/plugins/clipscape"
import "root:/plugins/clipscape/qml/js/Clips.js" as Clips

Rectangle {
    required property var bar

    id: button
    objectName: "aequalyn-clipscape-button"
    Accessible.role: Accessible.Button
    Accessible.name: "Open clipboard history"

    width: 28
    height: 24
    radius: 8
    color: area.containsMouse ? bar.theme.bgSelected : bar.chipColor

    readonly property var svc: ClipscapeService
    readonly property var cfg: svc.cfg
    readonly property string icon: svc.paused ? "󰏤" : "󰅌"

    readonly property string label: {
        if (!cfg) return icon
        if (cfg.barShows === "count") return icon + " " + svc.count
        if (cfg.barShows === "last") {
            const l = svc.clips.latest
            if (!l) return icon
            let t = Clips.title(l, true)
            if (l.secret) t = "••••••"
            if (t.length > 22) t = t.slice(0, 21) + "…"
            return icon + " " + t
        }
        return icon
    }

    Text {
        anchors.centerIn: parent
        text: button.label
        color: bar.theme.accentPrimary
        font.pixelSize: 13
        font.family: bar.font
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton && cfg && cfg.middleClick === "pause") {
                svc.togglePaused()
            } else if (mouse.button !== Qt.MiddleButton || !cfg || cfg.middleClick !== "none") {
                svc.openPicker("")
            }
        }
    }
}
