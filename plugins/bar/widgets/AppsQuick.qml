// The apps button's quick panel: every way to find and open an app, and the apps that
// open your links and files; last, the Apps page in the control center.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/settings"
import "root:/plugins/bar/quick"

QuickPopup {
    id: q
    required property var bar
    function on(id) { return (AequalynSettings.enabledPlugins || []).indexOf(id) >= 0 }
    function ipc(args) { q.dismissed(); Quickshell.execDetached(["qs", "ipc", "call"].concat(args)) }
    function page(name) { q.dismissed(); q.bar.openPage(name) }

    glyph: "\u{F003B}"
    title: "Apps"
    sub: "Super + D finds one by name"
    settingsLabel: "Apps settings"
    onSettingsClicked: q.page("apps")

    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: 8
        rowSpacing: 8
        QuickTile { glyph: "\u{F0349}"; title: "Find an app"; sub: "Super + D"; onToggled: { q.dismissed(); q.bar.openLauncher() } }
        QuickTile {
            glyph: "\u{F035C}"; title: "By category"; sub: "Super + Space"
            enabled: q.on("programsMenu")
            onToggled: q.ipc(["programs", "toggle"])
        }
        QuickTile {
            glyph: "\u{F0BE0}"; title: "Default apps"; sub: "Links, files and mail"
            enabled: q.on("defaultApps")
            onToggled: q.ipc(["defaults", "toggle"])
        }
        QuickTile { glyph: "\u{F0595}"; title: "Web apps"; sub: "Sites as apps"; onToggled: q.page("webapps") }
    }
    QuickWide { glyph: "\u{F034A}"; label: "Get more apps"; onClicked: q.page("store") }
}
