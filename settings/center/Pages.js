.pragma library
.import "SettingsIndex.js" as Index

// Every page of the control center, in the order of the sidebar. `words` are the
// settings on the page, shown as search results; `also` are other words people may
// type for it. A plugin's page will be added here from its plugin.json.
//
// Pages with live pictures are kept once made (on their first visit), so they show at
// once after that; the rest are made when shown and dropped when left, so their scans
// and timers only run while you look at them.
// Six categories, each a few pages: the window lists the categories, then the pages
// of the one chosen (two levels, so neither list ever grows long). Home stands apart.
// (Apps -- default apps, web apps, packages, AI tools -- live in the Store, not here.)
var categories = [
    { key: "look",    title: "Look",    icon: "\u{F03D8}", pages: ["wallpaper", "theme", "picker", "cursor", "lockscreens"] },
    { key: "desktop", title: "Desktop", icon: "\u{F10AB}", pages: ["bar", "dock", "media", "clipboard"] },
    { key: "windows", title: "Windows", icon: "\u{F05AF}", pages: ["arrange", "windows", "switcher"] },
    { key: "devices", title: "Devices", icon: "\u{F0379}", pages: ["screens", "sound", "input", "keybinds", "bluetooth", "wifi"] },
    { key: "system",  title: "System",  icon: "\u{F0493}", pages: ["sleep", "clock", "plugins", "updates", "backup", "about"] }
];
// the same, as the flat groups other parts of the shell read
var groups = [{ title: "", pages: ["home"] }].concat(categories.map(function (c) { return { title: c.title, pages: c.pages }; }));
// the category a page is in, "" for Home
function categoryOf(page) {
    for (var i = 0; i < categories.length; i++) if (categories[i].pages.indexOf(page) >= 0) return categories[i].key;
    return "";
}
function category(key) {
    for (var i = 0; i < categories.length; i++) if (categories[i].key === key) return categories[i];
    return null;
}

var pages = {
    home:      { label: "Home", icon: "\u{F02DC}", file: "Home",
                 words: [], also: "start overview desktop" },
    wallpaper: { label: "Wallpaper", icon: "\u{F0E09}", file: "Wallpaper",
                 words: ["Choose a wallpaper", "Next wallpaper", "Wallpaper picker", "Slideshow", "Wallpaper by time of day", "One wallpaper per workspace", "Moving wallpapers"],
                 also: "background picture image rotation video live" },
    theme:     { label: "Theme", icon: "\u{F03D8}", file: "Theme",
                 words: ["Choose a theme", "Wallpaper colours", "Colours follow the wallpaper", "A theme brings its wallpapers", "Apps use these colours", "Colour scheme", "Light or dark", "Add your own theme"],
                 also: "color colours palette matugen gtk dark light accent look super t" },
    bar:       { label: "Bar", icon: "\u{F10AB}", file: "Bar",
                 words: ["Bar shape", "Bar look", "Bar height", "Bar see-through", "Widgets on the bar", "Hide a widget", "Bar and docks together"],
                 also: "top panel taskbar widgets opacity size pills islands pebbles" },
    dock:      { label: "Dock", icon: "\u{F10A9}", file: "Dock",
                 words: ["Add a dock", "Dock position", "Hide the dock", "Dock icons", "Dock look"],
                 also: "launcher pinned apps taskbar autohide" },
    picker:    { label: "Theme picker", icon: "\u{F08B5}", file: "Picker",
                 words: ["Picker type", "Slices", "Picker shape", "Picker position", "Picker size"],
                 also: "switcher showcase carousel grid slices super t super w atelier" },
    lockscreens: { label: "Login screen", icon: "\u{F0343}", file: "LockScreens",
                 words: ["SDDM theme", "Login screen theme", "Autologin", "Login screen preview"],
                 also: "sddm greeter login sign in autologin preview boot lock screens" },
    arrange:   { label: "Arranging windows", icon: "\u{F0570}", file: "Arrange",
                 words: ["Window layout", "Layouts in Super + L", "Built-in arrangement"],
                 also: "tiling layout master dwindle scrolling grid focus" },
    windows:   { label: "Window look", icon: "\u{F05AF}", file: "Windows",
                 words: ["Space between windows", "Rounded corners", "Window border", "Blur", "Animations", "See-through windows",
                         "Behind panels", "Blur behind panels", "Smooth blur", "Frost", "Maelstrom", "Darkness", "Colour of the blur"],
                 also: "gaps rounding border opacity transparency effects hyprland backdrop dim zoom iris mosaic swirl" },
    switcher:  { label: "Window switcher", icon: "\u{F05B1}", file: "WindowSwitcher",
                 words: ["Alt + Tab", "Switch windows", "Switcher layout", "Window previews", "Switcher backdrop", "Switcher effects"],
                 also: "altscape alt tab switcher overview expose mission control previews carousel ring grid" },
    cursor:    { label: "Cursor", icon: "\u{F01C0}", file: "Cursor",
                 words: ["Design your own cursor", "Cursor theme", "Cursor size", "Pointer trail", "Halo", "Shake to find the pointer", "Hide the cursor", "Cursor looks"],
                 also: "plume pointer mouse arrow trail halo glow comet sparks ring spotlight crosshair hyprcursor xcursor" },
    screens:   { label: "Screens", icon: "\u{F0379}", file: "Screens",
                 words: ["Brightness", "Arrange screens", "Resolution", "Scale"],
                 also: "monitor display displays brightness resolution refresh" },
    input:     { label: "Keyboard and mouse", icon: "\u{F030C}", file: "Input",
                 words: ["Keyboard layout", "Natural scrolling"],
                 also: "keyboard touchpad mouse scroll language" },
    keybinds:  { label: "Keyboard shortcuts", icon: "\u{F030C}", file: "Keybinds",
                 words: ["Open a terminal", "Close the window", "Go to a workspace", "Take a screenshot", "Record the screen",
                         "Open the app launcher", "Programs menu", "Pick a theme", "Pick a wallpaper", "Power menu",
                         "Dismiss notifications", "Volume up", "Emoji", "Command palette", "Calculator"],
                 also: "keyboard shortcuts hotkeys hotkey keys bindings remap rebind shortcut super alt k" },
    wifi:      { label: "Wi-Fi", icon: "\u{F05A9}", file: "Wifi",
                 words: ["Turn Wi-Fi on or off", "Connect to a network", "Forget a network"],
                 also: "wifi wireless network internet" },
    bluetooth: { label: "Bluetooth", icon: "\u{F00AF}", file: "Bluetooth",
                 words: ["Pair a device", "Connect headphones", "Forget a device", "Headphones sound quality"],
                 also: "headphones headset speaker mouse keyboard pair audio profile" },
    sound:     { label: "Sound", icon: "\u{F057E}", file: "Sound",
                 words: ["Volume", "Mute", "Play sound through", "Microphone"],
                 also: "audio speakers headphones output input mic" },
    clipboard: { label: "Clipboard", icon: "\u{F0336}", file: "Clipboard",
                 words: ["Clear clipboard cache", "Clear clipboard history", "Clipboard shortcut", "Super + Ctrl + V",
                         "Clips kept", "Paste with", "Never keep copies from", "Bar button shows"],
                 also: "clipscape clips copy paste history cache clear keybind super ctrl v pins privacy images picker colors appearance window bar" },
    media:     { label: "Media", icon: "\u{F075A}", file: "Media",
                 words: ["Now playing", "Music visualizer", "Music controls", "Album cover", "Follow a player", "Media looks"],
                 also: "mpris player spotify music song album cover art visualizer spectrum bars audio playback pause next previous" },
    clock:     { label: "Clock", icon: "\u{F0954}", file: "Clock",
                 words: ["24-hour clock", "Show seconds"],
                 also: "time date am pm" },
    sleep:     { label: "Lock and sleep", icon: "\u{F033E}", file: "Sleep",
                 words: ["Lock the screen", "Turn the screen off", "Go to sleep", "Keep awake"],
                 also: "power idle suspend caffeine screensaver lock" },
    updates:   { label: "Updates", icon: "\u{F06B0}", file: "Updates",
                 words: ["Check for updates", "Update now"],
                 also: "upgrade version new" },
    backup:    { label: "Backup", icon: "\u{F0193}", file: "Backup",
                 words: ["Save my setup", "Bring a setup back"],
                 also: "export import restore move" },
    plugins:   { label: "Plugins", icon: "\u{F0431}", file: "Plugins",
                 words: ["Turn a part of the desktop on or off"],
                 also: "extensions modules addons" },
    about:     { label: "About", icon: "\u{F02FC}", file: "About",
                 words: ["Version"],
                 also: "info system aequalyn" }
};

// the pages in sidebar order
var order = [];
for (var g = 0; g < groups.length; g++) order = order.concat(groups[g].pages);

// the names older parts of the shell open pages by (IPC methods, bar buttons, and
// Atelier's former tabs), with the sub page to show: "page" or "page:tab"
var aliases = { appearance: "theme", hyprland: "windows",
                displays: "screens", power: "sleep", docks: "dock",
                themes: "theme", wallpapers: "wallpaper", layouts: "arrange",
                rotation: "wallpaper:1", palette: "theme:1", panel: "picker", backdrop: "windows:1" };

// "wifi", "rotation" or "wallpaper:1" -> { page, tab }; page "" when there is none
function resolve(name) {
    var n = String(name || "");
    if (!pages[n] && aliases[n]) n = aliases[n];
    var parts = n.split(":");
    var tab = parts.length > 1 ? parseInt(parts[1]) : 0;
    return { page: pages[parts[0]] ? parts[0] : "", tab: isNaN(tab) ? 0 : tab };
}

// What matches what you typed, best first: the settings themselves (SettingsIndex.js,
// read from the pages), then the pages and the words they are known by. `cat` keeps one
// category ("" for all). Each result: { page, tab, label, group, where, icon, cat, entry,
// score }; `entry` is the indexed control (with `setting` when it can be changed right
// there), null for a page.
function search(query, cat) {
    var q = (query || "").toLowerCase().trim();
    if (q === "") return [];
    var words = q.split(/\s+/);
    function hits(hay) {
        for (var w = 0; w < words.length; w++) if (hay.indexOf(words[w]) < 0) return false;
        return true;
    }
    function rank(name) {
        return name.indexOf(q) === 0 ? 3 : (" " + name).indexOf(" " + words[0]) >= 0 ? 2 : name.indexOf(q) >= 0 ? 1 : 0;
    }
    var out = [], seen = {};
    function push(r) {
        var id = r.page + "|" + r.label.toLowerCase() + "|" + (r.group || "");
        if (seen[id]) return;
        seen[id] = true;
        if (cat && r.cat !== cat) return;
        out.push(r);
    }
    // the settings
    for (var e = 0; e < Index.entries.length; e++) {
        var en = Index.entries[e], pg = pages[en.page];
        if (!pg || order.indexOf(en.page) < 0) continue;
        var hay = (en.title + " " + (en.group || "") + " " + (en.sub || "") + " " + pg.label + " " + pg.also).toLowerCase();
        if (!hits(hay)) continue;
        push({ page: en.page, tab: en.tab || 0, label: en.title, group: en.group || "", icon: pg.icon,
               cat: categoryOf(en.page), entry: en,
               score: rank(en.title.toLowerCase()) * 2 + (en.setting ? 1 : 0) + 4 });
    }
    // the pages, and the words they are known by
    for (var i = 0; i < order.length; i++) {
        var key = order[i], p = pages[key];
        var names = [p.label].concat(p.words);
        for (var j = 0; j < names.length; j++) {
            if (!hits((names[j] + " " + p.label + " " + p.also).toLowerCase())) continue;
            push({ page: key, tab: 0, label: names[j], group: "", icon: p.icon, cat: categoryOf(key), entry: null,
                   score: rank(names[j].toLowerCase()) * 2 + (j === 0 ? 5 : 2) });
        }
    }
    for (var k = 0; k < out.length; k++) {
        var c = category(out[k].cat);
        out[k].where = (c ? c.title + " › " : "") + pages[out[k].page].label + (out[k].group ? " › " + out[k].group : "");
    }
    out.sort(function (a, b) { return b.score - a.score || a.label.length - b.label.length; });
    return out.slice(0, 80);
}

// how many results each category has, for the chips over the results
function counts(query) {
    var all = search(query, ""), n = { "": all.length };
    for (var i = 0; i < categories.length; i++) n[categories[i].key] = 0;
    for (var j = 0; j < all.length; j++) if (all[j].cat) n[all[j].cat]++;
    return n;
}

// the pages kept once built: no timers or scans run on them while hidden
var kept = ["home", "wallpaper", "theme", "bar", "dock", "picker", "lockscreens", "windows", "sleep"];
