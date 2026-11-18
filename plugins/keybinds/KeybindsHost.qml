// The link to the Keyboard shortcuts service (plugins/keybinds/Keybinds.qml,
// loaded by the PluginManager): the control center's page finds it here, and
// its own key opens the page. `svc` is null while the plugin is turned off.
pragma Singleton

import QtQuick
import Quickshell
import "root:/settings/center"

Singleton {
    id: root

    property var svc: null

    function openPage() { Cc.go("keybinds") }
}
