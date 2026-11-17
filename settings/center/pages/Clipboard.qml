// Clipboard: the Clipscape history, its keybind, and a way to clear it.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "root:/settings"
import ".."

CcPage {
    id: page
    title: "Clipboard"
    sub: "Everything you copy is kept by Clipscape. Search it with Super + Ctrl + V, or clear it here."

    property int clipCount: -1
    property bool armed: false

    function refresh() {
        statusProc.command = ["sh", "-c", "qs ipc call clipscape status 2>/dev/null || true"]
        statusProc.running = true
    }
    Component.onCompleted: refresh()

    Process {
        id: statusProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(String(text || "{}"))
                    page.clipCount = Number(d.clips) || 0
                } catch (e) { page.clipCount = -1 }
            }
        }
    }

    CcSection {
        title: "History"
        hint: page.clipCount >= 0 ? page.clipCount + (page.clipCount === 1 ? " clip saved." : " clips saved.") : ""

        CcRow {
            icon: "\u{F0E09}"
            title: "Clear clipboard cache"
            sub: page.armed ? "Click again to delete the whole history." : "Deletes every saved clip. Pinned clips go too."
            action: page.armed ? "Confirm" : "Clear history"
            danger2: true
            onActivated: {
                if (!page.armed) {
                    page.armed = true
                    armTimer.restart()
                    return
                }
                page.armed = false
                armTimer.stop()
                Cc.ipc(["clipscape", "clearAll"], false)
                clearTimer.restart()
            }
        }
        CcNote {
            text: "This empties the Clipscape history stored in ~/.local/state/aequalyn-clipscape. It does not change the current clipboard contents."
        }
        Timer { id: armTimer; interval: 4000; onTriggered: page.armed = false }
        Timer { id: clearTimer; interval: 700; onTriggered: page.refresh() }
    }

    CcSection {
        title: "Shortcut"
        hint: "The key that opens the clipboard history."

        RowLayout {
            Layout.fillWidth: true
            spacing: 14
            Row {
                Layout.preferredWidth: 220
                spacing: 4
                Repeater {
                    model: ["Super", "Ctrl", "V"]
                    delegate: Rectangle {
                        required property string modelData
                        width: keyText.implicitWidth + 16
                        height: 26
                        radius: 7
                        color: Cc.theme.bgSurface
                        border.color: Cc.theme.bgBorder
                        border.width: 1
                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 2; radius: 1; color: Cc.theme.bgBorder }
                        Text {
                            id: keyText
                            anchors.centerIn: parent
                            text: modelData
                            color: Cc.theme.textPrimary
                            font.family: Cc.mono
                            font.pixelSize: 11
                        }
                    }
                }
            }
            Text {
                text: "Open the clipboard history"
                color: Cc.theme.textSecondary
                font.family: Cc.sans
                font.pixelSize: 12
            }
        }
    }
}
