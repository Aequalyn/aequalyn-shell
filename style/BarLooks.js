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
    edgeGap:     { range: [0, 30], fallback: 6 },
    floatGap:    { range: [0, 40], fallback: 0 },
    sideGap:     { range: [0, 200], fallback: 10 },
    padding:     { range: [0, 40], fallback: 6 },
    pillRoom:    { range: [0, 12], fallback: 0 },
    pillGap:     { range: [0, 12], fallback: 2 },
    mergeGap:    { range: [0, 60], fallback: 4 },
    fullExtra:   { range: [0, 16], fallback: 0 },
    fullInset:   { range: [0, 200], fallback: 8 },
    slim:        { range: [0, 12], fallback: 0 },
    radius:      { range: [0, 40], fallback: 10 },
    pillFit:     { bool: true, fallback: false },
    centerMin:   { range: [0, 600], fallback: 0 },
    mirrorSides: { bool: true, fallback: false },
    hover:       { options: ["none", "fill", "underline", "glow", "dot"], fallback: "fill" },
    hoverColor:  { options: ["text", "accent"], fallback: "text" },
    separators:  { options: ["none", "line", "dot", "slash"], fallback: "none" },
    dividers:    { bool: true, fallback: false },
    edgeLine:    { bool: true, fallback: false },
    colorMode:   { options: ["theme", "palette", "custom", "monochrome"], fallback: "theme" },
    centerStyle: { options: ["same", "tinted", "accent"], fallback: "same" },
    opacity:     { range: [10, 100], fallback: 100 },
    customBg:    { hex: true, fallback: "#141414" },
    customFg:    { hex: true, fallback: "#e0e0e0" },
    accentColor: { hex: true, fallback: "#ff6a1f" }
};

// style keys the bar starts with: Horizon, one plain band
var styleDefaults = {
    ends: "rounded", surface: "filled", fill: "solid", gradientTo: "accent", lines: "none",
    border: "subtle", borderWidth: 1, shadow: "none", shadowColor: "dark"
};

function defaults() {
    var out = Style.defaults();
    for (var k in styleDefaults) out[k] = styleDefaults[k];
    for (var key in layoutSettings) out[key] = layoutSettings[key].fallback;
    return out;
}

function cleanLayout(key, v) {
    var s = layoutSettings[key];
    // missing (older or hand-written settings): the default, not "off"
    if (v === undefined || v === null) return s.fallback;
    if (s.bool) return v === true || v === "true";
    if (s.hex) return typeof v === "string" && /^#[0-9a-fA-F]{6}$/.test(v) ? v.toLowerCase() : s.fallback;
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

// keys a look never touches: your colors stay yours
var KEEP = ["enabled", "colorMode", "customBg", "customFg", "accentColor"];

function applyLook(c, key) {
    var look = lookByKey[key];
    if (!look) return clean(c);
    var out = defaults();
    for (var i = 0; i < KEEP.length; i++) if (c && c[KEEP[i]] !== undefined) out[KEEP[i]] = c[KEEP[i]];
    for (var k in look.set) out[k] = look.set[k];
    return clean(out);
}

function lookOf(c) {
    for (var i = 0; i < looks.length; i++) {
        var want = applyLook(c, looks[i].key), same = true;
        for (var k in want) {
            if (KEEP.indexOf(k) >= 0) continue;
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
