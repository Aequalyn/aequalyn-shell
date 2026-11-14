// Plugins: the parts of the desktop, each on or off.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/settings"
import "../../../Plugins.js" as PluginRegistry
import ".."

CcPage {
    id: page
    title: "Plugins"
    sub: "The parts of your desktop. Turn off what you don't use; it comes back when you turn it on."

    readonly property var about: ({
        bar: "The strip along the top.",
        appLauncher: "Super + D: find and open apps.",
        notifications: "Messages from apps, in the corner.",
        atelier: "Themes, wallpapers and window layouts.",
        osd: "Shows the volume and brightness as they change.",
        monitorManager: "The screen map, Super + O.",
        idleInhibitor: "Keep awake.",
        clipboard: "Super + Ctrl + V: everything you copied.",
        powerMenu: "Lock, log out, restart, shut down.",
        docks: "Your apps at the edges of the screen."
    })

    CcSection {
        hint: "A change takes effect the next time the shell starts."
        Repeater {
            // this window itself is a plugin too, but turning it off here would lock you out
            model: PluginRegistry.list.filter(p => p.id !== "settings")
            delegate: CcToggle {
                required property var modelData
                title: modelData.label
                sub: page.about[modelData.id] || ""
                checked: AequalynSettings.enabledPlugins.indexOf(modelData.id) >= 0
                onToggled: v => AequalynSettings.togglePlugin(modelData.id, v)
            }
        }
    }
    CcNote {
        text: "Make your own: a plugin is a folder with a QML file, added to Plugins.js in the shell's folder. plugins.md there explains how."
    }
}
