// Power/session action menu overlay.
// Shows a centered modal panel with session actions (lock, log out, reboot,
// shutdown), supports keyboard navigation/activation, and exposes IPC
// (target "power": toggle/open/close). Actions invoke system/session commands.

// Aequalyn power menu -- Lock, Log out, Reboot, Shutdown.
// Open with `qs ipc call power toggle`.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "root:/settings"
import "root:/style/backdrop"

Scope {
    id: root
    property var theme: AequalynDefaultTheme {}
    property string font: AequalynSettings.monoFont
    property bool panelVisible: false
    property int selectedIndex: 0

    readonly property var actions: [
        { label: "Lock screen", icon: "󰌾", cmd: ["aequalyn-lock", "lock"] },
        { label: "Log out",     icon: "󰍃", cmd: ["sh", "-c", "command -v aequalyn-logout >/dev/null && exec aequalyn-logout; loginctl terminate-session \"$XDG_SESSION_ID\" 2>/dev/null || hyprctl dispatch 'hl.dsp.exit()'"] },
        { label: "Reboot",      icon: "󰜉", cmd: ["systemctl", "reboot"] },
        { label: "Shutdown",    icon: "󰐥", cmd: ["systemctl", "poweroff"] }
    ]

    IpcHandler {
        target: "power"
        function toggle(): void {
            root.panelVisible = !root.panelVisible
            if (root.panelVisible) root.selectedIndex = 0
        }
        function open(): void { root.panelVisible = true; root.selectedIndex = 0 }
        function close(): void { root.panelVisible = false }
    }

    function run(index) {
        if (index < 0 || index >= actions.length) return
        const cmd = actions[index].cmd
        root.panelVisible = false
        actionProc.command = cmd
        actionProc.running = true
    }

    Process {
        id: actionProc
        running: false
    }

    PanelWindow {
        id: win
        visible: veil.shown
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: veil.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None   // none while it fades away
        WlrLayershell.namespace: veil.layerName("power_menu")
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }

        Item {
            anchors.fill: parent
            focus: win.visible
            Keys.onEscapePressed: root.panelVisible = false
            Keys.onUpPressed: root.selectedIndex = (root.selectedIndex - 1 + root.actions.length) % root.actions.length
            Keys.onDownPressed: root.selectedIndex = (root.selectedIndex + 1) % root.actions.length
            Keys.onReturnPressed: root.run(root.selectedIndex)
            Keys.onEnterPressed: root.run(root.selectedIndex)

            MouseArea {
                anchors.fill: parent
                onClicked: root.panelVisible = false
                Backdrop {
                    id: veil
                    open: root.panelVisible
                    theme: root.theme
                    tintAlpha: root.theme.bgOverlay.a
                }
            }

            Rectangle {
                anchors.centerIn: parent
                opacity: veil.progress
                scale: 0.97 + 0.03 * veil.progress
                width: 360
                height: col.implicitHeight + 32
                radius: 16
                color: root.theme.bgBase
                border.color: root.theme.bgBorder
                border.width: 1
                MouseArea { anchors.fill: parent; onClicked: {} }

                ColumnLayout {
                    id: col
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 8

                    Text {
                        text: "󰐥  Power"
                        color: root.theme.accentPrimary
                        font.pixelSize: 14
                        font.bold: true
                        font.family: root.font
                        Layout.fillWidth: true
                    }

                    Repeater {
                        model: root.actions
                        Rectangle {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            implicitHeight: 44
                            radius: 10
                            color: root.selectedIndex === index ? root.theme.bgSelected : root.theme.bgSurface
                            border.color: root.selectedIndex === index ? root.theme.accentPrimary : root.theme.bgBorder
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 100 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                spacing: 12
                                Text {
                                    text: modelData.icon
                                    color: root.selectedIndex === index ? root.theme.accentPrimary : root.theme.textPrimary
                                    font.pixelSize: 16
                                    font.family: root.font
                                }
                                Text {
                                    text: modelData.label
                                    color: root.theme.textPrimary
                                    font.pixelSize: 13
                                    font.family: root.font
                                    Layout.fillWidth: true
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: root.selectedIndex = index
                                onClicked: root.run(index)
                            }
                        }
                    }

                    Text {
                        text: "↑↓ navigate · ⏎ select · esc close"
                        color: root.theme.textMuted
                        font.pixelSize: 10
                        font.family: root.font
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }
}
