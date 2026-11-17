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
                      about: "Your own cursor, and trails and halos around the pointer." }
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
