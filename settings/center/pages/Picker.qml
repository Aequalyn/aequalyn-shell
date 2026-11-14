// Theme picker: what Super + T and Super + W open, and how it looks (Atelier's panel pane).
import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/settings"
import "../../../plugins/atelier"
import ".."

CcPage {
    id: page
    title: "Theme picker"
    sub: "What Super + T and Super + W open: its type, shape, place and size."
    fills: [0]
    actions: [
        CcButton { text: "Try it"; icon: "\u{F0E09}"; onClicked: Cc.ipc(["atelier", "open", "themes"], true) }
    ]
    PanelPane {
        Layout.fillWidth: true
        Layout.fillHeight: true
        theme: Cc.theme
        font: Cc.mono
    }
}
