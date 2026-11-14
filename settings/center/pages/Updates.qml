// Updates: whether GitHub has a newer Aequalyn, and the update itself.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/settings"
import ".."

CcPage {
    id: page
    title: "Updates"
    sub: "New Aequalyn arrives here as soon as it is published."
    readonly property var u: Cc.updates
    readonly property bool ready: u && u.state === "behind"
    Component.onCompleted: if (u) u.refresh()

    CcRow {
        icon: page.ready ? "\u{F06B0}" : page.u && page.u.state === "same" ? "\u{F012C}" : "\u{F0450}"
        highlight: page.ready
        title: page.u ? page.u.status : ""
        sub: page.u ? "System " + (page.u.systemCommit || "…") + "  ·  shell " + (page.u.shellCommit || "…")
            + (page.u.systemDate !== "" ? "  ·  from " + page.u.systemDate.slice(0, 10) : "") : ""
        busy: page.u && (page.u.state === "checking" || page.u.state === "running")
        action: page.ready ? "Update now" : "Check now"
        primary: page.ready
        action2: page.ready ? "Check again" : ""
        onActivated: page.ready ? page.u.update() : page.u.check()
        onActivated2: page.u.check()
    }
    CcButton {
        visible: !page.ready
        text: "Update anyway"
        onClicked: page.u.update()
    }
    CcNote {
        text: "Updating opens a terminal that asks for your password, gets the newest Aequalyn and its shell, puts your settings back in place and restarts the shell. Your settings, themes and wallpapers stay as they are."
    }
}
