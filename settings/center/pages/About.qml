// About: what this is, which version, and where its settings live.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/settings"
import ".."

CcPage {
    id: page
    title: "About"
    readonly property var u: Cc.updates

    RowLayout {
        spacing: 18
        Rectangle {
            Layout.preferredWidth: 72
            Layout.preferredHeight: 72
            radius: 20
            color: Cc.theme.accentPrimary
            Text {
                anchors.centerIn: parent
                text: "æ"
                color: Cc.theme.bgBase
                font.family: Cc.sans
                font.pixelSize: 36
                font.bold: true
            }
        }
        ColumnLayout {
            spacing: 2
            Text { text: "Aequalyn"; color: Cc.theme.textPrimary; font.family: Cc.sans; font.pixelSize: 22; font.weight: Font.DemiBold }
            Text { text: "0.1 preview  ·  Arch Linux, Hyprland and Quickshell"; color: Cc.theme.textMuted; font.family: Cc.sans; font.pixelSize: 13 }
        }
    }
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
