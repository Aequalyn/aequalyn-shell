.pragma library

// Single source of truth for the shell's plugins. PluginManager loads from
// this list and Settings -> Plugins renders toggles from it, so adding a
// plugin here keeps both in sync.
var list = [
    { id: "bar",            label: "Top bar",        source: "plugins/bar/Bar.qml" },
    { id: "appLauncher",    label: "App launcher",   source: "plugins/appLauncher/AppLauncher.qml" },
    { id: "defaultApps",    label: "Default apps launcher", source: "plugins/defaultApps/DefaultApps.qml" },
    { id: "programsMenu",   label: "Programs menu",  source: "plugins/programsMenu/ProgramsMenu.qml" },
    { id: "notifications",  label: "Notifications",  source: "plugins/notifications/NotificationPopup.qml" },
    { id: "atelier",        label: "Themes and wallpapers", source: "plugins/atelier/Atelier.qml" },
    { id: "osd",            label: "On-screen display", source: "plugins/osd/OSD.qml" },
    { id: "monitorManager", label: "Monitor manager", source: "plugins/monitorManager/MonitorManager.qml" },
    { id: "idleInhibitor",  label: "Idle inhibitor", source: "plugins/idleInhibitor/CaffeineToggle.qml" },
    { id: "clipscape",      label: "Clipscape clipboard", source: "plugins/clipscape/Clipscape.qml" },
    { id: "powerMenu",      label: "Power menu",     source: "plugins/powerMenu/PowerMenu.qml" },
    { id: "docks",          label: "Docks",          source: "plugins/docks/DocksService.qml" },
    { id: "plume",          label: "Cursor and pointer effects", source: "plugins/plume/Service.qml" },
    { id: "altscape",       label: "Window switcher", source: "plugins/altscape/Altscape.qml" },
    { id: "media",          label: "Media",          source: "plugins/media/qml/Service.qml" },
    // the built-in pack: off until you turn them on (Plugins), each its own folder
    { id: "calculator",    label: "Calculator",        source: "plugins/calculator/Calculator.qml" },
    { id: "colorPicker",   label: "Color picker",      source: "plugins/colorPicker/ColorPicker.qml" },
    { id: "emoji",         label: "Emoji",             source: "plugins/emoji/Emoji.qml" },
    { id: "notes",         label: "Quick notes",       source: "plugins/notes/Notes.qml" },
    { id: "keyHints",      label: "Key hints",         source: "plugins/keyHints/KeyHints.qml" },
    { id: "palette",       label: "Command palette",   source: "plugins/palette/Palette.qml" },
    { id: "sysmon",        label: "System monitor",    source: "plugins/sysmon/SystemMonitor.qml" },
    { id: "screenText",    label: "Screen text",       source: "plugins/screenText/ScreenText.qml" },
    { id: "timer",         label: "Timer",             source: "plugins/timer/Timer.qml" },
    { id: "focus",         label: "Focus",             source: "plugins/focus/Focus.qml" },
    { id: "settings",       label: "Control center", source: "settings/ControlCenter.qml" }
];
