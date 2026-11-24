// Clipscape in the bar. A click opens the same picker as Super + Ctrl + V; the click
// you choose on the Bar page (a right click unless you change it), its quick panel.
import QtQuick
import Quickshell
import "root:/plugins/clipscape"
import "root:/plugins/clipscape/qml/js/Clips.js" as Clips

Rectangle {
    required property var bar
    // the colour the bar gives it (Bar page: the widgets' colours), transparent for its own
    property color ink: "transparent"

    id: button
    objectName: "aequalyn-clipscape-button"
    Accessible.role: Accessible.Button
    Accessible.name: "Open clipboard history"

    width: 28
    height: 24
    radius: 8
    color: area.containsMouse || quick.visible ? bar.theme.bgSelected : bar.chipColor

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
        color: bar.inked(ink, bar.theme.accentPrimary)
        font.pixelSize: 13
        font.family: bar.iconFont
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: mouse => {
            const role = button.bar.clickRole("clipscape", mouse.button)
            if (role === "quick") { button.toggleQuick(); return }
            if (role === "right") { button.bar.openPage("clipboard"); return }
            if (mouse.button === Qt.MiddleButton && cfg && cfg.middleClick === "pause") {
                svc.togglePaused()
            } else if (mouse.button !== Qt.MiddleButton || !cfg || cfg.middleClick !== "none") {
                svc.openPicker("")
            }
        }
    }

    // its quick panel (ClipscapeQuick.qml)
    function toggleQuick() {
        const w = button.QsWindow.window
        button.bar.toggleWidgetPopup("clipscape", w ? w.screen : null)
    }
    ClipscapeQuick {
        id: quick
        bar: button.bar
        anchorItem: button
        open: button.bar.widgetPopup === "clipscape" && !!button.QsWindow.window
              && button.QsWindow.window.screen === button.bar.popupScreen
        onDismissed: button.bar.widgetPopup = ""
    }
}
