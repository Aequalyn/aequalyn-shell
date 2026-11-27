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

    // the network credentials are being typed for, and which form to show
    property string askingFor: ""
    property bool askingEnterprise: false

    // the network whose details are open (click a row, not its Connect button)
    property string selectedSsid: ""
    readonly property var selectedNetwork: WifiService.networkForSsid(page.selectedSsid)
    readonly property bool selectedKnown: !!page.selectedNetwork && !!page.selectedNetwork.known
    readonly property bool selectedEnterprise: !!page.selectedNetwork
        && WifiService.isEnterprise(page.selectedNetwork.security)
    readonly property real speedScale: Math.max(100,
        Math.ceil(Math.max(WifiService.speedDownload, WifiService.speedUpload) / 100) * 100)

    function selectNetwork(net) {
        const ssid = net ? (net.name || "") : ""
        page.selectedSsid = page.selectedSsid === ssid ? "" : ssid
        WifiService.revealedPassword = ""
        WifiService.revealStatus = ""
        detailPassword.text = ""
        detailIdentity.text = ""
        detailCa.text = ""
    }
    function connectSelected() {
        const net = page.selectedNetwork
        if (!net) return
        if (net.connected) { WifiService.disconnectNetwork(net); return }
        if (page.selectedKnown) { WifiService.connectNetwork(net); return }
        if (WifiService.requiresCredentials(net.security)) {
            page.askingEnterprise = page.selectedEnterprise
            page.askingFor = page.selectedSsid
            return
        }
        WifiService.connectNetwork(net)
    }

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

    CcToggle {
        setting: "wifiAllowRestricted"
        title: "Allow restricted networks"
        sub: "Open captive portal logins and join enterprise networks like eduroam."
        enabled: WifiService.available
    }

    CcSection {
        visible: WifiService.allowRestricted && (WifiService.portalDetected || WifiService.eapStatus !== "")
        title: "Network sign-in"
        hint: "Only used while this switch is on."
        CcNote {
            visible: WifiService.portalDetected
            text: "This network asks you to sign in a browser before it gives you internet access."
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            CcButton {
                visible: WifiService.portalDetected
                text: "Open login page"
                primary: true
                onClicked: WifiService.openCaptivePortal()
            }
            CcButton {
                visible: WifiService.portalDetected
                text: "I've signed in — check again"
                onClicked: WifiService.recheckConnectivity()
            }
        }
        CcNote {
            visible: WifiService.eapStatus !== ""
            text: WifiService.eapStatus
        }
    }

    // ---- the selected network: details, credentials, forget, speed test ----
    CcSection {
        visible: page.selectedSsid !== ""
        title: "Network details"
        hint: page.selectedSsid + "  ·  " + (page.selectedKnown ? "Saved on this machine" : "New network")
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: page.selectedSsid
                color: Cc.theme.textPrimary
                font.family: Cc.sans
                font.pixelSize: 13
                font.weight: Font.DemiBold
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            CcButton { text: "Close"; onClicked: page.selectedSsid = "" }
        }
        CcNote {
            text: (page.selectedNetwork ? WifiService.securityText(page.selectedNetwork.security) : "")
                + "  ·  " + (page.selectedNetwork && page.strength(page.selectedNetwork) >= 66 ? "strong"
                : page.selectedNetwork && page.strength(page.selectedNetwork) >= 33 ? "good" : "weak")
                + " signal" + (page.selectedNetwork && page.selectedNetwork.connected ? "  ·  connected" : "")
        }
        CcField {
            id: detailIdentity
            visible: page.selectedEnterprise
            Layout.fillWidth: true
            placeholder: "Username, e.g. user@example.edu"
        }
        CcField {
            id: detailPassword
            Layout.fillWidth: true
            placeholder: page.selectedKnown ? "Enter a new password to change it" : "Password"
            echoMode: TextInput.Password
        }
        CcField {
            id: detailCa
            visible: page.selectedEnterprise
            Layout.fillWidth: true
            placeholder: "CA certificate file (optional)"
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            CcButton {
                text: page.selectedNetwork && page.selectedNetwork.connected ? "Disconnect" : "Connect"
                primary: true
                onClicked: page.connectSelected()
            }
            CcButton {
                visible: page.selectedKnown
                text: "Apply details"
                enabled: detailPassword.text.length > 0
                onClicked: {
                    if (WifiService.updateCredentials(page.selectedSsid, detailIdentity.text,
                                                      detailPassword.text, detailCa.text))
                        detailPassword.text = ""
                }
            }
            CcButton {
                visible: page.selectedKnown
                text: "Reveal password"
                onClicked: WifiService.revealPassword(page.selectedSsid)
            }
            CcButton {
                visible: page.selectedKnown
                text: "Forget"
                danger: true
                onClicked: {
                    WifiService.forgetNetwork(page.selectedNetwork)
                    page.selectedSsid = ""
                }
            }
        }
        CcNote {
            visible: WifiService.revealStatus !== ""
            text: WifiService.revealStatus
        }
        CcNote {
            visible: WifiService.revealedPassword !== ""
            text: "Saved password: " + WifiService.revealedPassword
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            CcButton {
                text: WifiService.speedRunning ? "Stop test" : "Run speed test"
                primary: !WifiService.speedRunning
                onClicked: WifiService.speedRunning ? WifiService.stopSpeedTest() : WifiService.runSpeedTest()
            }
            Text {
                text: WifiService.speedPhase === "download" ? "Downloading…"
                    : WifiService.speedPhase === "upload" ? "Uploading…"
                    : WifiService.speedPhase === "done" ? "Done"
                    : WifiService.speedPhase.indexOf("error") === 0 ? WifiService.speedPhase : ""
                color: Cc.theme.textMuted
                font.family: Cc.sans
                font.pixelSize: 10
                Layout.fillWidth: true
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            SpeedGauge {
                label: "DOWNLOAD"
                value: WifiService.speedDownload
                maxValue: page.speedScale
                color: Cc.theme.accentCyan
            }
            SpeedGauge {
                label: "UPLOAD"
                value: WifiService.speedUpload
                maxValue: page.speedScale
                color: Cc.theme.accentGreen
            }
        }
        Text {
            text: 'Measured with <a href="https://fast.com">fast.com</a>'
            color: Cc.theme.textMuted
            font.family: Cc.sans
            font.pixelSize: 9
            textFormat: Text.RichText
            onLinkActivated: Quickshell.execDetached(["xdg-open", "https://fast.com"])
        }
    }

    // credentials for a network you haven't joined before: a PSK for the usual
    // case, or an identity/password/CA pair for enterprise networks (eduroam)
    Rectangle {
        visible: page.askingFor !== ""
        onVisibleChanged: if (visible) {
            if (page.askingEnterprise) eapIdentity.forceInput(); else password.forceActiveFocus()
        }
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
                text: (page.askingEnterprise ? "Sign in to “" : "The password for “") + page.askingFor + "”"
                color: Cc.theme.textPrimary
                font.family: Cc.sans
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
            CcField {
                id: eapIdentity
                visible: page.askingEnterprise
                Layout.fillWidth: true
                placeholder: "Username, e.g. user@example.edu"
                onAccepted: password.forceActiveFocus()
            }
            CcField {
                id: eapCa
                visible: page.askingEnterprise
                Layout.fillWidth: true
                placeholder: "CA certificate file (optional)"
            }
            CcNote {
                visible: page.askingEnterprise && !WifiService.allowRestricted
                text: "Turn on “Allow restricted networks” above to join enterprise networks."
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
                CcButton {
                    text: page.askingEnterprise ? "Sign in" : "Join"
                    primary: true
                    enabled: page.askingEnterprise
                        ? (WifiService.allowRestricted && eapIdentity.text.length > 0 && password.text.length > 0)
                        : password.text.length > 0
                    onClicked: page.join()
                }
            }
        }
    }
    function join() {
        const net = WifiService.networkForSsid(page.askingFor);
        if (net) {
            if (page.askingEnterprise)
                WifiService.connectWithEap(net, eapIdentity.text, password.text, eapCa.text);
            else
                WifiService.connectWithPsk(net, password.text);
        }
        cancel();
    }
    function cancel() {
        password.text = ""; eapIdentity.text = ""; eapCa.text = "";
        page.askingFor = ""; page.askingEnterprise = false;
    }

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
                readonly property bool enterprise: WifiService.isEnterprise(modelData.security)
                icon: page.glyph(modelData)
                highlight: modelData.connected || (modelData.name || "") === page.selectedSsid
                clickable: true
                onClicked: page.selectNetwork(modelData)
                title: modelData.name || "Hidden network"
                sub: (modelData.connected ? "Connected" : modelData.known ? "Joined before"
                      : enterprise ? "Needs a sign-in" : locked ? "Needs a password" : "Open")
                    + "  ·  " + (page.strength(modelData) >= 66 ? "strong" : page.strength(modelData) >= 33 ? "good" : "weak") + " signal"
                action: modelData.connected ? "Disconnect" : "Connect"
                primary: !modelData.connected
                action2: modelData.known ? "Forget" : ""
                danger2: true
                onActivated: {
                    if (modelData.connected) WifiService.disconnectNetwork(modelData);
                    else if (enterprise && !modelData.known) {
                        page.askingEnterprise = true;
                        page.askingFor = modelData.name || "";
                    } else if (locked && !modelData.known) page.askingFor = modelData.name || "";
                    else WifiService.connectNetwork(modelData);
                }
                onActivated2: WifiService.forgetNetwork(modelData)
            }
        }
    }
}
