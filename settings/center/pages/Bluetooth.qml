// Bluetooth: on or off, the devices it remembers and the ones nearby, and how a
// connected headset sounds.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "root:/settings"
import "root:/plugins/bluetooth"
import ".."

CcPage {
    id: page
    title: "Bluetooth"
    sub: !BluetoothService.available ? "No Bluetooth adapter was found."
        : !BluetoothService.powered ? "Bluetooth is off."
        : BluetoothService.connectedName !== "" ? "Connected to " + BluetoothService.connectedName + "."
        : "Pair something new, or connect what it remembers."
    actions: [
        CcButton {
            visible: BluetoothService.powered
            text: BluetoothService.discovering ? "Stop looking" : "Look for devices"
            icon: "\u{F0450}"
            primary: !BluetoothService.discovering
            onClicked: page.look(!BluetoothService.discovering)
        }
    ]

    // a search started here stops when you leave the page
    property bool startedLook: false
    function look(on) { BluetoothService.setDiscovering(on); startedLook = on; }
    Component.onDestruction: if (startedLook) BluetoothService.setDiscovering(false)

    function glyph(d) {
        const i = (d && d.icon) || "";
        if (i.indexOf("headset") >= 0 || i.indexOf("headphone") >= 0) return "\u{F02CB}";
        if (i.indexOf("audio") >= 0) return "\u{F04C3}";
        if (i.indexOf("keyboard") >= 0) return "\u{F030C}";
        if (i.indexOf("mouse") >= 0) return "\u{F037D}";
        if (i.indexOf("gaming") >= 0) return "\u{F0297}";
        if (i.indexOf("phone") >= 0) return "\u{F03F2}";
        if (i.indexOf("computer") >= 0) return "\u{F07C0}";
        return "\u{F00AF}";
    }
    function describe(d) {
        if (d.pairing || BluetoothService.isPending(d)) return "Pairing…";
        if (d.state === 3) return "Connecting…";
        if (d.state === 2) return "Disconnecting…";
        const battery = d.batteryAvailable ? "  ·  battery " + Math.round(d.battery * 100) + "%" : "";
        if (d.connected) return "Connected" + battery;
        return BluetoothService.isRemembered(d) ? "Not connected" : "Ready to pair";
    }
    function busy(d) { return d.pairing || d.state === 2 || d.state === 3 || BluetoothService.isPending(d); }

    CcToggle {
        title: "Bluetooth"
        sub: BluetoothService.available ? "Others see this computer while you look for devices." : "No adapter."
        enabled: BluetoothService.available
        checked: BluetoothService.powered
        onToggled: BluetoothService.togglePower()
    }

    CcSection {
        visible: BluetoothService.powered && BluetoothService.remembered.length > 0
        title: "Remembered"
        Repeater {
            model: BluetoothService.remembered
            delegate: CcRow {
                required property var modelData
                icon: page.glyph(modelData)
                highlight: modelData.connected
                title: BluetoothService.label(modelData)
                sub: page.describe(modelData)
                busy: page.busy(modelData)
                action: modelData.connected ? "Disconnect" : "Connect"
                primary: !modelData.connected
                action2: "Forget"
                danger2: true
                onActivated: modelData.connected ? BluetoothService.disconnectDevice(modelData) : BluetoothService.connectDevice(modelData)
                onActivated2: BluetoothService.forgetDevice(modelData)
            }
        }
    }
    CcSection {
        visible: BluetoothService.powered
        title: "Nearby"
        hint: "Put your device in pairing mode. Once paired, it is remembered."
        CcNote {
            visible: BluetoothService.nearby.length === 0
            text: BluetoothService.discovering ? "Looking for devices…" : "Press “Look for devices” to find something new."
        }
        Repeater {
            model: BluetoothService.nearby
            delegate: CcRow {
                required property var modelData
                icon: page.glyph(modelData)
                title: BluetoothService.label(modelData)
                sub: page.describe(modelData)
                busy: page.busy(modelData)
                action: "Pair"
                primary: true
                onActivated: BluetoothService.connectDevice(modelData)
            }
        }
    }

    // ---- how a headset sounds: PipeWire card profiles (A2DP, HSP / HFP) -------------
    property var cards: []
    property string cardMessage: ""
    function refreshCards() { if (!cardList.running) cardList.running = true; }
    Component.onCompleted: refreshCards()
    Timer { interval: 6000; repeat: true; running: true; onTriggered: page.refreshCards() }
    Process {
        id: cardList
        command: ["aequalyn-bluetooth-audio", "status"]
        stdout: StdioCollector {
            onStreamFinished: { try { page.cards = JSON.parse(text).cards || []; } catch (e) { page.cards = []; } }
        }
    }
    Process {
        id: cardSet
        stdout: StdioCollector {
            onStreamFinished: {
                page.cardMessage = text.trim() === "ok" ? "" : "That didn't work. Try again in a moment.";
                page.refreshCards();
            }
        }
    }

    CcSection {
        visible: page.cards.length > 0
        title: "Headphones sound"
        hint: "Best quality for music and videos. For calls also turns on the headset's microphone, at lower quality."
        Repeater {
            model: page.cards
            delegate: ColumnLayout {
                id: card
                required property var modelData
                Layout.fillWidth: true
                spacing: 6
                Text {
                    text: card.modelData.description
                    color: Cc.theme.textPrimary
                    font.family: Cc.sans
                    font.pixelSize: 13
                }
                CcChoice {
                    current: card.modelData.activeProfile
                    options: (card.modelData.profiles || []).map(p => ({ key: p.name, label: p.description || p.name }))
                    onChosen: key => {
                        cardSet.command = ["aequalyn-bluetooth-audio", "set", card.modelData.name, key];
                        cardSet.running = true;
                    }
                }
            }
        }
        CcNote { visible: page.cardMessage !== ""; text: page.cardMessage; color: Cc.theme.accentRed }
    }
}
