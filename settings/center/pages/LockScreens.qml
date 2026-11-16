// Lock Screens: the SDDM login screen theme, autologin and a live preview.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "root:/settings"
import ".."

CcPage {
    id: page
    title: "Lock screens"
    sub: "The login screen shown by SDDM: pick a theme, turn autologin on (boots straight into Hyprland, no greeter) or preview one for a few seconds."

    property var themes: []
    property string currentTheme: ""
    property string selectedTheme: ""
    property bool autologin: false
    property bool applying: false
    property bool previewing: false
    property string status: ""

    function refresh() {
        listProc.running = true
        currentProc.running = true
        autoProc.running = true
    }

    // ---- installed SDDM themes --------------------------------------------
    property Process listProc: Process {
        running: false
        command: ["aequalyn-sddm", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n").filter(l => l.trim() !== "")
                page.themes = lines
                if (page.selectedTheme === "" && lines.length > 0)
                    page.selectedTheme = page.currentTheme !== "" ? page.currentTheme : lines[0]
            }
        }
    }

    property Process currentProc: Process {
        running: false
        command: ["aequalyn-sddm", "current"]
        stdout: StdioCollector {
            onStreamFinished: { page.currentTheme = text.trim() }
        }
    }

    property Process autoProc: Process {
        running: false
        command: ["aequalyn-sddm", "autologin", "status"]
        stdout: StdioCollector {
            onStreamFinished: { page.autologin = (text.trim() === "on") }
        }
    }

    property Process applyProc: Process {
        running: false
        stdout: StdioCollector { id: applyOut }
        stderr: StdioCollector { id: applyErr }
        onExited: (code, st) => {
            page.applying = false
            if (code === 0) {
                page.currentTheme = page._pendingApply
                page.status = "Applied " + page._pendingApply + "."
                page.currentProc.running = true
            } else {
                page.status = "Apply failed: " + (applyErr.text || applyOut.text).trim().slice(0, 200)
            }
        }
    }
    property string _pendingApply: ""

    function applyTheme(name) {
        page._pendingApply = name
        page.applying = true
        page.status = "Applying " + name + "…"
        // Hide Settings, then let sudo prompt for the password with zenity: some
        // GPU/VM setups crash hyprpolkitagent, which makes pkexec unusable.
        applyProc.command = ["setsid", "sh", "-c", privilegedSession("apply " + shellQuote(name))]
        applyProc.running = true
    }

    property Process autoToggleProc: Process {
        running: false
        stdout: StdioCollector { id: autoOut }
        stderr: StdioCollector { id: autoErr }
        onExited: (code, st) => {
            if (code === 0) {
                page.autologin = !page.autologin
                page.status = page.autologin ? "Autologin enabled." : "Autologin disabled."
            } else {
                page.status = "Autologin change failed: " + (autoErr.text || autoOut.text).trim().slice(0, 200)
            }
        }
    }

    function toggleAutologin(on) {
        page.status = on ? "Enabling autologin…" : "Disabling autologin…"
        autoToggleProc.command = ["setsid", "sh", "-c", privilegedSession("autologin " + (on ? "on" : "off"))]
        autoToggleProc.running = true
    }

    property Process previewProc: Process {
        running: false
        onExited: (code, st) => { page.previewing = false }
    }

    function shellQuote(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }

    // Run the privileged SDDM helper without pkexec: sudo's own askpass prompt
    // (zenity) is reliable even where the polkit agent is not.
    function privilegedCommand(subcommand) {
        const home = Quickshell.env("HOME")
        return "DISPLAY=" + shellQuote(Quickshell.env("DISPLAY") || "")
             + " WAYLAND_DISPLAY=" + shellQuote(Quickshell.env("WAYLAND_DISPLAY") || "")
             + " XDG_RUNTIME_DIR=" + shellQuote(Quickshell.env("XDG_RUNTIME_DIR") || "")
             + " SUDO_ASKPASS=" + shellQuote(home + "/.local/bin/aequalyn-askpass")
             + " sudo -A " + shellQuote(home + "/.local/bin/aequalyn-sddm") + " " + subcommand
    }
    function privilegedSession(subcommand) {
        return "qs ipc call aequalyn closeSettings; sleep 0.3; " + privilegedCommand(subcommand)
             + "; rc=$?; qs ipc call aequalyn openSettings; exit $rc"
    }

    function previewTheme(name) {
        page.previewing = true
        page.status = "Previewing " + name + " for 10 seconds…"
        // Detach so the preview survives the Settings panel closing.
        previewProc.command = ["sh", "-c", "DISPLAY=" + shellQuote(Quickshell.env("DISPLAY") || "") + " WAYLAND_DISPLAY=" + shellQuote(Quickshell.env("WAYLAND_DISPLAY") || "") + " XDG_RUNTIME_DIR=" + shellQuote(Quickshell.env("XDG_RUNTIME_DIR") || "") + " setsid aequalyn-sddm preview " + shellQuote(name) + " 10 >/dev/null 2>&1 &"]
        previewProc.running = true
    }

    Component.onCompleted: page.refresh()

    stageHeight: 120
    stage: Rectangle {
        anchors.fill: parent
        radius: 14
        color: Cc.theme.bgSurface
        Text {
            anchors.centerIn: parent
            text: page.currentTheme ? ("Current: " + page.currentTheme) : "No theme set"
            color: Cc.theme.textPrimary
            font.family: Cc.sans
            font.pixelSize: 14
        }
    }

    // ---- installed themes --------------------------------------------------
    CcSection {
        title: "Installed SDDM themes"
        hint: "Click a theme to preview it live for 10 seconds. Hit Apply to make it the login screen."
        GridLayout {
            Layout.fillWidth: true
            columns: Math.max(2, Math.floor(width / 200))
            columnSpacing: 10
            rowSpacing: 10
            Repeater {
                model: page.themes
                delegate: Rectangle {
                    id: tile
                    required property string modelData
                    readonly property bool on: page.currentTheme === modelData
                    readonly property bool sel: page.selectedTheme === modelData
                    property int shotIdx: 0
                    readonly property var shotCandidates: [
                        "file:///usr/share/sddm/themes/" + modelData + "/screenshot.png",
                        "file:///usr/share/sddm/themes/" + modelData + "/bg.png",
                        "file:///usr/share/sddm/themes/" + modelData + "/screenshot.jpg",
                        "file:///usr/share/sddm/themes/" + modelData + "/" + modelData + ".jpg",
                        "file:///usr/share/sddm/themes/" + modelData + "/" + modelData + ".png",
                        "file:///usr/share/sddm/themes/" + modelData + "/abstractdark-sddm-theme.png",
                        "file:///usr/share/sddm/themes/" + modelData + "/preview.png",
                        "file:///usr/share/sddm/themes/" + modelData + "/assets/screenshots/Screenshot_1.png",
                        "file:///usr/share/sddm/themes/" + modelData + "/screenshots/hi_IN.png"
                    ]
                    Layout.fillWidth: true
                    implicitHeight: 180
                    radius: 14
                    color: sel ? Cc.alpha(Cc.theme.accentPrimary, 0.18)
                           : (on ? Cc.alpha(Cc.theme.accentPrimary, 0.10) : (tileArea.containsMouse ? Cc.theme.bgHover : Cc.theme.bgSurface))
                    border.width: sel ? 3 : (on ? 2 : 1)
                    border.color: sel ? Cc.theme.accentPrimary : (on ? Cc.theme.accentPrimary : Cc.theme.textMuted)

                    Image {
                        id: shotImg
                        x: 6; y: 6
                        width: parent.width - 12
                        height: 90
                        source: tile.shotCandidates[tile.shotIdx]
                        sourceSize: Qt.size(320, 180)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        clip: true
                        visible: status === Image.Ready
                        onStatusChanged: {
                            if (status === Image.Error && tile.shotIdx < tile.shotCandidates.length - 1)
                                tile.shotIdx++
                        }
                    }
                    Rectangle {
                        anchors.fill: shotImg
                        color: Cc.theme.bgSurface
                        visible: shotImg.status !== Image.Ready
                        Text {
                            anchors.centerIn: parent
                            text: tile.modelData
                            color: Cc.theme.textMuted
                            font.family: Cc.mono
                            font.pixelSize: 11
                        }
                    }
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.bottom: applyBtn.top
                        anchors.bottomMargin: 6
                        text: tile.modelData + (tile.on ? "  (current)" : "")
                        elide: Text.ElideRight
                        color: Cc.theme.textPrimary
                        font.family: Cc.sans
                        font.pixelSize: 12
                        font.weight: tile.on ? Font.DemiBold : Font.Normal
                    }

                    CcButton {
                        id: applyBtn
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 6
                        height: 26
                        text: tile.on ? "Applied" : "Apply"
                        primary: tile.sel && !tile.on
                        enabled: !tile.on && !page.applying && !page.previewing
                        onClicked: {
                            page.selectedTheme = tile.modelData
                            page.applyTheme(tile.modelData)
                        }
                    }

                    MouseArea {
                        id: tileArea
                        anchors.fill: parent
                        anchors.bottomMargin: 36
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            page.selectedTheme = tile.modelData
                            page.previewTheme(tile.modelData)
                        }
                    }
                }
            }
        }
        CcNote {
            visible: page.themes.length === 0
            text: "No SDDM themes found. Install some into /usr/share/sddm/themes first."
        }
    }

    // ---- apply / preview ---------------------------------------------------
    CcSection {
        title: "Apply"
        hint: page.selectedTheme !== "" ? ("Selected: " + page.selectedTheme) : "Pick a theme above to preview and apply it."
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            CcButton {
                text: page.applying ? "Applying…" : "Apply selected"
                icon: "\u{F0193}"
                primary: true
                enabled: page.selectedTheme !== "" && !page.applying && !page.previewing
                onClicked: page.applyTheme(page.selectedTheme)
            }
            CcButton {
                text: page.previewing ? "Previewing…" : "Preview selected (10s)"
                icon: "\u{F03D8}"
                enabled: page.selectedTheme !== "" && !page.previewing && !page.applying
                onClicked: page.previewTheme(page.selectedTheme)
            }
            CcButton {
                text: "Refresh list"
                icon: "\u{F0450}"
                onClicked: page.refresh()
            }
        }
        CcNote {
            visible: page.status !== ""
            text: page.status
        }
    }

    // ---- autologin --------------------------------------------------------
    CcToggle {
        title: "SDDM autologin"
        sub: "When on, SDDM is skipped and you boot straight into Hyprland. The login theme is not shown."
        checked: page.autologin
        onToggled: v => page.toggleAutologin(v)
    }
}
