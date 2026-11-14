// Dock: every dock, where it sits, how it hides and how it looks (Atelier's docks pane).
import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/settings"
import "../../../plugins/atelier"
import ".."

CcPage {
    id: page
    title: "Dock"
    sub: "The apps you keep at hand. Up to 4 docks on each edge of each screen; right-click a dock to come here."
    fills: [0]
    actions: [
        CcButton { text: "Add a dock"; icon: "\u{F0415}"; onClicked: Cc.ipc(["dock", "add"], false) }
    ]
    DocksPane {
        Layout.fillWidth: true
        Layout.fillHeight: true
        theme: Cc.theme
        font: Cc.mono
    }
}
