// Wi-Fi: on or off, the networks around you, and the password for a new one.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "root:/settings"
import "root:/plugins/wifi"
import ".."

CcPage {
    id: page
    title: "Wi-Fi"
    sub: !WifiService.available ? "No Wi-Fi adapter was found."
        : !WifiService.wifiEnabled ? "Wi-Fi is off."
        : WifiService.connectedName !== "" ? "Connected to " + WifiService.connectedName + "."
        : "Not connected."
    actions: [
        CcButton {
            text: WifiService.scanning ? "Looking…" : "Look again"; icon: "\u{F0450}"
            enabled: WifiService.available && WifiService.wifiEnabled
            onClicked: page.scan()
        }
    ]

    // the network a password is being typed for
    property string askingFor: ""

    function scan() { WifiService.scan(); stopScan.restart(); }
    Component.onCompleted: scan()
    Timer { id: stopScan; interval: 3000; onTriggered: WifiService.setScanning(false) }
    Timer { interval: 5000; repeat: true; running: true; onTriggered: WifiService.scan() }

    function strength(n) {
        const s = n.signalStrength || 0;
        return s <= 1 ? s * 100 : s;
    }
    function glyph(n) {
        const s = strength(n);
        return s >= 75 ? "\u{F0928}" : s >= 50 ? "\u{F0925}" : s >= 25 ? "\u{F0922}" : "\u{F091F}";
    }

    CcToggle {
        title: "Wi-Fi"
        sub: "Turn it off to save battery, or on a plane."
        enabled: WifiService.available
        checked: WifiService.wifiEnabled
        onToggled: WifiService.toggleWifi()
    }

    // the password for a network you haven't joined before
    Rectangle {
        visible: page.askingFor !== ""
        onVisibleChanged: if (visible) password.forceActiveFocus()
        Layout.fillWidth: true
        implicitHeight: askCol.implicitHeight + 32
        radius: 14
        color: Cc.theme.bgSurface
        border.width: 2
        border.color: Cc.theme.accentPrimary
        ColumnLayout {
            id: askCol
            x: 16; y: 16
            width: parent.width - 32
            spacing: 10
            Text {
                text: "The password for “" + page.askingFor + "”"
                color: Cc.theme.textPrimary
                font.family: Cc.sans
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 40
                radius: 10
                color: Cc.theme.bgBase
                border.color: password.activeFocus ? Cc.theme.accentPrimary : Cc.theme.bgBorder
                border.width: 1
                TextInput {
                    id: password
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    color: Cc.theme.textPrimary
                    font.family: Cc.sans
                    font.pixelSize: 13
                    echoMode: show.checked ? TextInput.Normal : TextInput.Password
                    onAccepted: page.join()
                    Keys.onEscapePressed: event => { page.cancel(); event.accepted = true; }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                CcSwitch { id: show; scale: 0.8; onToggled: v => checked = v }
                Text { text: "Show the password"; color: Cc.theme.textSecondary; font.family: Cc.sans; font.pixelSize: 12; Layout.fillWidth: true }
                CcButton { text: "Cancel"; onClicked: page.cancel() }
                CcButton { text: "Join"; primary: true; enabled: password.text.length > 0; onClicked: page.join() }
            }
        }
    }
    function join() {
        const net = WifiService.networkForSsid(page.askingFor);
        if (net) WifiService.connectWithPsk(net, password.text);
        cancel();
    }
    function cancel() { password.text = ""; page.askingFor = ""; }

    CcSection {
        visible: WifiService.wifiEnabled
        title: "Networks around you"
        CcNote {
            visible: WifiService.networkCount === 0
            text: WifiService.scanning ? "Looking for networks…" : "No networks found. Look again in a moment."
        }
        Repeater {
            model: WifiService.networks
            delegate: CcRow {
                required property var modelData
                readonly property bool locked: WifiService.requiresCredentials(modelData.security)
                icon: page.glyph(modelData)
                highlight: modelData.connected
                title: modelData.name || "Hidden network"
                sub: (modelData.connected ? "Connected" : modelData.known ? "Joined before" : locked ? "Needs a password" : "Open")
                    + "  ·  " + (page.strength(modelData) >= 66 ? "strong" : page.strength(modelData) >= 33 ? "good" : "weak") + " signal"
                action: modelData.connected ? "Disconnect" : "Connect"
                primary: !modelData.connected
                action2: modelData.known ? "Forget" : ""
                danger2: true
                onActivated: {
                    if (modelData.connected) WifiService.disconnectNetwork(modelData);
                    else if (locked && !modelData.known) page.askingFor = modelData.name || "";
                    else WifiService.connectNetwork(modelData);
                }
                onActivated2: WifiService.forgetNetwork(modelData)
            }
        }
    }
}
