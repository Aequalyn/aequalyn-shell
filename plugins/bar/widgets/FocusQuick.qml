// Focus's quick panel: a right click on the bar's focus widget. How long is left, a
// little more, or an end; and how long to focus next; last, Focus in Plugins.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/plugins/bar/quick"
import "root:/plugins/kit"

QuickPopup {
    id: q
    required property var bar
    readonly property var svc: KitHost.get("focus")
    readonly property bool on: !!svc && svc.on

    glyph: "\u{F0F6E}"
    title: "Focus"
    sub: !svc ? "Turned off" : on ? "Until " + Qt.formatTime(new Date(svc.until), "HH:mm") + " · messages wait" : "Do not disturb, for a while"
    settingsLabel: "Focus settings"
    onSettingsClicked: { q.dismissed(); KitHost.openSettings("focus") }

    QuickCard {
        visible: q.on
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: q.on ? q.svc.left + " min left" : ""
            color: Quick.theme.textPrimary
            font.family: Quick.mono
            font.pixelSize: 32
            font.weight: Font.Medium
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Messages that come meanwhile wait in the corner."
            color: Quick.theme.textMuted
            font.family: Quick.sans
            font.pixelSize: 11
        }
    }
    RowLayout {
        visible: q.on
        Layout.fillWidth: true
        spacing: 8
        QuickWide { label: "+15 min"; onClicked: q.svc.extend(15) }
        QuickWide { label: "+30 min"; onClicked: q.svc.extend(30) }
        QuickWide { glyph: "\u{F04DB}"; label: "End now"; onClicked: q.svc.end(false) }
    }

    QuickLabel { visible: !!q.svc; text: q.on ? "Start again, for" : "Focus for" }
    GridLayout {
        visible: !!q.svc
        Layout.fillWidth: true
        columns: 2
        columnSpacing: 8
        rowSpacing: 8
        Repeater {
            model: [25, 50, 90, 120]
            delegate: QuickWide {
                required property int modelData
                glyph: "\u{F0F6E}"
                label: modelData === 120 ? "2 hours" : modelData + " minutes"
                onClicked: q.svc.begin(modelData)
            }
        }
    }
}
