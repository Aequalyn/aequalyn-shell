// Wi-Fi's quick panel: Wi-Fi on or off, the networks around (the strongest first), and
// a password asked for right here when a network needs one; last, the Wi-Fi page.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/plugins/bar/quick"
import "root:/plugins/wifi"

QuickPopup {
    id: q
    required property var bar
    onOpenChanged: if (open && WifiService.wifiEnabled) WifiService.scan()

    function pct(n) { const v = Number(n.signalStrength || 0); return Math.round(v <= 1 ? v * 100 : v) }
    function glyph(n) { const p = pct(n); return p > 75 ? "\u{F0928}" : p > 50 ? "\u{F0925}" : p > 25 ? "\u{F0922}" : "\u{F091F}" }
    readonly property var list: WifiService.networks.slice().sort((a, b) => (b.connected - a.connected) || (pct(b) - pct(a)))
    // the network a password is being typed for
    property var asking: null

    glyph: "\u{F05A9}"
    title: "Wi-Fi"
    sub: !WifiService.available ? "No Wi-Fi here" : !WifiService.wifiEnabled ? "Off"
        : WifiService.connectedName !== "" ? "Connected to " + WifiService.connectedName : "Not connected"
    settingsLabel: "Wi-Fi settings"
    onSettingsClicked: { q.dismissed(); q.bar.openPage("wifi") }
    actions: [
        QuickRound {
            small: true; glyph: WifiService.scanning ? "\u{F0453}" : "\u{F0450}"; tip: "Look again"
            enabled: WifiService.wifiEnabled; onClicked: WifiService.scan()
        }
    ]

    QuickTile {
        glyph: "\u{F05A9}"; title: "Wi-Fi"
        sub: WifiService.wifiEnabled ? WifiService.networkCount + (WifiService.networkCount === 1 ? " network around" : " networks around") : "Off"
        on: WifiService.wifiEnabled
        enabled: WifiService.available
        onToggled: WifiService.toggleWifi()
    }

    // a password, for a network that needs one and isn't known yet
    QuickCard {
        visible: !!q.asking
        Text {
            Layout.fillWidth: true
            text: q.asking ? "Password for " + q.asking.name : ""
            color: Quick.theme.textPrimary
            font.family: Quick.mono
            font.pixelSize: 12
            elide: Text.ElideRight
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 40
            radius: 10
            color: Quick.theme.bgBase
            border.width: 1
            border.color: psk.activeFocus ? Quick.theme.accentPrimary : Quick.theme.bgBorder
            TextInput {
                id: psk
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password
                color: Quick.theme.textPrimary
                font.family: Quick.mono
                font.pixelSize: 13
                clip: true
                onAccepted: q.join()
                Keys.onEscapePressed: q.asking = null
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            QuickWide { label: "Cancel"; onClicked: q.asking = null }
            QuickWide { label: "Connect"; on: true; enabled: psk.text.length >= 8; onClicked: q.join() }
        }
    }
    function join() {
        if (!q.asking || psk.text.length < 8) return
        WifiService.connectWithPsk(q.asking, psk.text)
        psk.text = ""
        q.asking = null
    }
    onAskingChanged: { psk.text = ""; if (asking) psk.forceActiveFocus() }
    onVisibleChanged: if (!visible) q.asking = null

    QuickLabel { visible: WifiService.wifiEnabled && q.list.length > 0; text: "Networks" }
    Flickable {
        visible: WifiService.wifiEnabled && q.list.length > 0
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(netCol.implicitHeight, 300)
        contentHeight: netCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: netCol
            width: parent.width
            spacing: 6
            Repeater {
                model: q.list
                delegate: QuickTile {
                    required property var modelData
                    glyph: q.glyph(modelData)
                    title: modelData.name || "Hidden network"
                    sub: (modelData.connected ? "Connected · " : modelData.known ? "Known · " : "")
                        + q.pct(modelData) + "% · " + WifiService.securityText(modelData.security)
                    on: !!modelData.connected
                    onToggled: {
                        if (modelData.connected) WifiService.disconnectNetwork(modelData)
                        else if (WifiService.requiresCredentials(modelData.security) && !modelData.known) q.asking = modelData
                        else WifiService.connectNetwork(modelData)
                    }
                }
            }
        }
    }
    Text {
        visible: WifiService.wifiEnabled && q.list.length === 0
        Layout.fillWidth: true
        text: WifiService.scanning ? "Looking for networks…" : "No networks around."
        color: Quick.theme.textMuted
        font.family: Quick.mono
        font.pixelSize: 11
    }
}
