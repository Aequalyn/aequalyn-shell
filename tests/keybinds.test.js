// node tests/keybinds.test.js -- the catalogue reads the binds as Aequalyn ships
// them (plain lines, the two loops, the marked block), the clipboard and the
// web apps' keys are refused with their names, and the written block says
// exactly what Hyprland needs, unbinds before binds.
const assert = require("assert");
const fs = require("fs");
const path = require("path");
const load = require("./jsload.js");
const B = load(path.join(__dirname, "../plugins/keybinds/js/Binds.js"));

let n = 0;
const ok = (c, msg) => { assert.ok(c, msg); n++; };
// one state file's worth: moved keys, deleted keys, made keys
const st = (changed, removed, custom) => Object.assign(B.newState(), {
    changed: changed || {}, removed: removed || [], custom: custom || []
});

// a keybinds.lua in miniature, with every shape the real one uses
const FILE = [
    '-- a test keybinds.lua',
    'local M = "SUPER"',
    '',
    'hl.bind(M .. " + RETURN",  hl.dsp.exec_cmd(term))',
    'hl.bind(M .. " + E",       hl.dsp.exec_cmd(files))',
    'hl.bind("PRINT",           hl.dsp.exec_cmd("aequalyn-screenshot region-clip"))   -- A part, saved and copied',
    'hl.bind("XF86SelectiveScreenshot", hl.dsp.exec_cmd("aequalyn-screenshot region-clip"))',
    'hl.bind(M .. " + Q", hl.dsp.window.close())',
    'hl.bind(M .. " + T", hl.dsp.exec_cmd("qs ipc call atelier toggle themes"))',
    'hl.bind(M .. " + SHIFT + V", hl.dsp.window.float({ action = "toggle" }))',
    'hl.bind(M .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))',
    'hl.bind(M .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })',
    '',
    'for i = 1, 10 do',
    '    local key = tostring(i % 10)',
    '    hl.bind(M .. " + " .. key,        hl.dsp.focus({ workspace = "r~" .. i }))',
    '    hl.bind(M .. " + SHIFT + " .. key,  hl.dsp.window.move({ workspace = "r~" .. i }))',
    'end',
    '',
    'local media = {',
    '    { "XF86AudioRaiseVolume",   "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+" },',
    '    { "XF86AudioMute",          "say \\"hi\\"" },',
    '    { "XF86AudioPlay",          "playerctl play-pause" },',
    '}',
    'for _, b in ipairs(media) do',
    '    hl.bind(b[1], hl.dsp.exec_cmd(b[2]), { locked = true, repeating = true })',
    'end'
].join("\n");

// ------------------------------------------------------------------ parsing

let P = B.parseBinds(FILE);
ok(P.warnings.length === 0, "no warnings: " + JSON.stringify(P.warnings));
const byId = {};
for (const b of P.binds) byId[b.id] = b;

ok(P.binds.length === 9 + 20 + 3, "every bind is in the catalogue (" + P.binds.length + ")");
ok(byId["SUPER + RETURN"], "the terminal bind is there");
ok(byId["SUPER + RETURN"].action === "hl.dsp.exec_cmd(term)", "an action copied word for word");
ok(byId["SUPER + RETURN"].label === "Open a terminal", "a label in plain words");
ok(byId["SUPER + SHIFT + V"].action === "hl.dsp.window.float({ action = \"toggle\" })", "braced arguments kept whole");
ok(byId["PRINT"].hardware === true && byId["PRINT"].editable === true, "Print is a key of its own");

// the workspace loop, unfolded
for (let i = 1; i <= 10; i++) {
    const k = String(i % 10);
    const go = byId["SUPER + " + k];
    ok(go && go.action === 'hl.dsp.focus({ workspace = "r~' + i + '" })',
       "workspace " + i + " focuses r~" + i);
    ok(go.label === "Go to workspace " + i, "workspace " + i + " has its label");
    const mv = byId["SUPER + SHIFT + " + k];
    ok(mv && mv.action === 'hl.dsp.window.move({ workspace = "r~' + i + '" })',
       "workspace " + i + " move is r~" + i);
}
ok(!byId["SUPER + 10"], "the tenth workspace is on the 0 key");

// the media loop, from its table
ok(byId["XF86AUDIOPLAY"].flags === "{ locked = true, repeating = true }", "flags kept word for word");
ok(byId["XF86AUDIORAISEVOLUME"].action === 'hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+")',
   "a table's command, as a Lua string");
ok(byId["XF86AUDIOMUTE"].action === 'hl.dsp.exec_cmd("say \\"hi\\"")', "a command's quotes escaped");
ok(byId["XF86AUDIOMUTE"].group === "media" && byId["XF86AUDIOMUTE"].hardware === true, "a media key of the media group");

// not keys on the keyboard
ok(byId["SUPER + MOUSE_DOWN"].editable === false, "the wheel is not edited with keys");
ok(byId["SUPER + MOUSE:272"].editable === false, "the buttons are not edited with keys");
ok(byId["SUPER + MOUSE:272"].flags === "{ mouse = true }", "the drag's flags kept");

// a label from the action, for a bind Aequalyn may add
const New = B.parseBinds('hl.bind(M .. " + Y", hl.dsp.exec_cmd("qs ipc call programsMenuSomething toggle"))');
ok(New.binds[0].label.length > 0, "an unknown bind still gets a name");

// the marked block, read back without doubling
const WithBlock = FILE + "\n\n" +
    B.blockLua(P.binds, st({ "SUPER + Q": "SUPER + SHIFT + Q" })).text;
const Reparsed = B.parseBinds(WithBlock);
ok(Reparsed.binds.length === P.binds.length, "the block is not read back as binds");
ok(Reparsed.warnings.length === 0, "and it leaves no warnings");

// a bind that changed its own line: the later one is the one Hyprland uses
const Twice = B.parseBinds([
    'hl.bind(M .. " + Y", hl.dsp.exec_cmd("first"))',
    'hl.bind(M .. " + Y", hl.dsp.exec_cmd("second"))'
].join("\n"));
ok(Twice.binds.length === 1 && Twice.binds[0].action === 'hl.dsp.exec_cmd("second")', "the later bind on a key wins");

// ------------------------------------------------------------------ chords

ok(B.normalize("super+ctrl+  v") === "SUPER + CTRL + V", "one way of writing a chord");
ok(B.normalize("SHIFT + super + Q") === "SUPER + SHIFT + Q", "mods in a fixed order");
ok(B.normalize("SUPER + SUPER + Q") === "SUPER + Q", "a chord never says a mod twice");
ok(B.normalize("") === "", "nothing pressed is nothing");

ok(B.chordText("SUPER + SHIFT + SPACE") === "Super + Shift + Space", "a chord as people read it");
ok(B.chordText("XF86AUDIORAISEVOLUME") === "volume up", "a media key in plain words");
ok(B.chordText("SUPER + MOUSE:272") === "Super + drag", "the mouse drag in plain words");
ok(B.chordText("SHIFT + PRINT") === "Shift + Print", "Print keeps its capital");
ok(B.chordText("SUPER + 3") === "Super + 3", "a number stays a number");

ok(B.modMask("SUPER + SHIFT + Q") === 65, "the mods as hyprctl reports them: Super+Shift");
ok(B.modMask("CTRL + ALT") === 12, "Ctrl+Alt");
ok(B.keyName("SUPER + RETURN") === "return", "the key as hyprctl reports it");
ok(B.keyName("XF86AUDIOMUTE") === "xf86audiomute", "media keys are lowercased too");

ok(B.chordFromParts(["SHIFT", "CTRL"], "v") === "CTRL + SHIFT + V", "a press becomes one chord, mods first");
ok(B.chordFromParts([], "print") === "PRINT", "a bare key is a chord too");

// ------------------------------------------------------------------ reserved keys

const CLIP = [
    '-- the universal clipboard',
    'local mod = "SUPER"',
    'local function send_shortcut_once(mods, key)',
    '  return function()',
    '    hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "down" }))',
    '  end',
    'end',
    'hl.bind(mod .. " + A",           send_shortcut_once("CTRL", "A"))',
    'hl.bind(mod .. " + C",           universal("CTRL", "C", "CTRL SHIFT", "C"))',
    'hl.bind(mod .. " + V",           universal("CTRL", "V", "CTRL SHIFT", "V"))',
    'hl.bind(mod .. " + X",           send_shortcut_once("CTRL", "X"))',
    'hl.bind(mod .. " + CTRL + V",    hl.dsp.exec_cmd("qs ipc call clipscape toggle"))'
].join("\n");
const WEB = [
    'hl.bind("SUPER + SHIFT + D", hl.dsp.exec_cmd("aequalyn-webapp launch reddit"))'
].join("\n");

const reserved = B.reservedFromFiles(CLIP, WEB);
ok(reserved["SUPER + C"] === "Copy, in any app", "the clipboard's copy key is held, by name");
ok(reserved["SUPER + CTRL + V"] === "Clipboard history (Clipscape)", "Clipscape's key is held");
ok(reserved["SUPER + SHIFT + D"] === "The reddit web app", "a web app's key is held");
ok(reserved["SUPER + LEFT"].indexOf("layouts") >= 0, "the layouts' arrows are held");
ok(reserved["SUPER + CTRL + L"], "the arrangement picker is held");
ok(reserved["ALT + TAB"] === "The window switcher", "the switcher's key is held");
ok(reserved[B.SELF_CHORD] === "This page", "this page's own key is held");

const rows = B.reservedRows(reserved);
ok(rows.length >= 8, "the fold lists the keys that live elsewhere (" + rows.length + ")");
ok(rows.some(r => r.keys.indexOf("Super + C") >= 0 && r.what.indexOf("any app") >= 0), "the clipboard row, in plain words");
ok(rows.some(r => r.what.indexOf("web app") >= 0), "the web apps' rows");

// ------------------------------------------------------------------ conflicts

const binds = P.binds;

ok(B.conflict("SUPER + C", null, binds, st(), reserved) === "Copy, in any app", "a clipboard key is refused, by name");
ok(B.conflict("SUPER + E", null, binds, st(), null) === "Open your files", "another bind's key is refused, by name");
ok(B.conflict("SUPER + E", { id: "SUPER + E" }, binds, st(), null) === null, "the bind being edited does not block itself");
ok(B.conflict("X", null, binds, st(), null) === "modifier", "a key alone would be taken from every app");
ok(B.conflict("PRINT", null, [], st(), null) === null, "Print alone is allowed, as shipped");
ok(B.conflict("XF86AUDIONEXT", null, [], st(), null) === null, "a media key alone is allowed");
ok(B.conflict("SUPER + Y", null, binds, st(), reserved) === null, "a free key is free");
ok(B.conflict("SUPER + ALT + K", null, binds, st(), reserved) === "This page", "this page's own key is refused");
// your other keys are where the new key wants to go
ok(B.conflict("SUPER + Y", { id: "SUPER + T" }, binds, st({ "SUPER + Q": "SUPER + Y" }), null) === "Close the window",
   "a key you already gave to another bind is refused");
// a deleted bind frees its key, and a bind you made holds its own
ok(B.conflict("SUPER + T", null, binds, st(null, ["SUPER + T"]), null) === null,
   "deleting a bind frees its key");
ok(B.conflict("SUPER + P", null, binds, st(null, null, [{ keys: "SUPER + P", label: "Snip", command: "grim" }]), null) === "Snip",
   "a bind you made holds its key, by its name");
ok(B.conflict("SUPER + P", { custom: "SUPER + P" }, binds, st(null, null, [{ keys: "SUPER + P", label: "Snip", command: "grim" }]), null) === null,
   "the bind you made being edited does not block itself");

// ------------------------------------------------------------------ the state file

// an older file is a plain map of moved keys
const Old = B.readState('{ "SUPER + Q": "SUPER + SHIFT + Q" }');
ok(Old.changed["SUPER + Q"] === "SUPER + SHIFT + Q" && Old.removed.length === 0 && Old.custom.length === 0,
   "an older state file reads as moved keys only");
// a new file: moved, deleted, made; junk dropped, not trusted
const NewShape = B.readState(JSON.stringify({
    changed: { "SUPER + Q": "SUPER + SHIFT + Q" },
    removed: ["SUPER + P", "SUPER + P", "no longer shipped"],
    custom: [
        { keys: "SUPER + F9", label: "Snip", command: "grim -g \"$(slurp)\" - | wl-copy" },
        { keys: "SUPER + F9", label: "", command: "" },
        { keys: "SUPER + F8", label: "bad", command: "echo \"line\nbreak\"" },
        { keys: "", label: "no key", command: "true" },
        // the name and the command swapped: keys typed as the command
        { keys: "SUPER + ALT + M", label: "nautilus", command: "super + alt + m" },
        // the keys typed as the command, with no name either
        { keys: "SUPER + ALT + N", label: "", command: "super + alt + n" }
    ]
}));
ok(NewShape.changed["SUPER + Q"] === "SUPER + SHIFT + Q", "moved keys are read");
ok(NewShape.removed.length === 2 && NewShape.removed.indexOf("SUPER + P") >= 0, "deleted keys are read, once each");
ok(NewShape.custom.length === 2, "only whole made binds are read");
ok(NewShape.custom[1].command === "nautilus" && NewShape.custom[1].label === "",
   "a swapped name/command is put right: the name runs, the label is derived");

// keys someone typed, not a command
ok(B.looksLikeChord("super + alt + m") === true, "keys with spaces look like keys");
ok(B.looksLikeChord("Super+Alt+M") === true, "keys without spaces look like keys");
ok(B.looksLikeChord("ctrl + shift + f1") === true, "mods and a function key look like keys");
ok(B.looksLikeChord("nautilus") === false, "one word is a command");
ok(B.looksLikeChord("kitty --class fm") === false, "a command with flags is a command");
ok(B.looksLikeChord("grim -g \"$(slurp)\"") === false, "a command with quotes is a command");
ok(B.looksLikeChord("echo $((1+1))") === false, "a command with a plus is a command");
ok(B.looksLikeChord("") === false, "nothing is not keys");

// ------------------------------------------------------------------ the block

const BL = B.blockLua(binds, st({
    "SUPER + Q": "SUPER + SHIFT + Q",
    "SUPER + RETURN": "SUPER + Y",
    "SUPER + 3": "SUPER + ALT + 3",
    "XF86AUDIOMUTE": "SUPER + ALT + M"
}, ["SUPER + T", "SUPER + MOUSE_DOWN"], [{
    keys: "SUPER + F9", label: "Snip", command: "grim -g \"$(slurp)\" - | wl-copy"
}]));
ok(BL.skipped.length === 0, "nothing in the state is skipped: " + JSON.stringify(BL.skipped));

const firstUnbind = BL.text.indexOf("pcall(hl.unbind");
ok(firstUnbind >= 0, "the block unbinds Aequalyn's own keys");
ok(BL.text.indexOf('pcall(hl.unbind, "SUPER + Q")  -- Close the window') >= 0, "an unbind with its label");
ok(BL.text.indexOf('pcall(hl.unbind, "SUPER + T")  -- deleted: Pick a theme') >= 0,
   "a deleted bind is only unbound, and named as deleted");
ok(BL.text.indexOf('pcall(hl.unbind, "SUPER + mouse_down")  -- deleted: Next workspace') >= 0,
   "an unbind uses the key as the file spells it (mouse_down, not MOUSE_DOWN)");
ok(BL.text.indexOf('hl.bind("SUPER + SHIFT + Q", hl.dsp.window.close())  -- Close the window') >= 0, "a bind to your key, its action word for word");
ok(BL.text.indexOf('hl.bind("SUPER + Y", hl.dsp.exec_cmd(term))  -- Open a terminal') >= 0, "a bind's action has the file's locals in scope");
ok(BL.text.indexOf('hl.bind("SUPER + ALT + 3", hl.dsp.focus({ workspace = "r~3" }))') >= 0,
   "a workspace key, unfolded to its own workspace");
ok(BL.text.indexOf('hl.bind("SUPER + ALT + M", hl.dsp.exec_cmd("say \\"hi\\""), { locked = true, repeating = true })') >= 0,
   "flags travel with the bind");
ok(BL.text.indexOf('pcall(hl.unbind, "SUPER + RETURN")') > 0 && BL.text.indexOf('pcall(hl.unbind, "SUPER + 3")') > 0, "every changed bind gives back its own key");
const lastTake = BL.text.indexOf('pcall(hl.unbind, "XF86AUDIOMUTE")');   // the overrides' own section
ok(BL.text.indexOf('hl.bind("SUPER + SHIFT + Q"') > lastTake && BL.text.indexOf('hl.bind("SUPER + Y"') > lastTake,
   "every unbind comes before every bind, so a key moving between binds is not caught");
ok(BL.text.indexOf('hl.bind("SUPER + F9", hl.dsp.exec_cmd("grim -g \\"$(slurp)\\" - | wl-copy"), { description = "Snip" })  -- Snip') >= 0,
   "a bind you made: its command escaped, its name the description");
ok(BL.text.indexOf('io.open("@@MARK@@", "r")') >= 0, "the block works only while the plugin is there (the helper fills the mark in)");
ok(BL.text.indexOf('hl.bind("SUPER + ALT + K", hl.dsp.exec_cmd("qs ipc call aequalyn page keybinds")') >= 0,
   "the block binds this page's own key");
ok(BL.text.trim().startsWith(B.BLOCK_BEGIN) && BL.text.trim().endsWith(B.BLOCK_END), "the block is marked, so it can be rewritten and removed");

// a delete wins over a moved key: unbound, never re-bound
const Deleted = B.blockLua(binds, st({ "SUPER + Q": "SUPER + SHIFT + Q" }, ["SUPER + Q"]));
ok(Deleted.text.indexOf('pcall(hl.unbind, "SUPER + Q")  -- deleted: Close the window') >= 0, "the delete takes the key back");
ok(Deleted.text.indexOf('hl.bind("SUPER + SHIFT + Q"') < 0, "a deleted bind is not re-bound, even if you had moved it");

// a key that is taken is skipped, not written -- shipped and made alike
const Bad = B.blockLua(binds, st({ "SUPER + Q": "SUPER + E" }));
ok(Bad.skipped.length === 1 && Bad.skipped[0].id === "SUPER + Q", "an override onto a taken key is skipped, with a why");
ok(Bad.text.indexOf('pcall(hl.unbind, "SUPER + Q")') < 0, "the skipped bind is left alone");
const BadCustom = B.blockLua(binds, st(null, null, [{ keys: "SUPER + E", label: "Files again", command: "nautilus" }]));
ok(BadCustom.skipped.length === 1 && BadCustom.skipped[0].id === "SUPER + E"
   && BadCustom.skipped[0].why.indexOf("used by another bind") >= 0, "a made bind onto a taken key is skipped, with a why");
ok(BadCustom.text.indexOf("Files again") < 0, "the skipped made bind is not written");

// nothing changed: still the page's own key, so it works from the first moment
const Empty = B.blockLua(binds, st());
ok(Empty.text.indexOf("hl.bind") >= 0 && Empty.text.indexOf('pcall(hl.unbind, "SUPER + Q")') < 0,
   "with no changes, only this page's own key is bound");

// Super + T and Super + W call atelier, so an install saved before atelier existed
// must gain the plugin once; otherwise both keys are silently dead.
const settings = fs.readFileSync(path.join(__dirname, "../settings/AequalynSettings.qml"), "utf8");
ok(/readonly property var newPlugins: \[[^\]]*"atelier"/.test(settings),
    "existing installs gain the theme and wallpaper picker once");

// Super + / calls `qs ipc call keyHints toggle`: with the plugin off there is no
// IPC target at all, so a fresh install must ship it on and older ones gain it.
ok(/readonly property var newPlugins: \[[^\]]*"keyHints"/.test(settings),
    "existing installs gain key hints once, so Super + / starts working");
const defaults = settings.match(/property var enabledPlugins: \[([\s\S]*?)\]/);
ok(defaults && defaults[1].indexOf('"keyHints"') >= 0,
    "fresh installs have key hints on by default");

console.log("keybinds: " + n + " ok");
