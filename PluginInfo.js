.pragma library

// What the control center says about each plugin (Plugins.js lists and loads them):
//   icon   a Nerd Font glyph
//   about  one line: what it does
//   group  "screen"      always on the desktop (the bar, docks, notifications...)
//          "key"         hidden until a key or a click calls it up
//          "background"  works out of sight
//   keys   the shortcuts that call it up, as shown on its card ("" for none)
//   page   its control center page (Pages.js), "" for none
// A plugin missing here still shows, with its label and a plain icon; adding a plugin
// is a line in Plugins.js and, for a proper card, one here. See PLUGINS.md.
var info = {
    bar:            { icon: "\u{F10AB}", group: "screen",     keys: "",                     page: "bar",
                      about: "The strip along the top: workspaces, clock, media and your widgets." },
    docks:          { icon: "\u{F10A9}", group: "screen",     keys: "",                     page: "dock",
                      about: "Your apps at the edges of the screen." },
    notifications:  { icon: "\u{F009A}", group: "screen",     keys: "Super + N",            page: "",
                      about: "Messages from apps, in the corner. Super + Shift + N: do not disturb." },
    osd:            { icon: "\u{F057E}", group: "screen",     keys: "",                     page: "",
                      about: "Shows the volume and brightness as they change." },
    media:          { icon: "\u{F075A}", group: "screen",     keys: "",                     page: "media",
                      about: "What is playing, on the bar: a live visualizer, the cover and the buttons." },
    appLauncher:    { icon: "\u{F003B}", group: "key",        keys: "Super + D",            page: "apps",
                      about: "Find and open apps." },
    programsMenu:   { icon: "\u{F035C}", group: "key",        keys: "Super + Space",        page: "",
                      about: "Every program, desktop and command line, by category." },
    defaultApps:    { icon: "\u{F0BE0}", group: "key",        keys: "Super + Alt + A",      page: "apps",
                      about: "Choose the apps that open your links, files and mail." },
    atelier:        { icon: "\u{F03D8}", group: "key",        keys: "Super + T · Super + W", page: "picker",
                      about: "The theme and wallpaper pickers, and the look pages here." },
    altscape:       { icon: "\u{F05B1}", group: "key",        keys: "Alt + Tab",            page: "switcher",
                      about: "Every window, in one of twelve layouts, with live previews." },
    clipboard:      { icon: "\u{F014F}", group: "key",        keys: "Super + Ctrl + V",     page: "",
                      about: "Everything you copied, text and images." },
    powerMenu:      { icon: "\u{F0425}", group: "key",        keys: "Super + Shift + M",    page: "sleep",
                      about: "Lock, log out, restart, shut down." },
    monitorManager: { icon: "\u{F0379}", group: "key",        keys: "Super + O",            page: "screens",
                      about: "The screen map: arrange, scale and turn screens on and off." },
    idleInhibitor:  { icon: "\u{F0176}", group: "background", keys: "Super + Shift + C",    page: "sleep",
                      about: "Keeps the screen awake while it is on." },
    plume:          { icon: "\u{F01C0}", group: "background", keys: "",                     page: "cursor",
                      about: "Your own cursor, and trails and halos around the pointer." },
    // ---- the built-in pack ----
    calculator:     { icon: "\u{F00EC}", group: "key",        keys: "Super + =",            page: "",
                      about: "Type a sum, see the answer as you type; Enter copies it." },
    colorPicker:    { icon: "\u{F0266}", group: "key",        keys: "Super + Shift + P",    page: "",
                      about: "Click any pixel on the screen; its colour is copied as #rrggbb." },
    emoji:          { icon: "\u{F0785}", group: "key",        keys: "Super + .",            page: "",
                      about: "Find an emoji by name; Enter copies it." },
    notes:          { icon: "\u{F0219}", group: "key",        keys: "Super + Alt + N",      page: "",
                      about: "One page to jot things down, saved as you type to ~/Documents/Notes.md." },
    keyHints:       { icon: "\u{F030C}", group: "key",        keys: "Super + /",            page: "",
                      about: "Every key binding, searchable: what to press and what it does." },
    palette:        { icon: "\u{F0349}", group: "key",        keys: "Super + Shift + Space", page: "",
                      about: "Every setting, plugin and action in one search." },
    sysmon:         { icon: "\u{F0EE0}", group: "key",        keys: "Super + Shift + Esc",  page: "",
                      about: "How busy the computer is, and what uses the most." },
    screenText:     { icon: "\u{F0E40}", group: "key",        keys: "Super + Alt + X",      page: "",
                      about: "Box any text on the screen and it is copied as text. Needs tesseract." },
    timer:          { icon: "\u{F051B}", group: "key",        keys: "Super + Alt + T",      page: "",
                      about: "A countdown, a pomodoro or a stopwatch, shown on the bar while it runs." },
    focus:          { icon: "\u{F0F6E}", group: "key",        keys: "Super + Alt + F",      page: "",
                      about: "Do not disturb for a while, with a message when the time is up." },
    weather:        { icon: "\u{F0599}", group: "screen",     keys: "",                     page: ""     ,
                      about: "The weather where you are, on the bar, and the next days." },
    netSpeed:       { icon: "\u{F06F3}", group: "screen",     keys: "",                     page: "",
                      about: "How fast things come in and go out, on the bar." },
    nightLight:     { icon: "\u{F0594}", group: "background", keys: "",                     page: ""     ,
                      about: "Warmer colours in the evening, on a schedule or by hand." },
    batteryGuard:   { icon: "\u{F0083}", group: "background", keys: "",                     page: ""     ,
                      about: "A message when the battery runs low, nearly empty, or is full." },
    breaks:         { icon: "\u{F0208}", group: "background", keys: "",                     page: ""     ,
                      about: "Every 20 minutes, a reminder to rest your eyes." },
    diskWatch:      { icon: "\u{F02CA}", group: "background", keys: "",                     page: ""     ,
                      about: "A message when a disk is nearly full." }
};

var groups = [
    { key: "screen",     title: "On screen",          hint: "Always on the desktop." },
    { key: "key",        title: "Opened with a key",  hint: "Hidden until you call them up." },
    { key: "background", title: "In the background",  hint: "Working out of sight." }
];

function of(id) {
    return Object.prototype.hasOwnProperty.call(info, id) ? info[id]
        : { icon: "\u{F0431}", group: "background", keys: "", page: "", about: "" };
}
