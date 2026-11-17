// Brightness's quick panel: how bright the screen is, and the night light when its
// plugin is on; last, the Screens page.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/settings"
import "root:/plugins/bar/quick"
import "root:/plugins/kit"

QuickPopup {
    id: q
    required property var bar
    readonly property bool nightOn: (AequalynSettings.enabledPlugins || []).indexOf("nightLight") >= 0
    readonly property var night: KitHost.get("nightLight")
    readonly property string nightMode: night ? night.mode : ""

    glyph: "\u{F00E0}"
    title: "Brightness"
    sub: q.bar.hasBacklight ? Math.round(q.bar.brightnessValue * 100) + "%" : "This screen sets its own"
    settingsLabel: "Screens settings"
    onSettingsClicked: { q.dismissed(); q.bar.openPage("screens") }

    QuickLevel {
        visible: q.bar.hasBacklight
        glyph: "\u{F00E0}"
        tip: "Brightness"
        value: q.bar.brightnessValue
        onMoved: v => q.bar.setBrightness(Math.max(1, Math.round(v * 100)))
    }
    RowLayout {
        visible: q.bar.hasBacklight
        Layout.fillWidth: true
        spacing: 8
        Repeater {
            model: [10, 40, 70, 100]
            delegate: QuickWide {
                required property int modelData
                label: modelData + "%"
                on: Math.round(q.bar.brightnessValue * 100) === modelData
                onClicked: q.bar.setBrightness(modelData)
            }
        }
    }
    QuickLabel { visible: q.nightOn; text: "Night light" }
    RowLayout {
        visible: q.nightOn
        Layout.fillWidth: true
        spacing: 8
        QuickWide { glyph: "\u{F0594}"; label: "On"; on: q.nightMode === "on"; onClicked: Quickshell.execDetached(["qs", "ipc", "call", "nightLight", "on"]) }
        QuickWide { label: "Off"; on: q.nightMode === "off"; onClicked: Quickshell.execDetached(["qs", "ipc", "call", "nightLight", "off"]) }
        QuickWide { glyph: "\u{F0954}"; label: "Schedule"; on: q.nightMode === "schedule"; onClicked: Quickshell.execDetached(["qs", "ipc", "call", "nightLight", "schedule"]) }
    }
}
