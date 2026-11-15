// The link to Altscape's service (Altscape.qml, loaded by the PluginManager): the bar
// button and the control center's Window switcher page find it here, and either can
// open that page on a tab ("visualisers" or "settings"). `svc` is null while the plugin
// is turned off.
pragma Singleton

import QtQuick
import Quickshell
import "root:/settings/center"

Singleton {
    id: root
    property var svc: null

    function openSettings(tab) {
        if (root.svc && root.svc.ui && tab) root.svc.ui.tabName = tab;
        Cc.go("switcher");
    }
}
