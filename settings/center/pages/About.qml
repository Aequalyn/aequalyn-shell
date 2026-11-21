// About: what this is, which version, and where its settings live.
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "root:/settings"
import ".."

CcPage {
    id: page
    title: "About"
    readonly property var u: Cc.updates

    function shellQuote(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }
    // Install the optional theme pack through the root gate: the approval
    // window opens (the control center's own declared action), and the
    // password goes to sudo on a pipe. No sudo, no askpass, no polkit.
    function installCommand() {
        return "aequalyn-sddm install"
    }

    // The wordmark sits on its own above the details, centred on the page.
    ColumnLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: 12
        Image {
            Layout.alignment: Qt.AlignHCenter
            source: "root:/assets/aequalyn-wordmark.svg"
            sourceSize.width: 280; sourceSize.height: 69
            Layout.preferredWidth: 280; Layout.preferredHeight: 69
            fillMode: Image.PreserveAspectFit
            smooth: true
            layer.enabled: true
            layer.effect: MultiEffect {
                colorization: 1.0
                colorizationColor: Cc.theme.accentPrimary
            }
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "0.1 preview  ·  Arch Linux, Hyprland and Quickshell"
            color: Cc.theme.textMuted
            font.family: Cc.sans
            font.pixelSize: 13
        }
    }
    CcSection {
        CcRow {
            icon: "\u{F06B0}"
            title: "Version"
            sub: page.u ? "System " + (page.u.systemCommit || "…") + "  ·  shell " + (page.u.shellCommit || "…") : ""
            action: "Updates"
            onActivated: Cc.go("updates")
        }
        CcRow {
            icon: "\u{F03D8}"
            title: "Colours"
            sub: "Made from your wallpaper by matugen, or taken from a theme."
        }
        CcRow {
            icon: "\u{F024B}"
            title: "Your settings"
            sub: "~/.config/aequalyn/settings.json"
            action: "Open the folder"
            onActivated: Cc.run(["xdg-open", Quickshell.env("HOME") + "/.config/aequalyn"])
        }
    }

    // Optional SDDM lock-screen theme pack.
    readonly property bool lockscreensInstalled: AequalynSettings.lockscreensInstalled
    property Process lsInstall: Process {
        running: false
        onExited: (code, st) => {
            if (code === 0) {
                page.status = "Login screens installed. Choose one in Look › Login screen."
                AequalynSettings.lockscreensMarker.reload()
            } else {
                page.status = "Install failed (exit " + code + ")."
            }
        }
    }
    property string status: ""

    CcSection {
        title: "Login screens"
        hint: page.lockscreensInstalled ? "SDDM theme pack installed." : "Optional SDDM login themes (~400 MB download)."
        CcButton {
            visible: !page.lockscreensInstalled
            text: "Install login screens"
            icon: "\u{F0193}"
            primary: true
            onClicked: {
                page.status = "Installing…"
                page.lsInstall.command = ["setsid", "sh", "-c", page.installCommand()]
                page.lsInstall.running = true
            }
        }
        CcNote {
            visible: page.status !== ""
            text: page.status
        }
    }
}
