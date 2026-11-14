// Home: your desktop in miniature, and every part of it opens its page. Below it a few
// things people often want, and how Wi-Fi, Bluetooth and the rest are right now.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/settings"
import "../../../plugins/atelier"
import "root:/plugins/wifi"
import "root:/plugins/bluetooth"
import "../../../style/BarLooks.js" as BarLooks
import ".."

CcPage {
    id: page
    readonly property int hour: new Date().getHours()
    title: (hour < 5 ? "Good evening" : hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening")
        + ". What would you like to change?"
    sub: "Click any part of your desktop below, or just start typing."

    readonly property var svc: AtelierHost.docks
    readonly property var look: BarLooks.clean(AequalynSettings.barStyleCfg)
    readonly property var stageDocks: svc ? svc.docks.map((d, i) => {
        const e = svc.effective(i);
        return { look: e, pal: svc.palette(e), edge: d.edge, icons: Math.max(3, Math.min(6, d.apps.length)) };
    }) : []

    // ---- the desktop -----------------------------------------------------------------
    Item {
        id: desk
        Layout.fillWidth: true
        Layout.maximumWidth: 760
        Layout.preferredHeight: width * 9 / 16
        property string hover: ""

        Stage {
            anchors.fill: parent
            theme: Cc.theme
            font: Cc.mono
            wallpaper: Cc.wallpaper
            barLook: page.look
            barSize: 24
            docks: page.stageDocks
            dockSize: 24
        }

        // the parts you can click; the wallpaper is everything the others leave
        Hot { name: "wallpaper"; label: "Wallpaper"; anchors.fill: parent; inset: 0; tipLow: true }
        Hot { name: "bar"; label: "The bar"; x: 4; y: 2; width: parent.width - 8; height: 38 }
        Hot { name: "arrange"; label: "Your windows"; x: parent.width * 0.04; y: parent.height * 0.25; width: parent.width * 0.92; height: parent.height * 0.54 }
        Hot {
            visible: page.stageDocks.length > 0
            name: "dock"; label: "The dock"
            x: parent.width * 0.2; y: parent.height - 52; width: parent.width * 0.6; height: 50
        }
    }

    // ---- quick ideas -------------------------------------------------------------------
    Flow {
        Layout.fillWidth: true
        spacing: 8
        Repeater {
            model: [
                { t: "Choose a new wallpaper", p: "wallpaper" },
                { t: "Try another theme", p: "theme" },
                { t: "Change how the bar looks", p: "bar" },
                { t: "Arrange my windows", p: "arrange" },
                { t: "Connect headphones", p: "bluetooth" },
                { t: "Make the screen dimmer", p: "screens" },
                { t: "Stop the screen locking", p: "sleep" }
            ]
            delegate: Rectangle {
                required property var modelData
                implicitWidth: chipText.implicitWidth + 28
                implicitHeight: 32
                radius: 16
                color: chipArea.containsMouse ? Cc.alpha(Cc.theme.accentPrimary, 0.14) : Cc.theme.bgSurface
                border.width: 1
                border.color: chipArea.containsMouse ? Cc.theme.accentPrimary : Cc.theme.bgBorder
                Text {
                    id: chipText
                    anchors.centerIn: parent
                    text: modelData.t
                    color: chipArea.containsMouse ? Cc.theme.accentPrimary : Cc.theme.textSecondary
                    font.family: Cc.sans
                    font.pixelSize: 12
                }
                MouseArea {
                    id: chipArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Cc.go(modelData.p)
                }
            }
        }
    }

    // ---- how things are right now ---------------------------------------------------
    GridLayout {
        Layout.fillWidth: true
        columns: Math.max(2, Math.min(3, Math.floor(width / 240)))
        columnSpacing: 10
        rowSpacing: 10
        CcCard {
            icon: "\u{F05A9}"; title: "Wi-Fi"
            sub: !WifiService.available ? "No Wi-Fi here" : !WifiService.wifiEnabled ? "Off"
                : WifiService.connectedName !== "" ? WifiService.connectedName : "Not connected"
            lit: WifiService.connectedName !== ""
            onClicked: Cc.go("wifi")
        }
        CcCard {
            icon: "\u{F00AF}"; title: "Bluetooth"
            sub: !BluetoothService.available ? "No Bluetooth here" : !BluetoothService.powered ? "Off"
                : BluetoothService.connectedName !== "" ? BluetoothService.connectedName
                : BluetoothService.remembered.length + " remembered"
            lit: BluetoothService.connectedName !== ""
            onClicked: Cc.go("bluetooth")
        }
        CcCard {
            icon: "\u{F03D8}"; title: "Theme"
            sub: Cc.theme.wallpaperMode ? "Colours from the wallpaper" : (Cc.theme.currentName || "")
            onClicked: Cc.go("theme")
        }
        CcCard {
            icon: "\u{F0379}"; title: "Screens"
            sub: Quickshell.screens.length === 1 ? "1 screen" : Quickshell.screens.length + " screens"
            onClicked: Cc.go("screens")
        }
        CcCard {
            icon: "\u{F06B0}"; title: "Updates"
            sub: Cc.updates ? Cc.updates.status : ""
            lit: Cc.updates && Cc.updates.state === "behind"
            onClicked: Cc.go("updates")
        }
        CcCard {
            icon: "\u{F033E}"; title: "Lock and sleep"
            sub: AequalynSettings.lockEnabled ? "Locks after " + AequalynSettings.lockMinutes + " min" : "Never locks by itself"
            onClicked: Cc.go("sleep")
        }
    }

    // a part of the desktop picture that opens a page
    component Hot: Item {
        id: hot
        property string name: ""
        property string label: ""
        property int inset: -3
        property bool tipLow: false     // the label near the bottom, out of the windows' way
        readonly property bool on: area.containsMouse
        Rectangle {
            anchors.fill: parent
            anchors.margins: hot.inset
            radius: 12
            color: "transparent"
            border.width: 2
            border.color: hot.on ? Cc.theme.accentPrimary : "transparent"
        }
        Rectangle {
            visible: hot.on
            anchors.horizontalCenter: parent.horizontalCenter
            y: hot.tipLow ? parent.height * 0.84 - height / 2 : (parent.height - height) / 2
            width: tip.implicitWidth + 22
            height: 26
            radius: 13
            color: Cc.theme.accentPrimary
            Text {
                id: tip
                anchors.centerIn: parent
                text: hot.label
                color: Cc.theme.bgBase
                font.family: Cc.sans
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Cc.go(hot.name)
        }
    }
}
