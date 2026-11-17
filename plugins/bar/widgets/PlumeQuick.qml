// Plume's quick panel: the pointer's trails and halos on or off, its ready-made looks,
// and finding the pointer; last, the Cursor page in the control center.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/plugins/bar/quick"
import "root:/plugins/plume"
import "root:/plugins/plume/js/Schema.js" as Schema

QuickPopup {
    id: q
    required property var bar
    readonly property var svc: PlumeHost.svc
    readonly property bool on: !!svc && svc.cfg.enabled === true
    readonly property string look: svc ? Schema.lookNow(svc.current()) || "" : ""

    glyph: "\u{F01C0}"
    title: "Cursor"
    sub: !svc ? "Turned off" : on ? "Trails and halos follow the pointer" : "Just the pointer"
    settingsLabel: "Cursor settings"
    onSettingsClicked: { q.dismissed(); PlumeHost.openSettings() }

    GridLayout {
        visible: !!q.svc
        Layout.fillWidth: true
        columns: 2
        columnSpacing: 8
        rowSpacing: 8
        QuickTile {
            glyph: "\u{F01C0}"; title: "Pointer effects"
            sub: q.on ? "On" : "Off"
            on: q.on
            onToggled: q.svc.setSetting("enabled", !q.on)
        }
        QuickTile {
            glyph: "\u{F0349}"; title: "Find the pointer"
            sub: "Rings around it"
            onToggled: { q.dismissed(); q.svc.find() }
        }
    }
    QuickLabel { visible: !!q.svc; text: "Ready-made looks" }
    RowLayout {
        visible: !!q.svc
        Layout.fillWidth: true
        spacing: 8
        QuickRound { glyph: "\u{F0141}"; tip: "The look before"; onClicked: q.svc.stepLook(-1) }
        QuickWide {
            glyph: "\u{F0E09}"
            label: q.look !== "" && Schema.lookByKey[q.look] ? Schema.lookByKey[q.look].label : "Your own"
            onClicked: q.svc.stepLook(1)
        }
        QuickRound { glyph: "\u{F0142}"; tip: "The next look"; onClicked: q.svc.stepLook(1) }
    }
}
