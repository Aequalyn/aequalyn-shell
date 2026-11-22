.pragma library
.import "Style.js" as Style
.import "AequalynLooks.js" as AequalynLooks

// The bar's look: where its shapes go (Shapes.js) and what they are made of (the
// same style keys a dock has, Style.js), plus the ready made looks. Plain
// functions, so they can be tested.
//
// Stored in settings.json -> .barStyle. A dock set to "Same as the bar" wears the
// style keys of this (ends, surface, lines, ornaments, colors...), so the bar and
// those docks always match.

// layout settings: [allowed values] or [min, max], and the default
var layoutSettings = {
    enabled:     { bool: true, fallback: true },
    shape:       { options: ["full", "pill", "islands", "widgets"], fallback: "full" },
    pointingBar: { options: ["right", "left", "both", "outward", "inward"], fallback: "right" },
    attach:      { bool: true, fallback: false },
    concave:     { bool: true, fallback: true },
    regions:     { options: ["all", "sides", "center"], fallback: "all" },
    edgeGap:     { range: [0, 24], fallback: 6 },
    floatGap:    { range: [0, 40], fallback: 0 },
    sideGap:     { range: [0, 80], fallback: 10 },
    padding:     { range: [0, 24], fallback: 6 },
    pillRoom:    { range: [0, 12], fallback: 0 },
    pillGap:     { range: [0, 12], fallback: 2 },
    mergeGap:    { range: [0, 60], fallback: 4 },
    fullExtra:   { range: [0, 16], fallback: 0 },
    fullInset:   { range: [0, 80], fallback: 8 },
    slim:        { range: [0, 8], fallback: 0 },
    radius:      { range: [0, 24], fallback: 10 },
    pillFit:     { bool: true, fallback: false },
    centerMin:   { range: [0, 600], fallback: 0 },
    mirrorSides: { bool: true, fallback: false },
    centerStyle: { options: ["same", "tinted", "accent"], fallback: "same" },
    opacity:     { range: [10, 100], fallback: 100 },
    colorMode:   { options: ["theme", "palette", "borders", "custom", "monochrome"], fallback: "theme" },
    barTint:     { range: [0, 40], fallback: 0 },
    shadowDir:   { options: ["around", "windows"], fallback: "around" },
    outlineGradientDir: { options: ["along", "diagonal", "across", "theme"], fallback: "along" },
    bracket:     { range: [3, 16], fallback: 7 },
    accentCap:   { options: ["none", "start", "end", "both"], fallback: "none" },
    paletteUse:  { options: ["accent", "fill"], fallback: "accent" },
    widgetText:  { options: ["auto", "theme", "custom"], fallback: "auto" },
    groupColors: { bool: true, fallback: false },
    leftColor:   { hex: true, fallback: "#7aa2f7" },
    centerColor: { hex: true, fallback: "#d4a35a" },
    rightColor:  { hex: true, fallback: "#a7c080" },
    hover:       { options: ["none", "fill", "underline", "glow", "dot"], fallback: "fill" },
    hoverColor:  { options: ["text", "accent"], fallback: "text" },
    openMark:    { options: ["line", "fill", "dot", "glow", "none"], fallback: "line" },
    separators:  { options: ["none", "line", "dot", "slash"], fallback: "none" },
    sepOpacity:  { range: [10, 100], fallback: 30 },
    dividers:    { bool: true, fallback: false },
    edgeLine:    { bool: true, fallback: false },
    speed:       { range: [0, 600], fallback: 180 },
    easing:      { options: ["smooth", "springy", "linear"], fallback: "smooth" },
    idleOpacity: { range: [20, 100], fallback: 100 },
    fadeTime:    { range: [0, 1500], fallback: 300 },
    corners:     { bool: true, fallback: false },
    cornerWhich: { options: ["all", "top", "bottom"], fallback: "all" },
    cornerSize:  { range: [4, 40], fallback: 14 },
    cornerColor: { options: ["black", "bar"], fallback: "black" },
    screenFrame: { bool: true, fallback: false },
    screenFrameWidth: { range: [1, 8], fallback: 2 },
    screenFrameColor: { options: ["accent", "border", "bar", "black"], fallback: "accent" },
    barButton:   { options: ["icon", "text", "hidden"], fallback: "icon" },
    barText:     { text: true, maxLength: 12, fallback: "Bar" },
    rightClick:  { options: ["shape", "look", "none"], fallback: "shape" },
    middleClick: { options: ["toggle", "look", "none"], fallback: "toggle" },
    openAs:      { options: ["panel", "window"], fallback: "panel" },
    windowWidth: { range: [480, 1000], fallback: 580 },
    windowHeight:{ range: [460, 1000], fallback: 680 },
    density:     { options: ["compact", "comfortable", "spacious"], fallback: "comfortable" },
    cornerRadius:{ range: [0, 20], fallback: 6 },
    frame:       { bool: true, fallback: false },
    frameGradient: { bool: true, fallback: true },
    frameColor:  { options: ["accent", "first", "middle", "last"], fallback: "accent" },
    fontScale:   { range: [80, 150], fallback: 100 },
    surfaceTint: { range: [0, 30], fallback: 0 },
    panelOpacity:{ range: [50, 100], fallback: 96 },
    customBg:    { hex: true, fallback: "#141414" },
    customFg:    { hex: true, fallback: "#e0e0e0" },
    accentColor: { hex: true, fallback: "#ff6a1f" },
    // kept out of the UI: which look supplied the colors, the last one worn,
    // the undo state and your twenty saved looks
    presetColors:{ options: ["", "monochrome", "palette", "borders"], fallback: "" },
    lastLook:    { text: true, maxLength: 16, fallback: "" },
    undoLook:    { look: true, fallback: null },
    savedLooks:  { slots: true, fallback: null }
};

// style keys the bar starts with: Horizon, one plain band
var styleDefaults = {
    ends: "rounded", surface: "filled", fill: "solid", gradientTo: "accent", lines: "none",
    border: "subtle", borderWidth: 1, shadow: "none", shadowColor: "dark"
};

// colors stay yours when a look is applied; history travels with the bar, not the look
var KEEP = ["enabled", "colorMode", "customBg", "customFg", "accentColor", "savedLooks"];
var HISTORY = ["savedLooks", "lastLook", "undoLook", "presetColors"];
var SLOTS = 20;

function defaults() {
    var out = Style.defaults();
    for (var k in styleDefaults) out[k] = styleDefaults[k];
    for (var key in layoutSettings) {
        out[key] = layoutSettings[key].slots ? slots() : layoutSettings[key].fallback;
    }
    return out;
}

function slots() {
    var out = [];
    for (var i = 0; i < SLOTS; i++) out.push(null);
    return out;
}

// one look, without its history or saved slots: what undo and a slot remember
function snapshot(v) {
    if (!v || typeof v !== "object") return null;
    var d = defaults(), out = {};
    for (var k in d) {
        if (HISTORY.indexOf(k) >= 0 || v[k] === undefined) continue;
        out[k] = k in Style.settings ? Style.cleanValue(k, v[k]) : cleanLayout(k, v[k]);
    }
    return out;
}

function cleanLayout(key, v) {
    var s = layoutSettings[key];
    // missing (older or hand-written settings): the default, not "off"
    if (v === undefined || v === null) return s.slots ? slots() : s.fallback;
    if (s.bool) return v === true || v === "true";
    if (s.hex) return typeof v === "string" && /^#[0-9a-fA-F]{6}$/.test(v) ? v.toLowerCase() : s.fallback;
    if (s.text) return typeof v === "string"
        ? v.replace(/[\u0000-\u001f\u007f<>]/g, "").slice(0, s.maxLength || 256) : s.fallback;
    if (s.look) return snapshot(v);
    if (s.slots) {
        var arr = Array.isArray(v) ? v : [], out = [];
        for (var i = 0; i < SLOTS; i++) out.push(snapshot(arr[i]));
        return out;
    }
    if (s.range) {
        var n = typeof v === "number" ? v : parseFloat(v);
        return isFinite(n) ? Math.max(s.range[0], Math.min(s.range[1], Math.round(n))) : s.fallback;
    }
    return typeof v === "string" && s.options.indexOf(v) !== -1 ? v : s.fallback;
}

// every key checked; missing ones take their default
function clean(c) {
    var d = defaults();
    var had = c && typeof c === "object";
    var style = Style.clean(had ? c : {});
    var out = {};
    for (var k in d) out[k] = d[k];
    for (var sk in style) if (had && c[sk] !== undefined) out[sk] = style[sk];
    for (var lk in layoutSettings) out[lk] = cleanLayout(lk, had ? c[lk] : undefined);
    return out;
}

// just the parts a dock takes over when it follows the bar
function styleOf(c) {
    var out = {};
    for (var i = 0; i < Style.keys.length; i++) out[Style.keys[i]] = c[Style.keys[i]];
    out.opacity = c.opacity;
    out.radius = c.radius;
    out.style = c.colorMode === "monochrome" ? "monochrome" : c.colorMode === "custom" ? "custom" : "theme";
    out.customBg = c.customBg; out.customFg = c.customFg; out.accentColor = c.accentColor;
    return out;
}

// ---- ready made looks -------------------------------------------------------------
// Aequalyn's own catalogue (AequalynLooks.js). Each sets the keys it names; the rest of
// the look (not the colors) goes back to the defaults.

var looks = AequalynLooks.bar;
var lookByKey = {};
for (var li = 0; li < looks.length; li++) lookByKey[looks[li].key] = looks[li];

function applyLook(c, key) {
    var look = lookByKey[key];
    if (!look) return clean(c);
    var out = defaults();
    for (var i = 0; i < KEEP.length; i++) if (c && c[KEEP[i]] !== undefined) out[KEEP[i]] = c[KEEP[i]];
    for (var k in look.set) out[k] = look.set[k];
    return clean(out);
}

// remember where we came from, so one change can be undone
function withLook(c, key) {
    if (!lookByKey[key]) return clean(c || {});
    var out = applyLook(c, key);
    out.undoLook = snapshot(c);
    out.lastLook = key;
    return clean(out);
}

function withNextLook(c, step) {
    var at = c && c.lastLook ? lookByKey[c.lastLook] ? c.lastLook : lookOf(c || {}) : lookOf(c || {});
    if (at === "") at = looks[0].key;
    var i = 0;
    for (; i < looks.length; i++) if (looks[i].key === at) break;
    var next = looks[(i + (step < 0 ? looks.length - 1 : 1)) % looks.length];
    return withLook(c, next.key);
}

function withUndo(c) {
    if (!c || !c.undoLook) return clean(c || {});
    var out = defaults(), saved = c.undoLook;
    for (var k in saved) out[k] = saved[k];
    out.undoLook = snapshot(c);
    return clean(out);
}

function withSlot(c, op, index) {
    var i = Math.max(0, Math.min(SLOTS - 1, Number(index) || 0));
    var out = clean(c || {}), all = out.savedLooks;
    if (op === "save") all[i] = snapshot(out);
    else if (op === "clear") all[i] = null;
    else if (op === "load" && all[i]) {
        var saved = all[i], next = defaults();
        for (var k in saved) if (HISTORY.indexOf(k) < 0) next[k] = saved[k];
        for (var j = 0; j < KEEP.length; j++) if (out[KEEP[j]] !== undefined) next[KEEP[j]] = out[KEEP[j]];
        next.savedLooks = all;
        next.undoLook = snapshot(out);
        return clean(next);
    }
    out.savedLooks = all;
    return clean(out);
}

function lookOf(c) {
    if (!c) return "";
    for (var i = 0; i < looks.length; i++) {
        var want = applyLook(c, looks[i].key), same = true;
        for (var k in want) {
            if (KEEP.indexOf(k) >= 0 || HISTORY.indexOf(k) >= 0) continue;
            if (JSON.stringify(want[k]) !== JSON.stringify(c[k])) { same = false; break; }
        }
        if (same) return looks[i].key;
    }
    return "";
}

// which way pointed ends point, for a group of the bar
function dirFor(c, region) {
    var p = c.pointingBar || "right";
    if (p === "outward") return region === "left" ? "left" : (region === "right" ? "right" : "both");
    if (p === "inward") return region === "left" ? "right" : (region === "right" ? "left" : "both");
    return p;
}
