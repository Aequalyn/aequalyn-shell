// Wallpaper: the picture behind everything, and how it changes over time (Atelier's
// rotation pane).
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
    sub: "The picture behind everything. Your colours can follow it."
    tabs: ["Pick one", "Change it over time"]
    fills: [1]
    readonly property string folder: AequalynSettings.wallpaperCfg.folder || (Quickshell.env("HOME") + "/Pictures/Wallpapers")

    actions: [
        CcButton {
            text: "Browse wallpapers"; icon: "\u{F0E09}"; primary: true
            onClicked: Cc.ipc(["atelier", "open", "wallpapers"], true)
        }
    ]

    Stage {
        visible: page.tab === 0
        Layout.fillWidth: true
        Layout.maximumWidth: 640
        Layout.preferredHeight: width * 9 / 16
        theme: Cc.theme
        font: Cc.mono
        wallpaper: Cc.wallpaper
        barLook: BarLooks.clean(AequalynSettings.barStyleCfg)
        barSize: 22
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
        title: "Colours follow the wallpaper"
        sub: "Choose in Theme and colours whether they come from the wallpaper or a theme."
        action: "Theme and colours"
        onActivated: Cc.go("theme")
    }

    RotationPane {
        visible: page.tab === 1
        Layout.fillWidth: true
        Layout.fillHeight: true
        theme: Cc.theme
        font: Cc.mono
    }
}
