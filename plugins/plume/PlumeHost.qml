// The link to Plume's service (Service.qml, loaded by the PluginManager): the bar
// button and the control center's Cursor page find it here, and either can open that
// page. `svc` is null while the plugin is turned off.
pragma Singleton

import QtQuick
import Quickshell
import "root:/settings/center"

Singleton {
    id: root
    property var svc: null

    function openSettings() { Cc.go("cursor"); }
}
