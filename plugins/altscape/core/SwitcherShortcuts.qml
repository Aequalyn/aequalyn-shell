import QtQuick
import Quickshell.Hyprland

// Keep shortcut events on one Wayland connection, in key-event order.
// Separate exec/IPC clients can deliver a quick release before its Tab press.
Item {
    id: root

    visible: false
    property string appid: "io.github.qempexe.altscape"
    signal triggered(string action)

    GlobalShortcut {
        appid: root.appid
        name: "next"
        description: "Window switcher: next window"
        onPressed: root.triggered("next")
    }
    GlobalShortcut {
        appid: root.appid
        name: "prev"
        description: "Window switcher: previous window"
        onPressed: root.triggered("prev")
    }
    GlobalShortcut {
        appid: root.appid
        name: "release"
        description: "Window switcher: switch on modifier release"
        onReleased: root.triggered("release")
    }
}
