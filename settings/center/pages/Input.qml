// Keyboard and mouse: the keyboard layout, the touchpad, and the shortcuts.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/settings"
import ".."

CcPage {
    id: page
    title: "Keyboard and mouse"
    sub: "Typing, scrolling and the shortcuts you use every day."

    readonly property var everyday: [
        { k: "Super  Space", v: "Find an app" },
        { k: "Super  Enter", v: "Terminal" },
        { k: "Super  E", v: "Files" },
        { k: "Super  T", v: "Pick a theme" },
        { k: "Super  W", v: "Pick a wallpaper" },
        { k: "Super  ,", v: "This control center" },
        { k: "Super  C / V", v: "Copy and paste, in any app" },
        { k: "Super  Q", v: "Close a window" },
        { k: "Super  1 … 0", v: "Go to a workspace" },
        { k: "Super  L", v: "Next window arrangement" }
    ]
    readonly property var more: [
        { k: "Super  D", v: "Aequalyn app launcher" },
        { k: "Super  Ctrl  V", v: "Clipboard history, text and images" },
        { k: "Super  X / A", v: "Cut / select all, in any app" },
        { k: "Super  O", v: "Screen map" },
        { k: "Super  Shift  O", v: "Refresh the screen layout" },
        { k: "Super  Shift  C", v: "Keep awake" },
        { k: "Super  Shift  V", v: "Float a window" },
        { k: "Super  F", v: "Full screen" },
        { k: "Super  P", v: "Pseudo-tile" },
        { k: "Super  J", v: "Turn the split" },
        { k: "Super  Shift  1 … 0", v: "Move a window to a workspace" },
        { k: "Super  S", v: "Scratchpad workspace" },
        { k: "Super  arrows", v: "Focus the nearest window that way" },
        { k: "Super  Shift  arrows", v: "Swap with the nearest window that way" },
        { k: "Super  Shift  L", v: "Previous window arrangement" },
        { k: "Super  Ctrl  L, 1 … 9", v: "Pick an arrangement (0 for more)" },
        { k: "Super  Alt  L", v: "All arrangements" },
        { k: "Super  Z", v: "Make the focused window the main one" },
        { k: "Super  - / =", v: "Main window larger / smaller (Alt finer, Ctrl coarser)" },
        { k: "Alt  Tab", v: "Step through windows; let go to bring one forward" },
        { k: "Super  N", v: "Dismiss notifications" },
        { k: "Super  Shift  N", v: "Do not disturb" },
        { k: "Super  Print", v: "Screenshot to the clipboard" },
        { k: "Print", v: "Screenshot of an area to the clipboard" },
        { k: "Super  Shift  Print", v: "Screenshot of an area to Pictures/Screenshots" },
        { k: "Super  Shift  R", v: "Record the screen" },
        { k: "Super  Shift  M", v: "Power menu" },
        { k: "Super  I", v: "Installer (live USB)" }
    ]

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
    CcSection {
        title: "Shortcuts"
        Repeater { model: page.everyday; delegate: KeyRow {} }
    }
    CcMore {
        title: "All shortcuts"
        Repeater { model: page.more; delegate: KeyRow {} }
    }

    component KeyRow: RowLayout {
        id: row
        required property var modelData
        Layout.fillWidth: true
        spacing: 14
        Row {
            Layout.preferredWidth: 220
            spacing: 4
            Repeater {
                model: row.modelData.k.split("  ")
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
            text: row.modelData.v
            color: Cc.theme.textSecondary
            font.family: Cc.sans
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }
}
