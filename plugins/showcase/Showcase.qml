// Showcase plugin entry for Aequalyn: the service singleton owns the desktop
// widgets, settings and IPC; this component keeps it loaded as a plugin.
import QtQuick
import "root:/plugins/showcase"

Item {
    id: root
    property var theme: null
    // Keep the singleton reachable from the plugin host.
    readonly property var svc: ShowcaseService
    visible: false
}
