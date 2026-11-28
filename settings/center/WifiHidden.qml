// Join a network that does not announce its name: it is saved, then joined. The password
// goes to tools/wifi/aequalyn-wifi-profile on stdin, never on a command line.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "root:/settings"

CcSection {
    id: box
    title: "Join a hidden network"
    hint: "One that does not show in the list: its name, and its password when it has one."
    property string security: "wpa-psk"
    property string status: ""
    readonly property string tool: Quickshell.env("HOME") + "/.config/quickshell/tools/wifi/aequalyn-wifi-profile"

    function join() {
        const ssid = name.text.trim()
        if (ssid === "") { box.status = "Type the network's name first."; return }
        box.status = "Joining " + ssid + "…"
        joiner.pending = box.security === "wpa-psk" ? password.text : ""
        password.text = ""
        joiner.exec({ command: ["python3", box.tool, "hidden", ssid, box.security] })
    }
    Process {
        id: joiner
        property string pending: ""
        // the password goes down the pipe once the helper is up, then is forgotten here
        stdinEnabled: true
        onStarted: { joiner.write(joiner.pending + "\n"); joiner.pending = "" }
        stdout: StdioCollector {
            onStreamFinished: {
                let r = {}
                try { r = JSON.parse(text) } catch (e) { r = { ok: false, error: "no answer" } }
                box.status = r.ok ? "Joined." : (r.error || "Could not join it.")
                if (r.ok) name.text = ""
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        CcField { id: name; Layout.fillWidth: true; placeholder: "Network name" }
        CcChoice {
            options: [{ key: "wpa-psk", label: "Password" }, { key: "open", label: "Open" }]
            current: box.security
            onChosen: k => box.security = k
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        CcField {
            id: password
            visible: box.security === "wpa-psk"
            Layout.fillWidth: true
            placeholder: "Password"
            echoMode: TextInput.Password
            onAccepted: box.join()
        }
        CcButton { text: "Join"; primary: true; onClicked: box.join() }
    }
    CcNote { visible: box.status !== ""; text: box.status }
}
