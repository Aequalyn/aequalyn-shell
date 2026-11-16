.pragma library

// Every page of the control center, in the order of the sidebar. `words` are the
// settings on the page, shown as search results; `also` are other words people may
// type for it. A plugin's page will be added here from its plugin.json.
//
// Pages with live pictures are kept once made (on their first visit), so they show at
// once after that; the rest are made when shown and dropped when left, so their scans
// and timers only run while you look at them.
var groups = [
    { title: "",        pages: ["home"] },
    { title: "Look",    pages: ["wallpaper", "theme", "bar", "dock", "picker", "lockscreens"] },
    { title: "Windows", pages: ["arrange", "windows", "switcher", "screens", "input", "cursor"] },
    { title: "Connect", pages: ["wifi", "bluetooth", "sound"] },
    { title: "System",  pages: ["apps", "webapps", "store", "aiTools", "clock", "sleep", "updates", "backup", "plugins", "about"] }
];

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
    lockscreens: { label: "Lock screens", icon: "\u{F033E}", file: "LockScreens",
                 words: ["SDDM theme", "Login screen", "Autologin", "Lock screen preview"],
                 also: "sddm greeter login autologin preview lock" },
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
                 words: ["Keyboard layout", "Natural scrolling", "Keyboard shortcuts"],
                 also: "keyboard touchpad mouse scroll shortcuts keybinds language" },
    wifi:      { label: "Wi-Fi", icon: "\u{F05A9}", file: "Wifi",
                 words: ["Turn Wi-Fi on or off", "Connect to a network", "Forget a network"],
                 also: "wifi wireless network internet" },
    bluetooth: { label: "Bluetooth", icon: "\u{F00AF}", file: "Bluetooth",
                 words: ["Pair a device", "Connect headphones", "Forget a device", "Headphones sound quality"],
                 also: "headphones headset speaker mouse keyboard pair audio profile" },
    sound:     { label: "Sound", icon: "\u{F057E}", file: "Sound",
                 words: ["Volume", "Mute", "Play sound through", "Microphone"],
                 also: "audio speakers headphones output input mic" },
    apps:      { label: "Apps", icon: "\u{F003B}", file: "Apps",
                 words: ["Default browser", "Default AI tool", "Default coding agent", "Default terminal", "Default file manager", "Default text editor", "Default video player"],
                 also: "default applications open with browser ai tool coding agent" },
    webapps:   { label: "Web apps", icon: "\u{F0595}", file: "Webapps",
                 words: ["Add a web app", "Remove a web app", "Web app browser", "Web app shortcuts"],
                 also: "webapp web app website site reddit chatgpt youtube music shortcut launcher app window" },
    store:     { label: "Store", icon: "\u{F034A}", file: "Store",
                  words: ["Install a package", "Install from the AUR", "Arch packages", "AUR packages"],
                  also: "store install software package aur pacman yay app application" },
    aiTools:   { label: "AI tools", icon: "\u{F06A9}", file: "AiTools",
                 words: ["Install a coding agent", "Update an AI CLI", "Remove an AI CLI", "Claude Code", "Codex", "Copilot CLI", "Gemini CLI", "OpenCode", "Qwen Code", "Kilo Code", "Cline", "Crush", "Amp"],
                 also: "ai artificial intelligence coding agent cli terminal claude codex copilot gemini opencode qwen kilo cline crush amp developer development programming mise node npm" },
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
var aliases = { appearance: "theme", defaultApps: "apps", hyprland: "windows",
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

// what matches what you typed: settings first, then pages
function search(query) {
    var q = (query || "").toLowerCase().trim();
    if (q === "") return [];
    var words = q.split(/\s+/);
    var out = [];
    for (var i = 0; i < order.length; i++) {
        var key = order[i], p = pages[key];
        var entries = [p.label].concat(p.words);
        for (var j = 0; j < entries.length; j++) {
            var hay = (entries[j] + " " + p.label + " " + p.also).toLowerCase();
            var hit = true;
            for (var w = 0; w < words.length; w++) if (hay.indexOf(words[w]) < 0) { hit = false; break; }
            if (!hit) continue;
            var name = entries[j].toLowerCase();
            var score = (name.indexOf(q) === 0 ? 4 : name.indexOf(q) >= 0 ? 2 : 0) + (j === 0 ? 1 : 0);
            out.push({ page: key, label: entries[j], where: j === 0 ? "Page" : p.label, icon: p.icon, score: score });
        }
    }
    out.sort(function (a, b) { return b.score - a.score; });
    return out.slice(0, 8);
}

// the pages kept once built: no timers or scans run on them while hidden
var kept = ["home", "wallpaper", "theme", "bar", "dock", "picker", "lockscreens", "windows", "sleep"];
