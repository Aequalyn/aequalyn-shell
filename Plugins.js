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
    { id: "store",          label: "Store",          source: "plugins/store/Store.qml",
      // the Store's package rides the same gate as any plugin's: the
      // approval window names the command, pacman runs with the staged
      // ids (validated, --noconfirm, full argv, no shell)
      needsRoot: [
        { "id": "pkg-install", "label": "Install Arch packages", "about": "Installs the staged package names with pacman (--needed --noconfirm).", "command": ["/usr/local/bin/aequalyn-store", "gate-pkg"] },
        { "id": "pkg-remove", "label": "Remove Arch packages", "about": "Removes the staged package names with pacman (-Rns --noconfirm).", "command": ["/usr/local/bin/aequalyn-store", "gate-pkg"] }
      ] },
    // the control center's own privileged actions: every one of them rides
    // the same gate as any plugin's (exec-root --as settings <action>), so
    // the approval window is the only password prompt the desktop ever
    // shows. The commands are pinned here, as plain JSON.
    { id: "settings",       label: "Control center", source: "settings/ControlCenter.qml",
      needsRoot: [
        { "id": "browser-theme-publish", "label": "Publish the bar's colour to the browsers",
          "about": "Writes the bar's base colour as the managed policy of every installed Chromium-based browser (their frame colour), in /etc.",
          "command": ["/usr/local/bin/aequalyn-browser-theme", "gate-publish"] },
        { "id": "browser-theme-clear", "label": "Remove the browsers' colour policy",
          "about": "Removes the colour.json managed-policy file from every browser.",
          "command": ["/usr/local/bin/aequalyn-browser-theme", "gate-clear"] },
        { "id": "sddm-install", "label": "Install the login screen theme pack",
          "about": "Installs the lock-screen themes and their fonts into /usr/share/sddm/themes.",
          "command": ["/usr/local/bin/aequalyn-sddm", "gate-install"] },
        { "id": "sddm-apply", "label": "Set the login screen theme",
          "about": "Writes which theme SDDM shows at the login screen.",
          "command": ["/usr/local/bin/aequalyn-sddm", "gate-apply"] },
        { "id": "sddm-autologin", "label": "Turn autologin on or off",
          "about": "Writes or removes the SDDM autologin configuration (boots straight into the session, no greeter).",
          "command": ["/usr/local/bin/aequalyn-sddm", "gate-autologin"] },
        { "id": "install-aequalyn", "label": "Run the Aequalyn installer",
          "about": "Starts the install wizard (its Quickshell GUI) as root, on this session's Wayland. The live ISO's 'Install Aequalyn' launcher.",
          "command": ["/usr/local/bin/aequalyn-install", "--gate"] }
      ] }
];
