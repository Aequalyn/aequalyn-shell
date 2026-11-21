// EscalationWindow -- the one window a plugin's root request opens.
//
// The supervisor (aequalyn-watchdog) sends every request here after it
// pinned the caller to its real process and the command to the plugin's
// manifest; the window's only job is to let the person at the keyboard
// decide, with the full facts in front of them: which plugin, which
// action, the exact command that will run as root. The answer goes back
// with the password on a pipe (never argv, never a log line), and an
// unanswered window counts as a denial when the supervisor times out.
//
// Nothing here can be dismissed by accident: a click outside does nothing,
// Escape is an explicit denial, and Enter is an explicit Allow once.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "root:/settings"
import "root:/style/backdrop"

Scope {
    id: root

    // the shell's live theme (Watchdog.qml passes it; the default covers
    // the moment while it loads)
    property var theme: AequalynDefaultTheme {}
    property string font: "JetBrainsMono Nerd Font"

    // the request on show (or null): { requestId, plugin, label, version,
    // source, action, actionLabel, command, about, allowed }
    property var request: null
    // the final answer, straight to the supervisor
    signal decided(string requestId, string decision, string password)

    // a button, as everywhere in Aequalyn: quiet, a hairline edge, the
    // primary one in the accent's edge on a lifted fill
    component Btn: Rectangle {
        id: btn
        property string text: ""
        property bool primary: false
        signal clicked()
        implicitHeight: 34
        implicitWidth: btnRow.implicitWidth + 24
        radius: 8
        color: primary
               ? (btnArea.containsMouse ? root.theme.bgHover : root.theme.bgSelected)
               : btnArea.containsMouse ? root.theme.bgHover : root.theme.bgSurface
        border.width: 1
        border.color: primary ? root.theme.accentPrimary : root.theme.bgBorder
        Row {
            id: btnRow
            anchors.centerIn: parent
            spacing: 6
            Text {
                text: btn.text
                color: primary ? root.theme.accentPrimary : root.theme.textPrimary
                font.pixelSize: 12
                font.bold: primary
                font.family: root.font
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        MouseArea {
            id: btnArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }

    // how long the window waits before it answers for itself: the same
    // clock the supervisor runs, so what the window says is what happens
    property int timeoutSeconds: 120
    property int secondsLeft: 0

    function showRequest(req) {
        root.request = req || null
        if (root.request) {
            root.secondsLeft = root.timeoutSeconds
            countdown.restart()
            pwInput.text = ""
            pwInput.forceActiveFocus()
        } else {
            countdown.stop()
        }
    }

    function answer(decision) {
        if (!root.request) return
        const rid = root.request.requestId
        const pwd = decision === "deny" ? "" : pwInput.text
        root.request = null          // answered: the window is gone for good
        countdown.stop()
        root.decided(rid, decision, pwd)
    }

    PanelWindow {
        id: win
        visible: veil.shown
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        // the password field needs the keyboard, and nothing else may have it
        WlrLayershell.keyboardFocus: root.request ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace: "quickshell-escalation"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }

        Item {
            anchors.fill: parent
            focus: win.visible
            // a root request is not dismissed by a stray click outside
            Keys.onEscapePressed: root.answer("deny")

            MouseArea {
                anchors.fill: parent
                onClicked: {}          // swallow it: the buttons decide

                Backdrop {
                    id: veil
                    open: root.request !== null
                    theme: root.theme
                    tintAlpha: root.theme.bgOverlay.a
                }
            }

            Rectangle {
                visible: veil.progress > 0
                anchors.centerIn: parent
                opacity: veil.progress
                scale: 0.97 + 0.03 * veil.progress
                width: 480
                height: col.implicitHeight + 32
                radius: 16
                color: root.theme.bgBase
                border.color: root.theme.bgBorder
                border.width: 1
                MouseArea { anchors.fill: parent; onClicked: {} }

                ColumnLayout {
                    id: col
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 9

                    Text {
                        text: "󰌾  " + (root.request && root.request.allowed
                                       ? "Plugin runs as root" : "Plugin asks for root")
                        color: root.theme.accentPrimary
                        font.pixelSize: 14
                        font.bold: true
                        font.family: root.font
                        Layout.fillWidth: true
                    }

                    Text {
                        visible: root.request !== null
                        text: root.request
                              ? root.request.label + "  ·  " + root.request.plugin
                                + (root.request.version ? "  ·  v" + root.request.version : "")
                                + (root.request.source === "store" ? "  ·  from the Store" : "  ·  built-in")
                              : ""
                        color: root.theme.textSecondary
                        font.pixelSize: 12
                        font.family: root.font
                        Layout.fillWidth: true
                    }

                    Text {
                        visible: root.request !== null && root.request.about !== ""
                        Layout.fillWidth: true
                        text: root.request ? root.request.about : ""
                        color: root.theme.textMuted
                        font.pixelSize: 11
                        font.family: root.font
                        wrapMode: Text.WordWrap
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.topMargin: 3
                        implicitHeight: cmdText.implicitHeight + 20
                        radius: 10
                        color: root.theme.bgSurface
                        border.width: 1
                        border.color: root.theme.bgBorder
                        Text {
                            id: cmdText
                            anchors.fill: parent
                            anchors.margins: 10
                            text: root.request ? root.request.command : ""
                            color: root.theme.textPrimary
                            font.pixelSize: 12
                            font.family: root.font
                            wrapMode: Text.WrapAnywhere
                        }
                    }

                    Text {
                        visible: root.request !== null && root.request.actionLabel !== ""
                        Layout.fillWidth: true
                        text: root.request ? "for: " + root.request.actionLabel : ""
                        color: root.theme.textMuted
                        font.pixelSize: 11
                        font.family: root.font
                    }

                    Text {
                        visible: root.request !== null && root.request.allowed
                        Layout.fillWidth: true
                        text: "You allowed this action before. Only the password is asked for again."
                        color: root.theme.textMuted
                        font.pixelSize: 11
                        font.family: root.font
                    }

                    // the password: straight to sudo through the supervisor
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        implicitHeight: 40
                        radius: 10
                        color: root.theme.bgSurface
                        border.width: 1
                        border.color: pwInput.activeFocus ? root.theme.accentPrimary : root.theme.bgBorder
                        Behavior on border.color { ColorAnimation { duration: 120 } }
                        MouseArea { anchors.fill: parent; onClicked: pwInput.forceActiveFocus() }
                        TextInput {
                            id: pwInput
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            verticalAlignment: TextInput.AlignVCenter
                            color: root.theme.textPrimary
                            selectionColor: root.theme.accentPrimary
                            selectedTextColor: root.theme.bgBase
                            font.pixelSize: 13
                            font.family: root.font
                            clip: true
                            echoMode: TextInput.Password
                            passwordCharacter: "•"
                            onAccepted: root.answer("once")
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        spacing: 8

                        Text {
                            Layout.fillWidth: true
                            text: root.request
                                  ? "Denied automatically in " + root.secondsLeft + " s"
                                  : ""
                            color: root.theme.textMuted
                            font.pixelSize: 11
                            font.family: root.font
                        }

                        Btn { text: "Deny"; onClicked: root.answer("deny") }
                        Btn {
                            text: "Always allow this"
                            visible: root.request !== null && !root.request.allowed
                            onClicked: root.answer("always")
                        }
                        Btn { text: "Allow once"; primary: true; onClicked: root.answer("once") }
                    }
                }
            }
        }
    }

    // the supervisor denies on its own timeout; this countdown only says
    // so, and typing keeps the person's window open as long as they need
    Timer {
        id: countdown
        interval: 1000
        repeat: true
        running: root.request !== null
        onTriggered: {
            root.secondsLeft--
            if (root.secondsLeft <= 0) root.answer("deny")
        }
    }
}
