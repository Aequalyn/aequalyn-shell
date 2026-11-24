// Keep awake's quick panel: nothing locks or sleeps while it is on, for good or for a
// while; last, the Lock and sleep page in the control center.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/plugins/bar/quick"
import "root:/plugins/idleInhibitor"

QuickPopup {
    id: q
    required property var bar
    readonly property bool on: CaffeineService.active

    glyph: "\u{F0176}"
    title: "Keep awake"
    sub: !on ? "The screen locks and sleeps as set"
        : CaffeineService.until > 0 ? "Until " + Qt.formatTime(new Date(CaffeineService.until), "HH:mm") + " · " + CaffeineService.minutesLeft + " min left"
        : "Nothing locks or sleeps"
    settingsLabel: "Lock and sleep settings"
    onSettingsClicked: { q.dismissed(); q.bar.openPage("sleep") }

    QuickTile {
        glyph: "\u{F0176}"; title: "Keep awake"
        sub: q.on ? (CaffeineService.until > 0 ? "For a while" : "Until you turn it off") : "Off"
        on: q.on
        onToggled: CaffeineService.toggle()
    }
    QuickLabel { text: "For a while" }
    GridLayout {
        Layout.fillWidth: true
        columns: 4
        columnSpacing: 8
        rowSpacing: 8
        Repeater {
            model: [30, 60, 120, 240]
            delegate: QuickWide {
                required property int modelData
                label: modelData < 60 ? modelData + " min" : modelData / 60 + " h"
                onClicked: CaffeineService.enableFor(modelData)
            }
        }
    }
    QuickWide {
        glyph: "\u{F033E}"; label: "Lock now"
        onClicked: { q.dismissed(); Quickshell.execDetached(["aequalyn-lock", "lock"]) }
    }
}
