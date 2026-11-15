// Wallpaper: the picture behind everything, and how it changes over time (Atelier's
// rotation pane). A wallpaper changes only the picture: the theme's colours stay.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/settings"
import "../../../plugins/atelier"
import "../../../style/BarLooks.js" as BarLooks
import ".."

CcPage {
    id: page
    title: "Wallpaper"
    sub: Cc.theme.wallpaperMode ? "The picture behind everything. Your colours are made from it."
                                : "The picture behind everything. Changing it keeps your theme's colours."
    tabs: ["Pick one", "Change it over time"]
    readonly property string folder: AequalynSettings.wallpaperCfg.folder || (Quickshell.env("HOME") + "/Pictures/Wallpapers")

    actions: [
        CcButton {
            text: "Browse wallpapers"; icon: "\u{F0E09}"; primary: true
            onClicked: Cc.ipc(["atelier", "open", "wallpapers"], true)
        }
    ]

    stageHeight: 210
    stage: Stage {
        anchors.fill: parent
        theme: Cc.theme
        font: Cc.mono
        wallpaper: Cc.wallpaper
        barLook: BarLooks.clean(AequalynSettings.barStyleCfg)
        barSize: Math.round(AequalynSettings.barHeight * 0.75)
    }
    CcSection {
        visible: page.tab === 0
        title: Cc.wallpaper !== "" ? Cc.wallpaper.split("/").pop() : "Right now"
        hint: "Super + W opens the wallpaper picker over your desktop, from anywhere."
        Flow {
            Layout.fillWidth: true
            spacing: 8
            CcButton { text: "Previous"; icon: "\u{F0141}"; onClicked: Cc.run(["aequalyn-wallpaper", "prev"]) }
            CcButton { text: "Next"; icon: "\u{F0142}"; onClicked: Cc.run(["aequalyn-wallpaper", "next"]) }
            CcButton { text: "Surprise me"; icon: "\u{F049D}"; onClicked: Cc.run(["aequalyn-wallpaper", "random"]) }
            CcButton { text: "Open the folder"; icon: "\u{F024B}"; onClicked: Cc.run(["xdg-open", page.folder]) }
        }
    }
    CcRow {
        visible: page.tab === 0
        icon: "\u{F03D8}"
        title: Cc.theme.wallpaperMode ? "Colours follow the wallpaper" : "Your theme's wallpapers and your own"
        sub: Cc.theme.wallpaperMode ? "Every wallpaper repaints the desktop. Set on the Theme page."
                                    : "Super + W shows the theme's wallpapers first, then the ones in your wallpaper folder. Other themes bring their own."
        action: "Theme page"
        onActivated: Cc.go("theme")
    }

    RotationPane {
        visible: page.tab === 1
        interactive: false
        Layout.fillWidth: true
        Layout.preferredHeight: contentHeight
        theme: Cc.theme
        font: Cc.mono
    }
}
