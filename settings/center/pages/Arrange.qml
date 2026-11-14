// Arranging windows: every layout as a picture, per workspace (Atelier's layouts
// pane), and Hyprland's own arrangement for workspaces without one.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/settings"
import "../../../plugins/atelier"
import ".."

CcPage {
    id: page
    title: "Arranging windows"
    sub: "How windows share the screen. Each workspace keeps its own choice."
    tabs: ["Layouts", "Without a layout"]
    fills: [0]

    LayoutsPane {
        id: layouts
        visible: page.tab === 0
        Layout.fillWidth: true
        Layout.fillHeight: true
        theme: Cc.theme
        font: Cc.mono
        Component.onCompleted: selectActive()
    }

    CcSection {
        visible: page.tab === 1
        title: "Hyprland's own arrangement"
        hint: "Used on workspaces where no layout is picked."
        CcChoice {
            setting: "layout"
            options: [
                { key: "dwindle", label: "Split in half, again and again" },
                { key: "master", label: "One big, the rest stacked" },
                { key: "scrolling", label: "A scrolling row" }
            ]
        }
    }
    CcNote {
        visible: page.tab === 1
        text: "Super + L steps through the layouts marked with a dot, Super + Shift + L goes back. Super + Ctrl + L, then a number, picks one."
    }
}
