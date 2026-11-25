.pragma library

// Binds -- the keyboard shortcuts Hyprland uses, as Aequalyn ships them.
//
// The binds live in ~/.config/hypr/keybinds.lua, one hl.bind() a line, some made
// in loops (the workspaces 1-10, the media keys). This library reads that file
// into a catalogue -- a plain-words label and a group for each -- keeps the keys
// you chose in a table of overrides, and writes them back as a marked block at
// the end of the very same file: the last binds win, and the block runs where the
// file's own locals (M, term, files, browser) are in scope, so every action is
// copied word for word.
//
// What is never on the page: the universal clipboard (aequalyn/clipboard.lua),
// the window layouts' own keys (aequalyn/keys.lua, they are (re)bound after
// every reload), the switcher's Alt + Tab and the web apps' keys. They are held
// here as reserved, and a key one of them uses is refused with its name.
//
// Pure string work, so tests/keybinds.test.js runs it in Node unchanged.

// ------------------------------------------------------------------ chords

var MODS = ["SUPER", "CTRL", "ALT", "SHIFT"];
// the bits Hyprland's `hyprctl binds` reports, for the live check
var MOD_BITS = { SHIFT: 1, CAPS: 2, CTRL: 4, ALT: 8, MOD2: 16, MOD3: 32, SUPER: 64, MOD5: 128 };

// "shift +  super+Q" -> "SUPER + SHIFT + Q": one way of writing a key, always the same
function normalize(chord) {
    const parts = String(chord || "").split("+");
    const up = [];
    for (let i = 0; i < parts.length; i++) {
        const p = parts[i].trim().toUpperCase();
        if (p !== "" && up.indexOf(p) < 0) up.push(p);
    }
    const mods = [];
    for (let m = 0; m < MODS.length; m++) if (up.indexOf(MODS[m]) >= 0) mods.push(MODS[m]);
    const rest = [];
    for (let r = 0; r < up.length; r++) if (MODS.indexOf(up[r]) < 0) rest.push(up[r]);
    return mods.concat(rest).join(" + ");
}

// the mods of a chord as a mask, as `hyprctl binds` shows them
function modMask(chord) {
    const parts = String(chord || "").split("+");
    let mask = 0;
    for (let i = 0; i < parts.length; i++) {
        const p = parts[i].trim().toUpperCase();
        if (MOD_BITS[p] !== undefined) mask += MOD_BITS[p];
    }
    return mask;
}

// the key of a chord, as `hyprctl binds` shows it (lowercase)
function keyName(chord) {
    const parts = String(chord || "").split("+");
    for (let i = 0; i < parts.length; i++) {
        const p = parts[i].trim().toUpperCase();
        if (p !== "" && MODS.indexOf(p) < 0) return p.toLowerCase();
    }
    return "";
}

// a chord as people read it: "SUPER + SHIFT + SPACE" -> "Super + Shift + Space"
var modWords = { SUPER: "Super", CTRL: "Ctrl", ALT: "Alt", SHIFT: "Shift" };
var keyWords = {
    RETURN: "Enter", ESCAPE: "Esc", SPACE: "Space", TAB: "Tab", BACKSPACE: "Backspace",
    DELETE: "Delete", INSERT: "Insert", HOME: "Home", END: "End", PAUSE: "Pause",
    PAGEUP: "Page up", PAGEDOWN: "Page down", SLASH: "/", PERIOD: ".", COMMA: ",",
    EQUAL: "=", MINUS: "-", GRAVE: "`", PRINT: "Print", SCROLLLOCK: "Scroll lock",
    CAPSLOCK: "Caps lock", NUMLOCK: "Num lock", MENU: "Menu",
    LEFT: "\u{2190}", RIGHT: "\u{2192}", UP: "\u{2191}", DOWN: "\u{2193}",
    BRACKETLEFT: "[", BRACKETRIGHT: "]", BACKSLASH: "\\", SEMICOLON: ";", APOSTROPHE: "'",
    MOUSE_DOWN: "wheel down", MOUSE_UP: "wheel up", "MOUSE:272": "drag", "MOUSE:273": "right-drag",
    XF86AUDIORAISEVOLUME: "volume up", XF86AUDIOLOWERVOLUME: "volume down", XF86AUDIOMUTE: "mute",
    XF86AUDIOMICMUTE: "mute the microphone", XF86MONBRIGHTNESSUP: "brighter", XF86MONBRIGHTNESSDOWN: "darker",
    XF86AUDIOPLAY: "play", XF86AUDIOPAUSE: "pause", XF86AUDIONEXT: "next track", XF86AUDIOPREV: "previous track",
    XF86SELECTIVESCREENSHOT: "the screenshot key", XF86AUDIOSTOP: "stop", XF86AUDIORECORD: "record",
    XF86AUDIOMEDIA: "media", XF86MAIL: "mail", XF86FAVORITES: "favorites", XF86SEARCH: "search", XF86HOMEPAGE: "home page",
    XF86CALCULATOR: "calculator", XF86SLEEP: "sleep", XF86WWW: "the web"
};

function chordText(chord) {
    if (chord === undefined || chord === null || chord === "") return "";
    const parts = String(chord).split("+");
    const out = [];
    for (let i = 0; i < parts.length; i++) {
        const raw = parts[i].trim();
        if (raw === "") continue;
        const up = raw.toUpperCase();
        if (modWords[up]) { out.push(modWords[up]); continue; }
        if (keyWords[up]) { out.push(keyWords[up]); continue; }
        // a letter stays big, a number stays, anything else keeps its case as written
        if (/^[A-Z0-9]$/.test(up)) out.push(up);
        else if (/^F\d{1,2}$/.test(up)) out.push(up);
        else out.push(up.charAt(0) + up.slice(1).toLowerCase());
    }
    return out.join(" + ");
}

// ------------------------------------------------------------------ the page

// the marked block, at the end of keybinds.lua: last binds win
var BLOCK_BEGIN = "-- >>> keybinds >>>";
var BLOCK_END = "-- <<< keybinds <<<";
// this page's own key, bound by the plugin itself (in the block) while it is on
var SELF_CHORD = "SUPER + ALT + K";
var SELF_CMD = "qs ipc call aequalyn page keybinds";

var groupOrder = ["apps", "pack", "windows", "workspaces", "shots", "media", "mouse", "other"];
var groupTitles = {
    apps: "Apps and the shell",
    pack: "The built-in pack",
    windows: "Windows",
    workspaces: "Workspaces",
    shots: "Screenshots and recording",
    media: "Media and brightness",
    mouse: "The mouse",
    other: "Other keys"
};
var groupHints = {
    pack: "Each of these works only while its plugin is on: control center \u203a Plugins.",
    media: "Keys on a laptop or a media keyboard. To change one, press the key itself.",
    mouse: "Held with Super. A key on the keyboard cannot take their place."
};

// what each bind does, in plain words, by the key Aequalyn ships it on
var labels = {
    // apps and the shell
    "SUPER + RETURN": ["Open a terminal", "apps"],
    "SUPER + E": ["Open your files", "apps"],
    "SUPER + ALT + F": ["Aequalyn file manager", "apps"],
    "SUPER + B": ["Open the browser", "apps"],
    "SUPER + SPACE": ["Programs menu", "apps"],
    "SUPER + D": ["App launcher", "apps"],
    "SUPER + ALT + A": ["Default apps", "apps"],
    "SUPER + COMMA": ["This control center", "apps"],
    "SUPER + L": ["Next window arrangement", "apps"],
    "SUPER + SHIFT + L": ["Previous window arrangement", "apps"],
    "SUPER + ALT + L": ["All the arrangements", "apps"],
    "SUPER + CTRL + LEFT": ["Swap with the previous window", "apps"],
    "SUPER + CTRL + RIGHT": ["Swap with the next window", "apps"],
    "SUPER + T": ["Pick a theme", "apps"],
    "SUPER + W": ["Pick a wallpaper", "apps"],
    "SUPER + SHIFT + W": ["Wallpaper settings", "apps"],
    "SUPER + CTRL + SHIFT + SPACE": ["Pick a theme", "apps"],
    "SUPER + CTRL + SPACE": ["Next wallpaper", "apps"],
    "SUPER + O": ["The screen map", "apps"],
    "SUPER + SHIFT + O": ["Refresh the screen layout", "apps"],
    "SUPER + SHIFT + C": ["Keep the screen awake", "apps"],
    "SUPER + I": ["Install chooser", "apps"],
    "SUPER + R": ["Remove chooser", "apps"],
    "SUPER + N": ["Dismiss notifications", "apps"],
    "SUPER + SHIFT + N": ["Do not disturb", "apps"],
    // the built-in pack
    "SUPER + SLASH": ["Key hints", "pack"],
    "SUPER + F1": ["Manual", "pack"],
    "SUPER + SHIFT + SPACE": ["Command palette", "pack"],
    "SUPER + ALT + C": ["Calculator", "pack"],
    "SUPER + PERIOD": ["Emoji", "pack"],
    "SUPER + CTRL + PERIOD": ["Fonts", "pack"],
    "SUPER + CTRL + B": ["Quick looks: the bar", "pack"],
    "SUPER + CTRL + D": ["Quick looks: the docks", "pack"],
    "SUPER + CTRL + K": ["Quick looks: the lock screen", "pack"],
    "SUPER + CTRL + G": ["Quick looks: the login screen", "pack"],
    "SUPER + SHIFT + P": ["Pick a colour on the screen", "pack"],
    "SUPER + ALT + N": ["Quick notes", "pack"],
    "SUPER + SHIFT + ESCAPE": ["System monitor", "pack"],
    "SUPER + ALT + X": ["Copy text from the screen", "pack"],
    "SUPER + ALT + T": ["Timer", "pack"],
    // windows
    "SUPER + Q": ["Close the window", "windows"],
    "SUPER + SHIFT + V": ["Float the window", "windows"],
    "SUPER + P": ["Pseudo-tile", "windows"],
    "SUPER + F": ["Full screen", "windows"],
    "SUPER + J": ["Turn the split", "windows"],
    "SUPER + SHIFT + M": ["Power menu", "windows"],
    // workspaces
    "SUPER + S": ["Scratchpad workspace", "workspaces"],
    "SUPER + SHIFT + S": ["Move the window to the scratchpad", "workspaces"],
    // screenshots and recording
    "PRINT": ["Screenshot a part, saved and copied", "shots"],
    "SHIFT + PRINT": ["Screenshot everything, saved and copied", "shots"],
    "SUPER + PRINT": ["Screenshot a part, saved only", "shots"],
    "SUPER + CTRL + S": ["Screenshot a part, without a Print key", "shots"],
    "SUPER + CTRL + SHIFT + S": ["Screenshot everything, without a Print key", "shots"],
    "SUPER + CTRL + R": ["Record the screen: start or stop", "shots"],
    "SUPER + SHIFT + R": ["Record the screen: start or stop", "shots"],
    "XF86SELECTIVESCREENSHOT": ["The screenshot key on some keyboards", "shots"],
    // media and brightness
    "XF86AUDIORAISEVOLUME": ["Volume up", "media"],
    "XF86AUDIOLOWERVOLUME": ["Volume down", "media"],
    "XF86AUDIOMUTE": ["Mute", "media"],
    "XF86AUDIOMICMUTE": ["Mute the microphone", "media"],
    "XF86MONBRIGHTNESSUP": ["Brighter", "media"],
    "XF86MONBRIGHTNESSDOWN": ["Darker", "media"],
    "XF86AUDIOPLAY": ["Play or pause", "media"],
    "XF86AUDIOPAUSE": ["Play or pause", "media"],
    "XF86AUDIONEXT": ["Next track", "media"],
    "XF86AUDIOPREV": ["Previous track", "media"],
    // the mouse
    "SUPER + MOUSE_DOWN": ["Next workspace", "mouse"],
    "SUPER + MOUSE_UP": ["Previous workspace", "mouse"],
    "SUPER + MOUSE:272": ["Move a window", "mouse"],
    "SUPER + MOUSE:273": ["Resize a window", "mouse"]
};
// the twenty workspace keys, made by a loop in the file
for (var ws = 1; ws <= 10; ws++) {
    labels["SUPER + " + (ws % 10)] = ["Go to workspace " + ws, "workspaces"];
    labels["SUPER + SHIFT + " + (ws % 10)] = ["Move the window to workspace " + ws, "workspaces"];
}

// names for the binds a newer Aequalyn may add: from the action itself
var ipcNames = {
    launcher: "App launcher", programs: "Programs menu", defaults: "Default apps",
    installMenu: "Install chooser", removeMenu: "Remove chooser",
    aequalyn: "Control center", atelier: "Themes and wallpapers", monitors: "Screens",
    idle: "Keep awake", notifications: "Notifications", power: "Power menu",
    clipscape: "Clipboard", altscape: "Window switcher", media: "Media",
    calculator: "Calculator", colorPicker: "Color picker", emoji: "Emoji",
    notes: "Quick notes", keyHints: "Key hints", palette: "Command palette",
    sysmon: "System monitor", screenText: "Copy text from the screen", timer: "Timer",
    focus: "Focus", keybinds: "Keyboard shortcuts", bar: "The bar"
};
var varNames = { term: "Open a terminal", files: "Open your files", browser: "Open the browser" };
var dspWords = {
    "window.close": "Close the window", "window.float": "Float the window",
    "window.pseudo": "Pseudo-tile the window", "window.fullscreen": "Full screen",
    "window.move": "Move the window", "workspace.toggle_special": "The scratchpad workspace"
};

function deriveLabel(action) {
    const a = String(action || "");
    let m = a.match(/description\s*=\s*"([^"]+)"/);
    if (m) return m[1];
    m = a.match(/hl\.dsp\.exec_cmd\(\s*"qs ipc call (\S+)\s*([^"]*)"\s*\)/);
    if (m) return ipcNames[m[1]] || (m[1] + (m[2].trim() ? " " + m[2].trim() : ""));
    m = a.match(/hl\.dsp\.exec_cmd\(\s*(\w+)\s*\)/);
    if (m) return varNames[m[1]] || m[1];
    m = a.match(/aequalyn-webapp launch ([^"\s]+)/);
    if (m) return "The " + m[1] + " web app";
    m = a.match(/hl\.dsp\.exec_cmd\(\s*"([^"]*)"/);
    if (m) return m[1].length > 40 ? "Run a command" : "Run: " + m[1];
    m = a.match(/hl\.dsp\.([\w.]+)\(/);
    if (m) {
        const d = dspWords[m[1]] || m[1].replace(/\./g, " ").replace(/_/g, " ");
        return d.charAt(0).toUpperCase() + d.slice(1);
    }
    return "A key binding";
}

// ------------------------------------------------------------------ parsing

// our own block, if the file already carries it: the catalogue must not read it back
function stripBlock(text) {
    const lines = String(text || "").split("\n");
    const out = [];
    let inBlock = false;
    for (let i = 0; i < lines.length; i++) {
        const t = lines[i].trim();
        if (t === BLOCK_BEGIN) { inBlock = true; continue; }
        if (t === BLOCK_END) { inBlock = false; continue; }
        if (!inBlock) out.push(lines[i]);
    }
    return out.join("\n");
}

// a Lua string, escaped and quoted
function luaStr(s) {
    const e = String(s === undefined || s === null ? "" : s).replace(/\\/g, "\\\\").replace(/"/g, '\\"');
    return '"' + e + '"';
}

// a Lua string's content, as text again
function unquote(s) {
    return String(s).replace(/\\"/g, '"').replace(/\\\\/g, "\\");
}

// the arguments of a call that starts at line[from] == "(": split at its own
// top-level commas, strings and nested calls kept whole, a trailing comment ends it
function callArgs(line, from) {
    let nest = 0, inStr = false, esc = false, buf = "", args = [];
    for (let i = from; i < line.length; i++) {
        const c = line.charAt(i);
        if (esc) { buf += c; esc = false; continue; }
        if (inStr) {
            if (c === "\\") { buf += c; esc = true; continue; }
            if (c === '"') inStr = false;
            buf += c; continue;
        }
        if (c === '"') { inStr = true; buf += c; continue; }
        if (c === "-" && line.charAt(i + 1) === "-") break;
        if (c === "(" || c === "{" || c === "[") {
            if (nest === 0) { nest++; continue; }
            nest++; buf += c; continue;
        }
        if (c === ")" || c === "}" || c === "]") {
            nest--;
            if (nest === 0) { args.push(buf.trim()); return args; }
            buf += c; continue;
        }
        if (c === "," && nest === 1) { args.push(buf.trim()); buf = ""; continue; }
        buf += c;
    }
    return null;   // the call runs past this line: not one of ours
}

// one name, as a whole word, with its value: i -> 3 in "r~" .. i
function subWord(text, name, value) {
    return String(text).replace(new RegExp("\\b" + name + "\\b", "g"), String(value));
}

// a `local NAME = { ... }` table over one or more lines: its entries as string lists
function readTable(lines, at, openAt) {
    // where the table's braces close: the first "}" that matches its "{"
    let nest = 0, inStr = false, esc = false, endLine = -1;
    for (let i = at; i < lines.length && endLine < 0; i++) {
        const line = i === at ? lines[i].substring(openAt) : lines[i];
        for (let j = 0; j < line.length; j++) {
            const c = line.charAt(j);
            if (esc) { esc = false; continue; }
            if (inStr) {
                if (c === "\\") { esc = true; continue; }
                if (c === '"') inStr = false;
                continue;
            }
            if (c === '"') { inStr = true; continue; }
            if (c === "-" && line.charAt(j + 1) === "-") break;
            if (c === "{") nest++;
            else if (c === "}") { nest--; if (nest === 0) { endLine = i; break; } }
        }
    }
    if (endLine < 0) return { entries: [], next: lines.length };
    // the text between the outer braces
    let body = "";
    for (let i = at; i <= endLine; i++) {
        let line = lines[i];
        if (i === at) line = line.substring(openAt + 1);
        if (i === endLine) line = line.substring(0, line.lastIndexOf("}"));
        body += (i > at ? "\n" : "") + line;
    }
    // the entries, at the table's own commas: { "a", "b" } each
    const entries = [];
    const parts = callArgs("f(" + body + ")", 1);
    if (parts) {
        for (let p = 0; p < parts.length; p++) {
            if (parts[p].trim() === "") continue;
            const strs = [];
            const re = /"((?:[^"\\]|\\.)*)"/g;
            let sm;
            while ((sm = re.exec(parts[p])) !== null) strs.push(unquote(sm[1]));
            if (strs.length > 0) entries.push(strs);
        }
    }
    return { entries: entries, next: endLine + 1 };
}

// keybinds.lua (or clipboard.lua, or webapps.lua) -> the binds it makes.
// Each: { id, label, group, action, flags, editable, hardware, line }.
// Binds the parser cannot name (a new loop shape, say) are skipped and noted.
function parseBinds(text) {
    const src = stripBlock(text);
    const lines = src.split("\n");
    const raw = [];
    const warnings = [];
    const tables = {};
    let modVar = "M", modVal = "SUPER";
    let loop = null;   // { type: "range", var, from, to, locals } | { type: "table", var, entries }

    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        const t = line.trim();
        if (t === "" || t.indexOf("--") === 0) continue;

        let m = t.match(/^local\s+(\w+)\s*=\s*"SUPER"$/);
        if (m) { modVar = m[1]; modVal = "SUPER"; continue; }

        m = t.match(/^local\s+(\w+)\s*=\s*\{/);
        if (m) {
            const r = readTable(lines, i, t.indexOf("{"));
            tables[m[1]] = r.entries;
            i = r.next - 1;
            continue;
        }

        m = t.match(/^for\s+(\w+)\s*=\s*(\d+)\s*,\s*(\d+)\s+do$/);
        if (m) { loop = { type: "range", var: m[1], from: Number(m[2]), to: Number(m[3]), locals: {} }; continue; }

        m = t.match(/^for\s+(_|\w+)\s*,\s*(\w+)\s+in\s+ipairs\((\w+)\)\s+do$/);
        if (m) {
            loop = tables[m[3]] ? { type: "table", var: m[2], entries: tables[m[3]] } : null;
            if (!loop) warnings.push({ line: i + 1, why: "the loop reads " + m[3] + ", which is not a table of strings" });
            continue;
        }

        if (t === "end") { loop = null; continue; }

        if (loop && loop.type === "range") {
            m = t.match(/^local\s+(\w+)\s*=\s*tostring\(\s*(\w+)\s*%\s*(\d+)\s*\)$/);
            if (m && m[2] === loop.var) { loop.locals[m[1]] = { mod: Number(m[3]) }; continue; }
        }

        if (t.indexOf("hl.bind(") !== 0) continue;

        const args = callArgs(line, line.indexOf("hl.bind(") + "hl.bind(".length - 1);
        if (!args || args.length < 2) { warnings.push({ line: i + 1, why: "the call is not one line" }); continue; }

        const make = (ctx) => {
            const chord = resolveChord(args[0], ctx);
            if (!chord) return null;
            return { chord: chord, action: resolveAction(args[1], ctx), flags: args.length > 2 ? args[2] : "" };
        };

        if (loop && loop.type === "range") {
            let any = false;
            for (let n = loop.from; n <= loop.to; n++) {
                const ctx = { modVar: modVar, modVal: modVal, i: n, loopVar: loop.var, localVals: {} };
                for (const name in loop.locals) ctx.localVals[name] = String(n % loop.locals[name].mod);
                const b = make(ctx);
                if (b) { b.line = i + 1; raw.push(b); any = true; }
            }
            if (!any) warnings.push({ line: i + 1, why: "the loop's keys are not ones this knows" });
        } else if (loop && loop.type === "table") {
            for (let e = 0; e < loop.entries.length; e++) {
                const ctx = { modVar: modVar, modVal: modVal, entryVar: loop.var, entry: loop.entries[e] };
                const b = make(ctx);
                if (b) { b.line = i + 1; raw.push(b); }
            }
        } else {
            const b = make({ modVar: modVar, modVal: modVal });
            if (b) { b.line = i + 1; raw.push(b); }
            else warnings.push({ line: i + 1, why: "the key is made in a way this does not know" });
        }
    }

    // the last bind on a key is the one Hyprland uses: later entries replace earlier
    const byId = {};
    for (let r = 0; r < raw.length; r++) {
        const id = normalize(raw[r].chord);
        raw[r].id = id;
        byId[id] = raw[r];
    }
    const out = [];
    for (let r = 0; r < raw.length; r++) {
        if (byId[raw[r].id] !== raw[r]) continue;   // an older bind on the same key
        const e = raw[r];
        const known = labels[e.id];
        e.label = known ? known[0] : deriveLabel(e.action);
        e.group = known ? known[1] : "other";
        e.editable = e.id.indexOf("MOUSE_") < 0 && e.id.indexOf("MOUSE:") < 0;
        e.hardware = e.id.indexOf("XF86") === 0 || e.id === "PRINT";
        out.push(e);
    }
    out.sort(function (a, b) {
        const ga = groupOrder.indexOf(a.group), gb = groupOrder.indexOf(b.group);
        return ga - gb || a.id.localeCompare(b.id);
    });
    return { binds: out, warnings: warnings };
}

// a key expression, to the chord it names (null when it needs a loop we know nothing of)
function resolveChord(expr, ctx) {
    const e = String(expr || "").trim();
    let m = e.match(/^"([^"]*)"$/);
    if (m) return m[1];
    const head = ctx.modVar + " .. ";
    if (ctx.modVar && e.indexOf(head) === 0) {
        const rest = e.substring(head.length).trim();
        m = rest.match(/^"([^"]*)"\s*\.\.\s*(\w+)$/);
        if (m) {
            const v = ctx.localVals && ctx.localVals[m[2]] !== undefined ? ctx.localVals[m[2]]
                : (m[2] === ctx.loopVar ? String(ctx.i) : null);
            if (v === null) return null;
            return ctx.modVal + m[1] + v;
        }
        m = rest.match(/^"([^"]*)"$/);
        if (m) return ctx.modVal + m[1];
        return null;
    }
    m = e.match(/^(\w+)\[(\d+)\]$/);
    if (m && ctx.entry) return ctx.entry[Number(m[2]) - 1] || null;
    return null;
}

// an action expression, with the loop's variables as their values
function resolveAction(expr, ctx) {
    let a = String(expr || "").trim();
    if (ctx.loopVar) a = subWord(a, ctx.loopVar, ctx.i);
    if (ctx.localVals) for (const name in ctx.localVals) a = subWord(a, name, ctx.localVals[name]);
    if (ctx.entryVar && ctx.entry) {
        a = a.replace(new RegExp(ctx.entryVar + "\\[(\\d+)\\]", "g"), function (mm, idx) {
            return luaStr(ctx.entry[Number(idx) - 1] || "");
        });
    }
    // "r~" .. 3 -> "r~3": tidier in the block, and still the same to Lua
    a = a.replace(/"([^"]*)"\s*\.\.\s*(\d+)/g, function (mm, s, n) { return '"' + s + n + '"'; });
    return a.trim();
}

// ------------------------------------------------------------------ reserved keys

// the universal clipboard (aequalyn/clipboard.lua), by the keys it uses
var clipboardLabels = {
    "SUPER + A": "Select all, in any app",
    "SUPER + C": "Copy, in any app",
    "SUPER + V": "Paste, in any app",
    "SUPER + X": "Cut, in any app",
    "SUPER + CTRL + V": "Clipboard history (Clipscape)"
};

// the layouts' keys (aequalyn/keys.lua, (re)bound after every reload), the
// switcher's and this page's own: named here, not on the page
function buildReserved() {
    const r = {};
    for (let d = 0; d < 4; d++) {
        const dir = ["LEFT", "RIGHT", "UP", "DOWN"][d];
        r["SUPER + " + dir] = "Focus the window that way: one of the layouts' keys";
        r["SUPER + SHIFT + " + dir] = "Swap two windows: one of the layouts' keys";
    }
    r["SUPER + Z"] = "Make the focused window the main one: one of the layouts' keys";
    const step = ["SUPER", "SUPER + ALT", "SUPER + CTRL"];
    for (let s = 0; s < step.length; s++) {
        r[step[s] + " + MINUS"] = "The main window smaller: one of the layouts' keys";
        r[step[s] + " + EQUAL"] = "The main window larger: one of the layouts' keys";
    }
    r["SUPER + CTRL + L"] = "Pick an arrangement: one of the layouts' keys";
    r["ALT + TAB"] = "The window switcher";
    r["ALT + SHIFT + TAB"] = "The window switcher, backwards";
    r["SUPER + TAB"] = "The window switcher, when it is set to Super";
    r["SUPER + SHIFT + TAB"] = "The window switcher backwards, when it is set to Super";
    r["SUPER + ALT + SHIFT + S"] = "The switcher's settings";
    r[SELF_CHORD] = "This page";
    return r;
}
var reservedStatic = buildReserved();

// the clipboard's and the web apps' keys, read from their files, folded into the
// reserved table (theirs win: they say what the key does)
function reservedFromFiles(clipboardText, webappsText) {
    const out = {};
    for (const k in reservedStatic) out[k] = reservedStatic[k];
    if (clipboardText) {
        const p = parseBinds(clipboardText);
        for (let i = 0; i < p.binds.length; i++) {
            const b = p.binds[i];
            out[b.id] = clipboardLabels[b.id] || ("The universal clipboard: " + b.label);
        }
    }
    if (webappsText) {
        const p = parseBinds(webappsText);
        for (let i = 0; i < p.binds.length; i++) out[p.binds[i].id] = p.binds[i].label;
    }
    return out;
}

// the rows for the page's fold: the reserved keys, in plain words
function reservedRows(reserved) {
    const order = [
        ["SUPER + A", "SUPER + C", "SUPER + V", "SUPER + X"],
        ["SUPER + CTRL + V"],
        ["SUPER + LEFT", "SUPER + RIGHT", "SUPER + UP", "SUPER + DOWN"],
        ["SUPER + SHIFT + LEFT", "SUPER + SHIFT + RIGHT", "SUPER + SHIFT + UP", "SUPER + SHIFT + DOWN"],
        ["SUPER + Z"],
        ["SUPER + MINUS", "SUPER + EQUAL", "SUPER + ALT + MINUS", "SUPER + ALT + EQUAL",
         "SUPER + CTRL + MINUS", "SUPER + CTRL + EQUAL"],
        ["SUPER + CTRL + L"],
        ["ALT + TAB", "ALT + SHIFT + TAB", "SUPER + TAB", "SUPER + SHIFT + TAB"],
        ["SUPER + ALT + SHIFT + S"],
        [SELF_CHORD]
    ];
    const rows = [];
    for (let o = 0; o < order.length; o++) {
        const chords = order[o];
        const reasons = [];
        for (let c = 0; c < chords.length; c++) if (reserved[chords[c]]) reasons.push(reserved[chords[c]]);
        if (reasons.length === 0) continue;
        rows.push({ keys: chords.map(chordText).join("  \u00b7  "), what: reasons[0] });
    }
    // the web apps' keys, one row each
    const rest = [];
    for (const id in reserved) {
        if (reserved[id].indexOf("web app") >= 0) rest.push({ keys: chordText(id), what: reserved[id] });
    }
    return rows.concat(rest);
}

// ------------------------------------------------------------------ your keys

// The page's whole state, as saved in overrides.json: the shipped binds whose
// keys you moved (Aequalyn's own -> yours), the ones you deleted, and the
// binds you made yourself (a name and a command, on a key of yours). An older
// file is a plain map of moved keys only.
function newState() {
    return { changed: {}, removed: [], custom: [] };
}

function hasControl(s) { return /[\u0000-\u001f]/.test(String(s || "")) }

// does this look like keys someone typed ("super + alt + m"), not a command?
// Two or more + separated words, at least one a modifier, every one a key word.
function looksLikeChord(s) {
    const parts = String(s || "").split("+").map(p => p.trim()).filter(p => p !== "");
    if (parts.length < 2) return false;
    const mods = /^(super|sup|win|meta|ctrl|control|alt|shift|altgr)$/i;
    const keys = /^(esc|escape|tab|enter|return|space|print|scrolllock|capslock|grave|left|right|up|down|delete|insert|home|end|pageup|pagedown|backspace|f\d{1,2}|[a-z0-9]|[,.\/;'[\]`\\=\-])$/i;
    let hasMod = false;
    for (let i = 0; i < parts.length; i++) {
        if (mods.test(parts[i])) { hasMod = true; continue }
        if (!keys.test(parts[i])) return false;
    }
    return hasMod;
}

// a made bind's command, with the name/command swap undone: when the command
// someone typed is keys and the name is what they meant to run, run the name
function repairCustom(entry) {
    const command = String(entry.command || "");
    const label = String(entry.label || "");
    if (!looksLikeChord(command)) return entry;
    if (label.trim() === "") return null;   // nothing to run: not a whole bind
    return { keys: entry.keys, label: "", command: label.trim() };
}

function labelOfCustom(c) {
    return c.label && String(c.label).trim() !== "" ? String(c.label)
        : "Run: " + String(c.command).split(/\s+/)[0];
}

// one file's worth of state, old shape or new
function readState(text) {
    let raw;
    try { raw = JSON.parse(String(text || "{}")) } catch (e) { raw = {} }
    if (!raw || typeof raw !== "object" || Array.isArray(raw)) raw = {};
    const st = newState();
    if (raw.changed !== undefined || raw.removed !== undefined || raw.custom !== undefined) {
        const ch = raw.changed && typeof raw.changed === "object" && !Array.isArray(raw.changed) ? raw.changed : {};
        for (const k in ch) st.changed[normalize(k)] = normalize(ch[k]);
        const rm = Array.isArray(raw.removed) ? raw.removed : [];
        for (let i = 0; i < rm.length; i++) {
            const id = normalize(rm[i]);
            if (id !== "" && st.removed.indexOf(id) < 0) st.removed.push(id);
        }
        const cu = Array.isArray(raw.custom) ? raw.custom : [];
        for (let i = 0; i < cu.length; i++) {
            let c = cu[i] && typeof cu[i] === "object" ? cu[i] : null;
            if (!c || !c.command || hasControl(c.command) || hasControl(c.label)) continue;
            const keys = normalize(c.keys);
            if (keys === "") continue;
            // the name and the command may have come swapped: the command holds
            // the keys, the name what they meant to run. Undone here, so every
            // saved entry of that kind heals without a migration.
            const fixed = repairCustom({ keys: keys, label: String(c.label || ""), command: String(c.command) });
            if (!fixed) continue;
            st.custom.push({ keys: fixed.keys, label: String(fixed.label || ""), command: String(fixed.command) });
        }
        return st;
    }
    // an older file: { "SUPER + Q": "SUPER + SHIFT + Q" }
    for (const k in raw) st.changed[normalize(k)] = normalize(raw[k]);
    return st;
}

// the key a bind is on now: yours, the one Aequalyn ships, or "" once deleted
function currentKey(bind, state) {
    if (state && state.removed && state.removed.indexOf(bind.id) >= 0) return "";
    const o = state && state.changed ? state.changed[bind.id] : undefined;
    return o && o !== bind.id ? o : bind.id;
}

// a chord, against everything else that uses it. null when it is free; the
// string "modifier" when a key alone would be taken from every app; otherwise
// the name of the key's holder, in plain words. `except` spares the one being
// edited: { id: a shipped bind's id } while its key is being changed, or
// { custom: a made bind's own key } while that is being moved.
function conflict(chord, except, binds, state, reserved) {
    const id = normalize(chord);
    if (id === "") return "nothing was pressed";
    const parts = id.split(" + ");
    const key = parts[parts.length - 1];
    const bare = parts.length === 1;
    const okBare = key.indexOf("XF86") === 0 || key === "PRINT" || /^F\d{1,2}$/.test(key);
    if (bare && !okBare) return "modifier";
    if (reserved && reserved[id]) return reserved[id];
    if (binds && state) {
        for (let i = 0; i < binds.length; i++) {
            const b = binds[i];
            if (except && except.id && b.id === except.id) continue;
            const cur = currentKey(b, state);
            if (cur !== "" && normalize(cur) === id) return b.label;
        }
        for (let c = 0; c < state.custom.length; c++) {
            if (except && except.custom && state.custom[c].keys === except.custom) continue;
            if (normalize(state.custom[c].keys) === id) return labelOfCustom(state.custom[c]);
        }
    }
    return null;
}

// ------------------------------------------------------------------ the block

// the marked block, from your state: every unbind first, then every bind, so
// a key that moves from one bind to another is never caught in between. A
// deleted shipped bind is only unbound; a bind you made is bound to your key
// with its command; the mark (@@MARK@@) is the plugin's own helper, which
// keybinds-sync fills in from where it really is: the block works only while
// the plugin is there.
// Returns { text, skipped }: a skip is a change that no longer fits (its bind
// is gone, or its key is taken), kept in the state but not written.
function blockLua(binds, state) {
    const skipped = [];
    const seenTargets = {};
    const removed = [];
    const changed = [];
    const custom = [];

    for (let i = 0; i < binds.length; i++) {
        const b = binds[i];
        const isRemoved = state.removed.indexOf(b.id) >= 0;
        const to = state.changed[b.id];
        if (isRemoved) { removed.push(b); continue; }   // a delete wins over a moved key
        if (to === undefined || to === null) continue;
        const norm = normalize(to);
        if (norm === b.id) { skipped.push({ id: b.id, why: "it is already Aequalyn's own key" }); continue; }
        if (conflict(norm, { id: b.id }, binds, state, null)) {
            skipped.push({ id: b.id, why: "the key is used by another bind" });
            continue;
        }
        if (seenTargets[norm]) { skipped.push({ id: b.id, why: "two binds want the same key" }); continue; }
        seenTargets[norm] = true;
        changed.push({ bind: b, to: norm });
    }
    // deletes of binds Aequalyn no longer ships: noted, not written
    for (let r = 0; r < state.removed.length; r++) {
        const id = state.removed[r];
        let ships = false;
        for (let i = 0; i < binds.length; i++) if (binds[i].id === id) ships = true;
        if (!ships) skipped.push({ id: id, why: "Aequalyn no longer ships it" });
    }
    for (let c = 0; c < state.custom.length; c++) {
        const e = state.custom[c];
        const norm = normalize(e.keys);
        if (norm === "" || hasControl(e.command) || (!e.label && !e.command)) {
            skipped.push({ id: norm, why: "it says nothing to run" });
            continue;
        }
        if (conflict(norm, { custom: e.keys }, binds, state, null)) {
            skipped.push({ id: norm, why: "the key is used by another bind" });
            continue;
        }
        if (seenTargets[norm]) { skipped.push({ id: norm, why: "two binds want the same key" }); continue; }
        seenTargets[norm] = true;
        custom.push({ keys: norm, label: labelOfCustom(e), command: e.command });
    }

    const L = [];
    L.push(BLOCK_BEGIN);
    L.push("-- Your keys, as set on the Keyboard shortcuts page of the control center.");
    L.push("-- Take one back there, or remove this block to start over. The plugin");
    L.push("-- rewrites it whenever a key changes, so it can be edited freely.");
    L.push("do");
    L.push("local kb_mark = io.open(\"@@MARK@@\", \"r\")");
    L.push("if kb_mark then");
    L.push("  kb_mark:close()");
    if (changed.length > 0 || removed.length > 0 || custom.length > 0) {
        if (removed.length > 0 || changed.length > 0) {
            L.push("  -- first take back the keys Aequalyn ships with");
            for (let r = 0; r < removed.length; r++)
                L.push("  pcall(hl.unbind, " + luaStr(removed[r].chord) + ")  -- deleted: " + removed[r].label);
            for (let c = 0; c < changed.length; c++)
                L.push("  pcall(hl.unbind, " + luaStr(changed[c].bind.chord) + ")  -- " + changed[c].bind.label);
        }
        if (changed.length > 0) {
            L.push("  -- then give their actions your own keys");
            for (let c = 0; c < changed.length; c++) {
                const b = changed[c].bind;
                L.push("  hl.bind(" + luaStr(changed[c].to) + ", " + b.action + (b.flags ? ", " + b.flags : "") + ")  -- " + b.label);
            }
        }
        if (custom.length > 0) {
            L.push("  -- and the keys you made yourself");
            for (let c = 0; c < custom.length; c++) {
                const e = custom[c];
                L.push("  hl.bind(" + luaStr(e.keys) + ", hl.dsp.exec_cmd(" + luaStr(e.command)
                    + "), { description = " + luaStr(e.label) + " })  -- " + e.label);
            }
        }
    }
    L.push("  -- this page, while the plugin is on");
    L.push("  pcall(hl.unbind, " + luaStr(SELF_CHORD) + ")");
    L.push("  hl.bind(" + luaStr(SELF_CHORD) + ", hl.dsp.exec_cmd(" + luaStr(SELF_CMD) + "), { description = " + luaStr("Keyboard shortcuts") + " })");
    L.push("end");
    L.push("end");
    L.push(BLOCK_END);
    return { text: L.join("\n") + "\n", skipped: skipped };
}

// ------------------------------------------------------------------ chords from a press

// the mods of a key press and the key's name -> one chord, written one way
function chordFromParts(mods, key) {
    const parts = [];
    for (let i = 0; i < (mods ? mods.length : 0); i++) parts.push(mods[i]);
    parts.push(key);
    return normalize(parts.join(" + "));
}
