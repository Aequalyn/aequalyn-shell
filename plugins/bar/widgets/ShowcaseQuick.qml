// Showcase's quick panel: the state of the desktop widgets, and the main actions.
import QtQuick
import QtQuick.Layouts
import "root:/plugins/bar/quick"
import "root:/plugins/kit"

QuickPopup {
    id: q
    required property var bar
    readonly property var svc: KitHost.get("showcase")
    readonly property var cfg: q.svc ? q.svc.cfg : null

    glyph: "\u{F0E6B}"
    title: "Showcase"
    sub: !q.svc ? "Turned off"
        : !q.cfg || !q.cfg.enabled ? "Hidden · your widgets are kept"
        : !q.cfg || q.cfg.widgets.length === 0 ? "No widgets yet"
        : q.cfg.widgets.length + (q.cfg.widgets.length === 1 ? " widget" : " widgets") + " on the desktop"
    settingsLabel: "Showcase settings"
    onSettingsClicked: { q.dismissed(); q.bar.openPage("showcase") }
    actions: [
        QuickRound { small: true; glyph: "\u{F040A}"; tip: "Arrange"; enabled: !!q.svc; onClicked: { q.dismissed(); q.svc.arrange(true) } },
        QuickRound { small: true; glyph: "\u{F03E4}"; tip: "Show or hide"; enabled: !!q.svc; onClicked: q.svc.setValue("enabled", !q.cfg.enabled) }
    ]

    QuickLabel { text: "Looks" }
    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: 8
        rowSpacing: 8
        Repeater {
            model: ["salon", "gazette", "glass", "bauhaus", "orbit", "neon"]
            delegate: QuickWide {
                required property string modelData
                label: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                on: q.cfg && q.cfg.lastLook === modelData
                enabled: !!q.svc
                onClicked: q.svc.applyPreset(modelData)
            }
        }
    }
    QuickWide {
        glyph: "\u{F0E6B}"; label: "Next look"
        enabled: !!q.svc
        onClicked: q.svc.nextLook()
    }
}
