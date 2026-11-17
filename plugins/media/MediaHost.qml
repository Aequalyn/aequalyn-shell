// The link to Media's one shell-wide service (qml/Service.qml, loaded by the
// PluginManager): the bar's media widget and the control center's Media page find it
// here, and either can open that page. `svc` is null while the plugin is turned off.
pragma Singleton

import QtQuick
import Quickshell
import "root:/settings/center"

Singleton {
    id: root
    property var svc: null

    function openSettings() { Cc.go("media") }
}
