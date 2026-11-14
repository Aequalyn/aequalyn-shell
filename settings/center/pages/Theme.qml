// Theme and colours: a ready-made look or colours made from the wallpaper, and how
// they are made (Atelier's palette pane).
import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/settings"
import "../../../plugins/atelier"
import ".."

CcPage {
    id: page
    title: "Theme and colours"
    sub: "A ready-made look, or colours made from your wallpaper."
    tabs: ["Theme", "How colours are made"]
    fills: [1]

    actions: [
        CcButton {
            text: "Browse themes"; icon: "\u{F03D8}"; primary: true
            onClicked: Cc.ipc(["atelier", "open", "themes"], true)
        }
    ]

    // the colours in use right now
    Rectangle {
        visible: page.tab === 0
        Layout.fillWidth: true
        implicitHeight: 128
        radius: 16
        color: Cc.theme.bgSurface
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: Cc.theme.wallpaperMode ? "Made from your wallpaper" : (Cc.theme.currentName || "Your theme")
                    color: Cc.theme.textPrimary
                    font.family: Cc.sans
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                }
                Text {
                    text: "in use"
                    color: Cc.theme.accentGreen
                    font.family: Cc.mono
                    font.pixelSize: 11
                }
            }
            Row {
                spacing: 6
                Repeater {
                    model: [Cc.theme.bgBase, Cc.theme.bgSurface, Cc.theme.bgSelected, Cc.theme.textPrimary,
                            Cc.theme.textSecondary, Cc.theme.accentPrimary, Cc.theme.accentCyan,
                            Cc.theme.accentGreen, Cc.theme.accentOrange, Cc.theme.accentRed]
                    delegate: Rectangle {
                        required property var modelData
                        width: 38; height: 48; radius: 10
                        color: modelData
                        border.color: Cc.theme.bgBorder
                        border.width: 1
                    }
                }
            }
        }
    }
    CcSection {
        visible: page.tab === 0
        hint: "Super + T opens the theme picker over your desktop, from anywhere."
        Flow {
            Layout.fillWidth: true
            spacing: 8
            CcButton { text: "Regenerate colours"; icon: "\u{F0450}"; onClicked: AequalynSettings.retheme() }
            CcButton { text: "Wallpaper"; icon: "\u{F0E09}"; onClicked: Cc.go("wallpaper") }
        }
    }
    CcToggle {
        visible: page.tab === 0
        setting: "themeApps"
        title: "Apps use these colours too"
        sub: "Files, settings windows and other GTK apps match your desktop. Off leaves them as they come."
    }

    PalettePane {
        visible: page.tab === 1
        Layout.fillWidth: true
        Layout.fillHeight: true
        theme: Cc.theme
        font: Cc.mono
    }
}
