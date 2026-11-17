// Clipscape in the bar: left click opens the clip panel, right click its settings,
// middle click the picker. Everything lives in the ClipscapeService singleton.
import QtQuick
import Quickshell
import "root:/plugins/clipscape"
import "../../clipscape/qml/panel" as ClipPanel
import "root:/plugins/clipscape/qml/js/Clips.js" as Clips

Rectangle {
    required property var bar

    id: button
    objectName: "aequalyn-clipscape-button"
    Accessible.role: Accessible.Button
    Accessible.name: "Clipboard history"

    width: 28
    height: 24
    radius: 8
    color: area.containsMouse || panel.opened ? bar.theme.bgSelected : bar.chipColor

    readonly property var svc: ClipscapeService
    readonly property var ux: svc.ui
    readonly property var cfg: svc.cfg
    readonly property bool paused: svc.paused
    readonly property string icon: paused ? "󰏤" : "󰅌"

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
            ux.host = button
            if (mouse.button === Qt.LeftButton) toggle()
            else if (mouse.button === Qt.RightButton) showTab("settings")
            else if (cfg) {
                if (cfg.middleClick === "picker") svc.openPicker("")
                else if (cfg.middleClick === "pause") svc.togglePaused()
            }
        }
    }

    // ---- the panel / popped-out window -----------------------------------------------
    property bool userPicked: false
    readonly property bool popped: ux ? ux.popped : false
    readonly property bool opened: panel.opened
    property bool windowRequested: false

    function chooseMode() {
        if (userPicked || !cfg) return
        const want = cfg.openAs === "window"
        if (want === popped) return
        if (windowRequested) hideWindow()
        if (panel.opened) panel.close()
        ux.popped = want
    }
    function showWindow() { windowRequested = true; if (winLoader.item) winLoader.item.visible = true }
    function hideWindow() { windowRequested = false; if (winLoader.item) winLoader.item.visible = false }
    function openPanel() { panel.bar = button.bar; panel.anchorItem = button; panel.svc = svc; panel.open() }
    function closePanel() { panel.close() }
    function open() { chooseMode(); if (popped) showWindow(); else openPanel() }
    function close() { closePanel(); hideWindow() }
    function toggle() {
        chooseMode()
        if (popped) { if (windowRequested) hideWindow(); else showWindow() }
        else if (opened) closePanel()
        else openPanel()
    }
    function popOut() { userPicked = true; ux.popped = true; closePanel(); showWindow() }
    function dock() { userPicked = true; hideWindow(); ux.popped = false; Qt.callLater(openPanel) }
    function showTab(name) { if (ux) ux.tabName = name; if (!opened && !windowRequested) open() }

    Connections {
        target: button.ux
        ignoreUnknownSignals: true
        function onPopOutRequested() { if (button.opened || button.windowRequested) button.popOut() }
        function onDockRequested() { if (button.opened || button.windowRequested) button.dock() }
        function onCloseRequested() { button.close() }
        function onTabRequested(name, toggle) {
            if (!ux.host) ux.host = button
            if (ux.host !== button) return
            const shown = button.opened || button.windowRequested
            if (toggle && shown && ux.tabName === name) button.close()
            else button.showTab(name)
        }
    }
    Connections {
        target: button.svc
        ignoreUnknownSignals: true
        function onPanelRequested(tab, toggle) {
            ux.host = button
            button.showTab(tab)
        }
    }

    ClipPanel.Panel {
        id: panel
        bar: button.bar
        anchorItem: button
        hostWidget: button
        svc: button.svc
    }

    Loader {
        id: winLoader
        active: button.windowRequested
        source: Qt.resolvedUrl("../../clipscape/qml/panel/PopoutWindow.qml")
        onLoaded: { item.svc = button.svc; item.visible = button.windowRequested }
    }

    Connections {
        target: winLoader.item
        ignoreUnknownSignals: true
        function onVisibleChanged() {
            if (winLoader.item && !winLoader.item.visible && button.windowRequested) button.windowRequested = false
        }
    }
}
