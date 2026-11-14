// Screens: brightness, and the screens there are; the screen map (Super + O) arranges them.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/settings"
import "../../../plugins/monitorManager"
import ".."

CcPage {
    id: page
    title: "Screens"
    sub: "How bright, and where each screen sits."
    actions: [
        CcButton { text: "Arrange screens"; icon: "\u{F0379}"; primary: true; onClicked: Cc.ipc(["monitors", "toggle"], true) }
    ]

    CcSection {
        title: "Brightness"
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: bright.implicitHeight + 28
            radius: 12
            color: Cc.theme.bgSurface
            BrightnessControl {
                id: bright
                x: 16; y: 14
                width: parent.width - 32
                theme: Cc.theme
                font: Cc.mono
            }
        }
    }
    CcSection {
        title: Quickshell.screens.length === 1 ? "Your screen" : "Your screens"
        hint: "Size, refresh rate, position, rotation and mirroring are set in the screen map. Super + O opens it from anywhere."
        Repeater {
            model: Quickshell.screens
            delegate: CcRow {
                required property var modelData
                icon: "\u{F0379}"
                title: modelData.model || modelData.name
                sub: modelData.name + "  ·  " + modelData.width + " × " + modelData.height
                    + (Math.abs(modelData.devicePixelRatio - 1) > 0.01 ? "  ·  scaled " + Math.round(modelData.devicePixelRatio * 100) + "%" : "")
            }
        }
    }
}
