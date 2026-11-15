// Window look: the space around windows, their corners, border and effects, with a
// picture that changes as you go; and what the desktop looks like behind the full-screen
// panels (this one, the pickers, clipboard, power menu, launcher, screens).
import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/settings"
import "../../../plugins/atelier"
import "root:/style/backdrop"
import "root:/style/backdrop/Styles.js" as Styles
import ".."

CcPage {
    id: page
    title: "Window look"
    sub: "Space, corners and effects around every window, and what shows behind panels like this one."
    tabs: ["Windows", "Behind panels"]
    stageTabs: [0]

    // two windows as they will look, pinned on top while the settings scroll
    stageHeight: 230
    stage: Item {
        id: pic
        anchors.fill: parent
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


    CcSlider { visible: page.tab === 0; setting: "gapsIn"; title: "Space between windows"; from: 0; to: 20; step: 1; unit: " px" }
    CcSlider { visible: page.tab === 0; setting: "gapsOut"; title: "Space at the screen's edges"; from: 0; to: 30; step: 1; unit: " px" }
    CcSlider { visible: page.tab === 0; setting: "rounding"; title: "Rounded corners"; from: 0; to: 24; step: 1; unit: " px"; zeroText: "Square" }
    CcSlider { visible: page.tab === 0; setting: "borderSize"; title: "Border"; from: 0; to: 8; step: 1; unit: " px"; zeroText: "None" }
    CcToggle { visible: page.tab === 0; setting: "blurEnabled"; title: "Blur behind see-through windows"; sub: "The bar, menus and see-through windows soften what is behind them." }
    CcToggle { visible: page.tab === 0; setting: "animationsEnabled"; title: "Animations"; sub: "Windows glide when they open, close and move." }
    CcMore {
        visible: page.tab === 0
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

    // ---- behind panels ------------------------------------------------------------------
    readonly property var bcfg: AequalynSettings.backdropCfg
    readonly property string bstyle: Styles.valid(bcfg.style)
    CcSection {
        visible: page.tab === 1
        title: "Behind panels"
        hint: "How the desktop looks behind this window, the theme and wallpaper pickers, the clipboard, the power menu, the launcher and Screens. Pick one and it plays behind this window; point at one to see it come and go."
        GridLayout {
            Layout.fillWidth: true
            columns: Math.max(2, Math.floor(width / 190))
            columnSpacing: 10
            rowSpacing: 10
            Repeater {
                model: Styles.list
                delegate: Rectangle {
                    id: tile
                    required property var modelData
                    readonly property bool on: page.bstyle === modelData.key
                    Layout.fillWidth: true
                    implicitHeight: pic.height + 62
                    radius: 14
                    color: on ? Cc.alpha(Cc.theme.accentPrimary, 0.14) : (tileArea.containsMouse ? Cc.theme.bgHover : Cc.theme.bgSurface)
                    border.width: 2
                    border.color: on ? Cc.theme.accentPrimary : "transparent"
                    Accessible.role: Accessible.RadioButton
                    Accessible.name: modelData.label
                    Accessible.checked: on

                    // the style on your wallpaper, with a little panel on top
                    Item {
                        id: pic
                        x: 8; y: 8
                        width: parent.width - 16
                        height: Math.round(width * 9 / 16)
                        clip: true
                        Rectangle { anchors.fill: parent; color: Cc.theme.bgSurface }   // until the picture loads
                        Backdrop {
                            id: mini
                            preview: true
                            image: Cc.wallpaper !== "" ? "file://" + Cc.wallpaper : ""
                            style: tile.modelData.key
                            theme: Cc.theme
                            strength: page.bcfg.strength
                            darkness: page.bcfg.dim
                            open: true
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width * 0.42
                            height: parent.height * 0.46
                            radius: 6
                            color: Cc.theme.bgBase
                            border.width: 1
                            border.color: Cc.theme.bgBorder
                            opacity: mini.progress
                            scale: 0.97 + 0.03 * mini.progress
                        }
                        // come and go while pointed at
                        Timer {
                            interval: 1300
                            repeat: true
                            running: tileArea.containsMouse && page.visible
                            triggeredOnStart: true
                            onTriggered: mini.open = !mini.open
                            onRunningChanged: if (!running) mini.open = true
                        }
                    }
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        y: pic.y + pic.height + 10
                        text: tile.modelData.label
                        elide: Text.ElideRight
                        color: Cc.theme.textPrimary
                        font.family: Cc.sans
                        font.pixelSize: 13
                        font.weight: tile.on ? Font.DemiBold : Font.Normal
                    }
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        y: pic.y + pic.height + 30
                        text: tile.modelData.sub
                        elide: Text.ElideRight
                        color: Cc.theme.textMuted
                        font.family: Cc.sans
                        font.pixelSize: 11
                    }
                    MouseArea {
                        id: tileArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: AequalynSettings.setIn("backdrop", "style", tile.modelData.key)
                    }
                }
            }
        }
    }
    CcSection {
        visible: page.tab === 1
        title: "Colour"
        hint: page.bcfg.colour === "neutral" ? "Black shade and a plain blur, whatever the theme."
                                             : "The theme's background as the shade, with a touch of its accent in the blur."
        CcChoice {
            options: [{ key: "theme", label: "From the theme" }, { key: "neutral", label: "Neutral" }]
            current: page.bcfg.colour === "neutral" ? "neutral" : "theme"
            onChosen: key => AequalynSettings.setIn("backdrop", "colour", key)
        }
    }
    CcSlider {
        visible: page.tab === 1
        enabled: page.bstyle !== "instant" && page.bstyle !== "dim"
        title: "Blur strength"
        sub: page.bstyle === "instant" ? "Instant uses the blur strength of see-through windows (Windows tab)."
           : page.bstyle === "dim" ? "Dim only has no blur." : ""
        value: Number(page.bcfg.strength)
        from: 0; to: 100; step: 5
        format: v => v <= 15 ? "Light" : v >= 80 ? "Strong" : Math.round(v) + "%"
        onCommitted: v => AequalynSettings.setIn("backdrop", "strength", v)
    }
    CcSlider {
        visible: page.tab === 1
        title: "Darkness"
        sub: "How much each panel darkens the desktop behind it. The middle is each panel's own shade."
        value: Number(page.bcfg.dim)
        from: 0; to: 100; step: 5
        format: v => v === 0 ? "Not darker" : v === 50 ? "As each panel sets" : Math.round(v) + "%"
        onCommitted: v => AequalynSettings.setIn("backdrop", "dim", v)
    }
}
