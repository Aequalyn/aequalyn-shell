// Atelier's quick panel (the Themes or Layouts button, on the click you chose for it):
// the theme and wallpaper pickers, another wallpaper at once, and the window layout of
// this workspace; last, the Theme picker page in the control center.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/plugins/bar/quick"
import "root:/plugins/atelier"

QuickPopup {
    id: q
    required property var bar
    readonly property var layout: LayoutService.find(LayoutService.layoutOf(LayoutService.focusedWorkspace))
    function ipc(args) { q.dismissed(); Quickshell.execDetached(["qs", "ipc", "call"].concat(args)) }

    glyph: "\u{F03D8}"
    title: "Themes and wallpapers"
    sub: q.bar.theme && q.bar.theme.wallpaperMode ? "Colours from the wallpaper"
        : q.bar.theme && q.bar.theme.committed ? q.bar.theme.committed.name : ""
    settingsLabel: "Theme picker settings"
    onSettingsClicked: { q.dismissed(); q.bar.openPage("picker") }

    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: 8
        rowSpacing: 8
        QuickTile { glyph: "\u{F03D8}"; title: "Themes"; sub: "Super + T"; onToggled: q.ipc(["atelier", "open", "themes"]) }
        QuickTile { glyph: "\u{F0E09}"; title: "Wallpapers"; sub: "Super + W"; onToggled: q.ipc(["atelier", "open", "wallpapers"]) }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        QuickWide { glyph: "\u{F04AD}"; label: "Next wallpaper"; onClicked: AtelierHost.act("next-wallpaper") }
        QuickWide { glyph: "\u{F049D}"; label: "Any wallpaper"; onClicked: AtelierHost.act("random-wallpaper") }
    }
    QuickLabel { text: "Windows on this workspace" }
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        QuickRound { glyph: "\u{F0141}"; tip: "The layout before"; onClicked: AtelierHost.act("prev-layout") }
        QuickWide {
            glyph: "\u{F0570}"
            label: q.layout ? q.layout.name : "Layout"
            onClicked: { q.dismissed(); q.bar.openPage("arrange") }
        }
        QuickRound { glyph: "\u{F0142}"; tip: "The next layout"; onClicked: AtelierHost.act("next-layout") }
    }
}
