import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import ".."
import "picker"
import "controls"
import "root:/style/backdrop"

// Clipscape's picker on Super+Ctrl+V, opened through the service singleton. Drawn like
// the Applications menu: over the shell's backdrop, on its frame, with its key chips.
// The payload may hold { "query": "...", "filter": "..." }.
Item {
    id: root

    readonly property var svc: ClipscapeService
    readonly property var ui: svc.ui
    readonly property var cfg: svc.cfg
    property var theme: null            // the shell's palette, for the frame and the backdrop

    property bool opened: false
    property var targetScreen: null
    // 0 = shown, 1 = gone
    property real t: 1
    readonly property bool shown: opened || t < 1

    Connections {
        target: ClipscapeService
        ignoreUnknownSignals: true
        function onPickerRequested(payload) { root.open(payload) }
        function onPickerToggleRequested() { root.toggle() }
    }

    function open(payload) {
        let p = {}
        try { p = JSON.parse(String(payload || "{}")) } catch (e) { p = {} }
        if (root.opened) {
            view.forceActiveFocus()
            return
        }
        // the bar panel gives up the keyboard first
        root.ui.closeRequested()
        root.targetScreen = pickScreen()
        root.opened = true
        if (p && typeof p.query === "string") view.setQuery(p.query)
        if (p && typeof p.filter === "string" && ["all", "pinned", "text", "link", "image", "files", "color", "code"].indexOf(p.filter) >= 0)
            view.setFilter(p.filter)
        if (root.cfg.openAt === "mouse") cursorProc.running = true
        else place(-1, -1)
        anim.from = root.t
        anim.to = 0
        anim.restart()
        Qt.callLater(() => view.forceActiveFocus())
    }

    function close() {
        if (!root.opened) return
        root.opened = false
        anim.from = root.t
        anim.to = 1
        anim.restart()
    }
    function toggle() { if (root.opened) dismiss(); else open("") }

    function dismiss() { root.close() }

    function pickScreen() {
        let name = ""
        try { name = Hyprland.focusedMonitor ? String(Hyprland.focusedMonitor.name) : "" } catch (e) { name = "" }
        let list = []
        try { list = Quickshell.screens } catch (e2) { list = [] }
        for (let i = 0; i < list.length; i++) if (list[i] && list[i].name === name) return list[i]
        return null
    }

    // where the card goes: the middle, or centered on the mouse and kept on screen
    property real cardX: 0
    property real cardY: 0
    function place(mx, my) {
        const w = card.width, h = card.height
        if (mx < 0) {
            cardX = Math.round((win.width - w) / 2)
            cardY = Math.round((win.height - h) / 2)
        } else {
            cardX = Math.round(Math.max(16, Math.min(win.width - w - 16, mx - w / 2)))
            cardY = Math.round(Math.max(16, Math.min(win.height - h - 16, my - h / 3)))
        }
    }
    Process {
        id: cursorProc
        command: ["hyprctl", "-j", "cursorpos"]
        stdout: StdioCollector {
            onStreamFinished: {
                let c = null
                try { c = JSON.parse(String(text || "")) } catch (e) { c = null }
                const sx = win.screen && win.screen.x !== undefined ? win.screen.x : 0
                const sy = win.screen && win.screen.y !== undefined ? win.screen.y : 0
                if (c && typeof c.x === "number" && typeof c.y === "number") root.place(c.x - sx, c.y - sy)
                else root.place(-1, -1)
            }
        }
    }

    NumberAnimation {
        id: anim
        target: root
        property: "t"
        duration: 120
        easing.type: Easing.OutCubic
    }

    // no input while it fades away, so the fade never eats a click
    Region { id: noInput }

    PanelWindow {
        id: win

        visible: root.shown || veil.shown
        screen: root.targetScreen
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: veil.layerName("clipscape")
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        mask: root.opened ? null : noInput

        // the desktop behind, blurred and dimmed as every Aequalyn panel has it
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onClicked: root.dismiss()
            Backdrop {
                id: veil
                open: root.opened
                theme: root.theme
                tintAlpha: root.theme ? root.theme.bgOverlay.a : (root.cfg ? root.cfg.dim / 100 : 0.3)
            }
        }

        Item {
            id: card
            visible: root.ui !== null
            x: root.cardX
            y: root.cardY + Math.round(root.t * 12)
            width: Math.min(win.width - 32, root.cfg ? root.cfg.pickerWidth : 860)
            height: Math.min(win.height - 32, root.cfg ? root.cfg.pickerHeight : 560)
            opacity: 1 - root.t
            scale: 1 - root.t * 0.03
            onWidthChanged: if (root.opened && root.cfg.openAt !== "mouse") root.place(-1, -1)
            onHeightChanged: if (root.opened && root.cfg.openAt !== "mouse") root.place(-1, -1)

            MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }   // clicks on the card stay here

            // the Applications menu's frame
            Rectangle {
                anchors.fill: parent
                radius: 16
                color: root.theme ? root.theme.bgBase : root.ui.surface
                border.width: 1
                border.color: root.theme ? root.theme.bgBorder : root.ui.tint(0.14)
            }

            ClipView {
                id: view
                anchors.fill: parent
                anchors.margins: 16
                anchors.bottomMargin: 42
                svc: root.svc
                active: root.opened
                onDone: root.dismiss()
            }

            // the keys, as the Applications menu shows them: each in its own chip
            Row {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.bottomMargin: 14
                height: 18
                spacing: 16
                clip: true
                Repeater {
                    model: view.hints.split(" · ").map(h => {
                        const k = h.indexOf(" ");
                        return k > 0 ? [h.slice(0, k), h.slice(k + 1)] : [h, ""];
                    })
                    delegate: Row {
                        required property var modelData
                        spacing: 4
                        Rectangle {
                            width: keyText.implicitWidth + 8
                            height: 18
                            radius: 4
                            color: root.theme ? root.theme.bgSurface : root.ui.tint(0.06)
                            Txt {
                                id: keyText
                                ui: root.ui
                                anchors.centerIn: parent
                                text: ({ "Enter": "⏎", "Esc": "esc", "Tab": "tab", "Del": "del" })[modelData[0]] || modelData[0]
                                color: root.theme ? root.theme.textMuted : root.ui.tint(0.5)
                                font.pixelSize: 10
                            }
                        }
                        Txt {
                            ui: root.ui
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData[1]
                            color: root.theme ? root.theme.textMuted : root.ui.tint(0.5)
                            font.pixelSize: 10
                        }
                    }
                }
            }
        }
    }
}
