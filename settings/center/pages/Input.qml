// Keyboard and mouse: the keyboard layout and the touchpad, and the way to the
// shortcuts' own page (the keys Hyprland uses, changed by pressing your own).
import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/settings"
import ".."

CcPage {
    id: page
    title: "Keyboard and mouse"
    sub: "The keyboard layout and the touchpad. The keys themselves are on their own page."

    CcSection {
        title: "Keyboard layout"
        CcChoice {
            setting: "kbLayout"
            options: [
                { key: "us", label: "English (US)" }, { key: "gb", label: "English (UK)" },
                { key: "ro", label: "Romanian" }, { key: "de", label: "German" }, { key: "fr", label: "French" }
            ]
        }
    }
    CcToggle {
        setting: "naturalScroll"
        title: "Natural scrolling on the touchpad"
        sub: "The page moves the way your fingers do, like on a phone."
    }
    CcRow {
        title: "Keyboard shortcuts"
        sub: "Every key Hyprland uses, changed by pressing your own. Super + Alt + K."
        clickable: true
        action: "Open"
        primary: true
        onClicked: Cc.go("keybinds")
    }
}
