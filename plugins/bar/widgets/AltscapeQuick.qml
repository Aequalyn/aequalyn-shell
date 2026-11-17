// Altscape's quick panel: open the window switcher, or pick how it lays out the
// windows; last, the Window switcher page in the control center.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/plugins/bar/quick"
import "root:/plugins/altscape"
import "root:/plugins/altscape/js/Schema.js" as Schema

QuickPopup {
    id: q
    required property var bar
    readonly property var svc: AltscapeHost.svc
    readonly property string mode: svc ? String(svc.cfg.mode) : ""
    readonly property var current: Schema.modes.find(m => m.key === q.mode) || null

    glyph: "\u{F05B1}"
    title: "Window switcher"
    sub: !svc ? "Turned off" : current ? current.label + " · Alt + Tab" : "Alt + Tab"
    settingsLabel: "Window switcher settings"
    onSettingsClicked: { q.dismissed(); AltscapeHost.openSettings("settings") }

    QuickWide {
        visible: !!q.svc
        glyph: "\u{F05B1}"
        label: "Show every window"
        onClicked: { q.dismissed(); q.svc.openSwitcher("open") }
    }
    QuickLabel { visible: !!q.svc; text: "How it lays them out" }
    GridLayout {
        visible: !!q.svc
        Layout.fillWidth: true
        columns: 3
        columnSpacing: 8
        rowSpacing: 8
        Repeater {
            model: Schema.modes
            delegate: QuickWide {
                required property var modelData
                label: modelData.label
                on: modelData.key === q.mode
                onClicked: q.svc.setMode(modelData.key)
            }
        }
    }
    Text {
        visible: !!q.current
        Layout.fillWidth: true
        text: q.current ? q.current.hint : ""
        color: Quick.theme.textMuted
        font.family: Quick.sans
        font.pixelSize: 11
        wrapMode: Text.WordWrap
    }
}
