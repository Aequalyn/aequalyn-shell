// Window look: the space around windows, their corners, border and effects, with a
// picture that changes as you go.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/settings"
import "../../../plugins/atelier"
import ".."

CcPage {
    id: page
    title: "Window look"
    sub: "Space, corners and effects around every window."

    // two windows as they will look
    Item {
        id: pic
        Layout.fillWidth: true
        Layout.maximumWidth: 560
        Layout.preferredHeight: 230
        readonly property int go: AequalynSettings.gapsOut
        readonly property int gi: AequalynSettings.gapsIn
        Desk { anchors.fill: parent; theme: Cc.theme; source: Cc.wallpaper; radius: 14 }
        Rectangle {   // the bar
            x: 8; y: 6; width: parent.width - 16; height: 18; radius: 6
            color: Cc.alpha(Cc.theme.bgBase, 0.85)
        }
        Repeater {
            model: 2
            delegate: Rectangle {
                required property int index
                readonly property real w: (pic.width - 2 * pic.go - 2 * pic.gi) / 2
                x: pic.go + index * (w + 2 * pic.gi)
                y: 30 + pic.go
                width: w
                height: pic.height - 30 - 2 * pic.go
                radius: AequalynSettings.rounding
                color: Cc.theme.bgBase
                opacity: index === 0 ? AequalynSettings.activeOpacity : AequalynSettings.inactiveOpacity
                border.width: AequalynSettings.borderSize
                border.color: index === 0 ? Cc.theme.accentPrimary : Cc.theme.bgBorder
                Text {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: 12 + AequalynSettings.borderSize
                    text: index === 0 ? "❯ the window you use" : "another window"
                    color: index === 0 ? Cc.theme.accentPrimary : Cc.theme.textMuted
                    font.family: Cc.mono
                    font.pixelSize: 11
                }
            }
        }
    }

    CcSlider { setting: "gapsIn"; title: "Space between windows"; from: 0; to: 20; step: 1; unit: " px" }
    CcSlider { setting: "gapsOut"; title: "Space at the screen's edges"; from: 0; to: 30; step: 1; unit: " px" }
    CcSlider { setting: "rounding"; title: "Rounded corners"; from: 0; to: 24; step: 1; unit: " px"; zeroText: "Square" }
    CcSlider { setting: "borderSize"; title: "Border"; from: 0; to: 8; step: 1; unit: " px"; zeroText: "None" }
    CcToggle { setting: "blurEnabled"; title: "Blur behind see-through windows"; sub: "The bar, menus and see-through windows soften what is behind them." }
    CcToggle { setting: "animationsEnabled"; title: "Animations"; sub: "Windows glide when they open, close and move." }
    CcMore {
        CcSlider { setting: "blurSize"; title: "Blur strength"; from: 1; to: 20; step: 1; enabled: AequalynSettings.blurEnabled }
        CcSlider {
            setting: "activeOpacity"; title: "The window you're using"
            from: 0.6; to: 1; step: 0.05; format: v => Math.round(v * 100) + "% solid"
        }
        CcSlider {
            setting: "inactiveOpacity"; title: "Other windows"
            from: 0.6; to: 1; step: 0.05; format: v => Math.round(v * 100) + "% solid"
        }
    }
}
