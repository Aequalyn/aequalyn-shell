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
    { id: "fm",             label: "Aequalyn FM (file manager)", source: "plugins/aequalynfm/Fm.qml" },
    { id: "keybinds",       label: "Keyboard shortcuts", source: "plugins/keybinds/Keybinds.qml" },
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
    { id: "weather",       label: "Weather",           source: "plugins/weather/Weather.qml" },
    { id: "netSpeed",      label: "Network speed",     source: "plugins/netSpeed/NetSpeed.qml" },
    { id: "nightLight",    label: "Night light",       source: "plugins/nightLight/NightLight.qml", sandbox: true },
    { id: "batteryGuard",  label: "Battery guard",     source: "plugins/batteryGuard/BatteryGuard.qml", sandbox: true },
    { id: "breaks",        label: "Break reminder",    source: "plugins/breaks/Breaks.qml", sandbox: true },
    { id: "diskWatch",     label: "Disk watch",        source: "plugins/diskWatch/DiskWatch.qml", sandbox: true },
    { id: "watchdogTest",  label: "Watchdog self-test", source: "plugins/watchdogTest/WatchdogTest.qml", sandbox: true },
    // the root gate's own demo: its command is pinned HERE (needsRoot), it
    // asks through the gate the moment it is on, and the window decides.
    { id: "rootTest",      label: "Root gate self-test", source: "plugins/rootTest/RootTest.qml", sandbox: true,
      needsRoot: [{ "id": "who-am-i", "label": "Show the user id it runs as", "about": "Runs /usr/bin/id -u as root; the answer should be 0.",
                    "command": ["/usr/bin/id", "-u"] }] },
    { id: "store",          label: "Store",          source: "plugins/store/Store.qml" },
    { id: "settings",       label: "Control center", source: "settings/ControlCenter.qml" }
];
