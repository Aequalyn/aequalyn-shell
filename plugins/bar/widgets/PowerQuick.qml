// The power button's quick panel: lock, sleep, log out, restart, shut down (the last
// three ask for a second click), and the power profile; last, the Lock and sleep page.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "root:/plugins/bar/quick"

QuickPopup {
    id: q
    required property var bar

    // log out, restart and shut down: a second click within four seconds does it
    property string armed: ""
    Timer { id: disarm; interval: 4000; onTriggered: q.armed = "" }
    onVisibleChanged: if (!visible) q.armed = ""
    function act(key, cmd, ask) {
        if (ask && q.armed !== key) { q.armed = key; disarm.restart(); return }
        q.armed = "";
        q.dismissed();
        Quickshell.execDetached(cmd);
    }

    property string uptime: ""
    property string profile: ""
    Process {
        id: info
        command: ["sh", "-c", "uptime -p 2>/dev/null; powerprofilesctl get 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n");
                q.uptime = (l[0] || "").replace(/^up /, "");
                q.profile = (l[1] || "").trim();
            }
        }
    }
    onOpenChanged: if (open) info.running = true
    function setProfile(p) {
        q.profile = p;
        Quickshell.execDetached(["powerprofilesctl", "set", p]);
    }

    glyph: "\u{F0425}"
    title: "Power"
    sub: q.uptime !== "" ? "Up for " + q.uptime : ""
    settingsLabel: "Lock and sleep settings"
    onSettingsClicked: { q.dismissed(); q.bar.openPage("sleep") }

    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: 8
        rowSpacing: 8
        QuickTile { glyph: "\u{F033E}"; title: "Lock"; sub: "The lock screen"; onToggled: q.act("lock", ["loginctl", "lock-session"], false) }
        QuickTile { glyph: "\u{F04B2}"; title: "Sleep"; sub: "Lock, then sleep"; onToggled: q.act("sleep", ["systemctl", "suspend"], false) }
        QuickTile {
            glyph: "\u{F0343}"; title: "Log out"
            sub: q.armed === "logout" ? "Click again to log out" : "Close every app"
            on: q.armed === "logout"
            onToggled: q.act("logout", ["hyprctl", "dispatch", "hl.dsp.exit()"], true)
        }
        QuickTile {
            glyph: "\u{F0709}"; title: "Restart"
            sub: q.armed === "reboot" ? "Click again to restart" : "Start again"
            on: q.armed === "reboot"
            onToggled: q.act("reboot", ["systemctl", "reboot"], true)
        }
    }
    QuickWide {
        glyph: "\u{F0425}"
        label: q.armed === "poweroff" ? "Click again to shut down" : "Shut down"
        on: q.armed === "poweroff"
        onClicked: q.act("poweroff", ["systemctl", "poweroff"], true)
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
