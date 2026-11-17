// The calendar's quick panel (the clock and calendar widgets): the month, a day's
// distance from today when you point at it, and back to today; last, the Clock page.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/plugins/bar/quick"

QuickPopup {
    id: q
    required property var bar
    property date shown: new Date()
    onOpenChanged: if (open) q.shown = new Date()
    property date now: new Date()
    Timer { interval: 30000; repeat: true; running: q.visible; triggeredOnStart: true; onTriggered: q.now = new Date() }
    function step(m) { q.shown = new Date(q.shown.getFullYear(), q.shown.getMonth() + m, 1) }
    readonly property bool onToday: q.shown.getFullYear() === q.now.getFullYear() && q.shown.getMonth() === q.now.getMonth()

    glyph: "\u{F00ED}"
    title: Qt.formatDate(q.now, "dddd d MMMM")
    sub: "Week " + weekOf(q.now)
    settingsLabel: "Clock settings"
    onSettingsClicked: { q.dismissed(); q.bar.openPage("clock") }
    function weekOf(d) {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        const day = t.getUTCDay() || 7;
        t.setUTCDate(t.getUTCDate() + 4 - day);
        return Math.ceil(((t - new Date(Date.UTC(t.getUTCFullYear(), 0, 1))) / 86400000 + 1) / 7);
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        QuickRound { small: true; glyph: "\u{F0141}"; tip: "The month before"; onClicked: q.step(-1) }
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: Qt.formatDate(q.shown, "MMMM yyyy")
            color: Quick.theme.textPrimary
            font.family: Quick.mono
            font.pixelSize: 13
            font.bold: true
        }
        QuickRound { small: true; glyph: "\u{F0142}"; tip: "The month after"; onClicked: q.step(1) }
    }
    GridLayout {
        Layout.fillWidth: true
        columns: 7
        columnSpacing: 2
        rowSpacing: 2
        Repeater {
            model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
            delegate: Text {
                required property string modelData
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                color: Quick.theme.textMuted
                font.family: Quick.mono
                font.pixelSize: 10
            }
        }
        Repeater {
            model: 42
            delegate: Rectangle {
                id: cell
                required property int index
                readonly property int offset: (new Date(q.shown.getFullYear(), q.shown.getMonth(), 1).getDay() + 6) % 7
                readonly property date day: new Date(q.shown.getFullYear(), q.shown.getMonth(), index - offset + 1)
                readonly property bool inMonth: day.getMonth() === q.shown.getMonth()
                readonly property bool today: day.toDateString() === q.now.toDateString()
                Layout.fillWidth: true
                implicitHeight: 34
                radius: 8
                color: today ? Quick.theme.bgSelected : cellArea.containsMouse ? Quick.theme.bgHover : "transparent"
                border.width: today ? 1 : 0
                border.color: Quick.theme.accentPrimary
                Text {
                    anchors.centerIn: parent
                    text: cell.day.getDate()
                    color: cell.today ? Quick.theme.accentPrimary : cell.inMonth ? Quick.theme.textPrimary : Quick.theme.textMuted
                    opacity: cell.inMonth ? 1 : 0.45
                    font.family: Quick.mono
                    font.pixelSize: 12
                    font.bold: cell.today
                }
                MouseArea { id: cellArea; anchors.fill: parent; hoverEnabled: true }
            }
        }
    }
    QuickWide {
        visible: !q.onToday
        glyph: "\u{F00F6}"
        label: "Back to today"
        onClicked: q.shown = new Date()
    }
}
