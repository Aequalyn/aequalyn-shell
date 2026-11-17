// The system's quick panel (the CPU and temperature widgets): how busy it is, how warm,
// and what uses the most right now; last, the system monitor.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "root:/settings"
import "root:/plugins/bar/quick"
import ".."

QuickPopup {
    id: q
    required property var bar
    readonly property bool sysmonOn: (AequalynSettings.enabledPlugins || []).indexOf("sysmon") >= 0

    property var top: []
    Process {
        id: ps
        command: ["ps", "-eo", "pcpu,pmem,comm", "--sort=-pcpu", "--no-headers"]
        stdout: StdioCollector {
            onStreamFinished: q.top = text.split("\n").map(l => l.trim()).filter(l => l !== "").slice(0, 6).map(l => {
                const m = /^(\S+)\s+(\S+)\s+(.+)$/.exec(l);
                return m ? { cpu: m[1], mem: m[2], name: m[3] } : null;
            }).filter(x => x)
        }
    }
    Timer { interval: 3000; repeat: true; running: q.visible; triggeredOnStart: true; onTriggered: ps.running = true }

    glyph: "\u{F0EE0}"
    title: "System"
    sub: "Every three seconds while it's open"
    settingsLabel: q.sysmonOn ? "Open the system monitor" : "Turn on the system monitor"
    onSettingsClicked: {
        q.dismissed();
        if (q.sysmonOn) Quickshell.execDetached(["qs", "ipc", "call", "sysmon", "toggle"]);
        else Quickshell.execDetached(["qs", "ipc", "call", "aequalyn", "pluginPage", "sysmon"]);
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Repeater {
            model: [
                { glyph: "\u{F0EE0}", name: "Processor", value: SystemInfo.cpuUsage },
                { glyph: "\u{F035B}", name: "Memory", value: SystemInfo.memoryUsage },
                { glyph: "\u{F050F}", name: "Warmth", value: SystemInfo.temperature }
            ]
            delegate: QuickCard {
                required property var modelData
                spacing: 2
                Text { text: modelData.glyph + "  " + modelData.name; color: Quick.theme.accentPrimary; font.family: Quick.mono; font.pixelSize: 10 }
                Text { text: modelData.value; color: Quick.theme.textPrimary; font.family: Quick.mono; font.pixelSize: 18; font.weight: Font.Medium }
            }
        }
    }
    QuickLabel { visible: q.top.length > 0; text: "Using the most" }
    QuickCard {
        visible: q.top.length > 0
        spacing: 6
        Repeater {
            model: q.top
            delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 10
                Text { Layout.fillWidth: true; text: modelData.name; color: Quick.theme.textSecondary; font.family: Quick.mono; font.pixelSize: 12; elide: Text.ElideRight }
                Text { text: modelData.cpu + "%"; color: Quick.theme.textPrimary; font.family: Quick.mono; font.pixelSize: 11 }
                Text { Layout.preferredWidth: 52; horizontalAlignment: Text.AlignRight; text: modelData.mem + "% mem"; color: Quick.theme.textMuted; font.family: Quick.mono; font.pixelSize: 11 }
            }
        }
    }
}
