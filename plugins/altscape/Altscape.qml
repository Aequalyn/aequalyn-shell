// Altscape, the Alt + Tab window switcher (twelve layouts, live previews, effects).
// The plugin's entry (Plugins.js): its service (Service.qml: windows, settings, the
// keybind, ipc) and the switcher itself (Switcher.qml), which the service opens. The
// control center's Window switcher page and the bar button reach the service through
// AltscapeHost.
import QtQuick
import Quickshell

Item {
    id: root
    property var theme: null

    Service {
        id: svc
        theme: root.theme
        overlay: sw
    }
    Switcher {
        id: sw
        service: svc
    }

    Component.onCompleted: AltscapeHost.svc = svc
    Component.onDestruction: if (AltscapeHost.svc === svc) AltscapeHost.svc = null
}
