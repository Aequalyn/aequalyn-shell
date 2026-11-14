.pragma library

// Single source of truth for the shell's plugins. PluginManager loads from
// this list and Settings -> Plugins renders toggles from it, so adding a
// plugin here keeps both in sync.
var list = [
    { id: "bar",            label: "Top bar",        source: "plugins/bar/Bar.qml" },
    { id: "appLauncher",    label: "App launcher",   source: "plugins/appLauncher/AppLauncher.qml" },
    { id: "notifications",  label: "Notifications",  source: "plugins/notifications/NotificationPopup.qml" },
    { id: "atelier",        label: "Atelier",       source: "plugins/atelier/Atelier.qml" },
    { id: "osd",            label: "On-screen display", source: "plugins/osd/OSD.qml" },
    { id: "monitorManager", label: "Monitor manager", source: "plugins/monitorManager/MonitorManager.qml" },
    { id: "idleInhibitor",  label: "Idle inhibitor", source: "plugins/idleInhibitor/CaffeineToggle.qml" },
    { id: "clipboard",      label: "Clipboard history", source: "plugins/clipboard/ClipboardPanel.qml" },
    { id: "powerMenu",      label: "Power menu",     source: "plugins/powerMenu/PowerMenu.qml" },
    { id: "docks",          label: "Docks",          source: "plugins/docks/DocksService.qml" },
    { id: "settings",       label: "Control center", source: "settings/ControlCenter.qml" }
];
