// Timer's quick panel: a right click on the bar's timer. The time, pause and stop, a
// few more minutes, and a new one to start; last, Timer in Plugins.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/plugins/bar/quick"
import "root:/plugins/kit"

QuickPopup {
    id: q
    required property var bar
    readonly property var svc: KitHost.get("timer")
    readonly property bool running: !!svc && svc.mode !== ""
    readonly property bool countdown: running && svc.mode !== "stopwatch"

    glyph: running && svc.mode === "rest" ? "\u{F0130}" : "\u{F051B}"
    title: running ? svc.modeName : "Timer"
    sub: !svc ? "Turned off" : !running ? "Nothing running"
        : svc.paused ? "Paused"
        : countdown ? "Ends at " + Qt.formatTime(new Date(svc.endsAt), "HH:mm") : "Counting up"
    settingsLabel: "Timer settings"
    onSettingsClicked: { q.dismissed(); KitHost.openSettings("timer") }
    function start(kind, minutes) { if (q.svc) q.svc.start(kind, minutes) }

    // ---- the time --------------------------------------------------------------------
    QuickCard {
        visible: q.running
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: q.running ? q.svc.label : ""
            color: q.svc && q.svc.paused ? Quick.theme.textMuted : Quick.theme.textPrimary
            font.family: Quick.mono
            font.pixelSize: 40
            font.weight: Font.Medium
        }
        Rectangle {
            visible: q.countdown
            Layout.fillWidth: true
            implicitHeight: 6
            radius: 3
            color: Quick.theme.bgSelected
            Rectangle {
                width: parent.width * (q.svc ? q.svc.progress : 0)
                height: parent.height
                radius: 3
                color: Quick.theme.accentPrimary
            }
        }
    }
    RowLayout {
        visible: q.running
        Layout.fillWidth: true
        spacing: 8
        QuickWide {
            glyph: q.svc && q.svc.paused ? "\u{F040A}" : "\u{F03E4}"
            label: q.svc && q.svc.paused ? "Go on" : "Pause"
            onClicked: q.svc.paused ? q.svc.resume() : q.svc.pause()
        }
        QuickWide { visible: q.countdown; label: "+1 min"; onClicked: q.svc.extend(1) }
        QuickWide { visible: q.countdown; label: "+5 min"; onClicked: q.svc.extend(5) }
        QuickWide { glyph: "\u{F04DB}"; label: "Stop"; onClicked: q.svc.stop() }
    }

    // ---- a new one -------------------------------------------------------------------
    QuickLabel { visible: !!q.svc; text: q.running ? "Start another" : "Start" }
    GridLayout {
        visible: !!q.svc
        Layout.fillWidth: true
        columns: 3
        columnSpacing: 8
        rowSpacing: 8
        Repeater {
            model: [5, 10, 15, 25, 30, 60]
            delegate: QuickWide {
                required property int modelData
                label: modelData === 60 ? "1 hour" : modelData + " min"
                on: q.svc && q.svc.mode === "timer" && q.svc.lengthMin === modelData
                onClicked: q.start("timer", modelData)
            }
        }
    }
    RowLayout {
        visible: !!q.svc
        Layout.fillWidth: true
        spacing: 8
        QuickWide {
            glyph: "\u{F0130}"; label: "Pomodoro"
            on: !!q.svc && (q.svc.mode === "work" || q.svc.mode === "rest")
            onClicked: q.start("work", 25)
        }
        QuickWide {
            glyph: "\u{F0954}"; label: "Stopwatch"
            on: !!q.svc && q.svc.mode === "stopwatch"
            onClicked: q.start("stopwatch", 0)
        }
        QuickRound {
            glyph: "\u{F03EB}"; tip: "Other minutes"
            onClicked: { q.dismissed(); q.svc.toggle() }
        }
    }
}
