// Backup: your setup in one file, to keep or to bring to another computer.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/settings"
import ".."

CcPage {
    id: page
    title: "Backup"
    sub: "Keep your setup, or move it to another computer."
    readonly property var b: Cc.backup

    CcRow {
        icon: "\u{F0193}"
        title: "Save my setup"
        sub: "Settings, theme, bar, docks, layouts, pinned apps and the list of installed apps, in one file in your home folder."
        action: page.b && page.b.busy ? "Working…" : "Save"
        primary: true
        busy: page.b && page.b.busy
        onActivated: page.b.save()
    }
    CcRow {
        icon: "\u{F0552}"
        title: "Bring a setup back"
        sub: "From a file you saved before."
        action: "Choose a file"
        busy: page.b && page.b.busy
        onActivated: page.b.restore()
    }
    CcNote {
        visible: page.b && page.b.status !== ""
        text: page.b ? page.b.status : ""
        color: Cc.theme.accentGreen
    }
    CcNote {
        visible: page.b && page.b.lastFile !== ""
        text: "Last saved: " + (page.b ? page.b.lastFile : "")
    }
}
