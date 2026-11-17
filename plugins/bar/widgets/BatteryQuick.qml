// The battery's quick panel: how full it is and how long it lasts, and the power
// profile; last, the Lock and sleep page.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "root:/plugins/bar/quick"
import ".."

QuickPopup {
    id: q
    required property var bar

    property string profile: ""
    property string timeLeft: ""
    property string rate: ""
    Process {
        id: info
        command: ["sh", "-c", "powerprofilesctl get 2>/dev/null || echo; b=$(upower -e 2>/dev/null | grep -m1 BAT); [ -n \"$b\" ] && upower -i \"$b\" | grep -E 'time to (empty|full)|energy-rate' | sed 's/^ *//'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n");
                q.profile = (l[0] || "").trim();
                q.timeLeft = ""; q.rate = "";
                for (const s of l.slice(1)) {
                    const m = /^(time to empty|time to full|energy-rate):\s*(.+)$/.exec(s.trim());
                    if (!m) continue;
                    if (m[1] === "energy-rate") q.rate = m[2];
                    else q.timeLeft = (m[1] === "time to full" ? "Full in " : "Lasts ") + m[2];
                }
            }
        }
    }
    Timer { interval: 15000; repeat: true; running: q.visible; triggeredOnStart: true; onTriggered: info.running = true }
    function setProfile(p) { q.profile = p; Quickshell.execDetached(["powerprofilesctl", "set", p]) }

    glyph: SystemInfo.batteryIcon
    title: "Battery"
    sub: SystemInfo.batteryCharging ? "Charging" : "On battery"
    settingsLabel: "Lock and sleep settings"
    onSettingsClicked: { q.dismissed(); q.bar.openPage("sleep") }

    QuickCard {
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Text {
                text: SystemInfo.batteryLevel
                color: Quick.theme.textPrimary
                font.family: Quick.mono
                font.pixelSize: 32
                font.weight: Font.Medium
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text { Layout.fillWidth: true; text: q.timeLeft !== "" ? q.timeLeft : (SystemInfo.batteryCharging ? "Charging" : "Working it out…"); color: Quick.theme.textSecondary; font.family: Quick.mono; font.pixelSize: 12; elide: Text.ElideRight }
                Text { Layout.fillWidth: true; visible: q.rate !== ""; text: "Using " + q.rate; color: Quick.theme.textMuted; font.family: Quick.mono; font.pixelSize: 11 }
            }
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 6
            radius: 3
            color: Quick.theme.bgSelected
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, SystemInfo.batteryLevelRaw / 100))
                height: parent.height
                radius: 3
                color: SystemInfo.batteryLevelRaw <= 15 && !SystemInfo.batteryCharging ? Quick.theme.accentRed : Quick.theme.accentPrimary
            }
        }
    }

    QuickLabel { visible: q.profile !== ""; text: "Power profile" }
    RowLayout {
        visible: q.profile !== ""
        Layout.fillWidth: true
        spacing: 8
        Repeater {
            model: [
                { key: "power-saver", label: "Saver", glyph: "\u{F032A}" },
                { key: "balanced", label: "Balanced", glyph: "\u{F05D1}" },
                { key: "performance", label: "Fast", glyph: "\u{F04C5}" }
            ]
            delegate: QuickWide {
                required property var modelData
                glyph: modelData.glyph
                label: modelData.label
                on: q.profile === modelData.key
                onClicked: q.setProfile(modelData.key)
            }
        }
    }
}
