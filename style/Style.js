.pragma library
.import "Paint.js" as Paint
.import "Trace.js" as Trace
.import "parts/Ends.js" as Ends
.import "parts/Surfaces.js" as Surfaces
.import "parts/Lines.js" as Lines
.import "parts/Ornaments.js" as Ornaments

// How a dock's body looks: the settings for it and their options,
// and the parameters Paint.js draws from. Plain functions, so they can be tested.
//
// A dock's body is one shape: its ends (parts/Ends.js), what it is made of
// (parts/Surfaces.js), its edge (parts/Lines.js) and decoration (parts/Ornaments.js).

function keysOf(mod) { var out = []; for (var i = 0; i < mod.list.length; i++) out.push(mod.list[i].key); return out; }
function labelsOf(mod) { var out = {}; for (var i = 0; i < mod.list.length; i++) out[mod.list[i].key] = mod.list[i].label; return out; }
function aboutsOf(mod) {
    var out = {};
    for (var i = 0; i < mod.list.length; i++) if (mod.list[i].about) out[mod.list[i].key] = mod.list[i].about;
    return out;
}
function keysWith(mod, flag, value) {
    var out = [];
    for (var i = 0; i < mod.list.length; i++) if (mod.list[i][flag] === value) out.push(mod.list[i].key);
    return out;
}

var ends = { options: keysOf(Ends), labels: labelsOf(Ends), abouts: aboutsOf(Ends) };
var surfaces = { options: keysOf(Surfaces), labels: labelsOf(Surfaces), abouts: aboutsOf(Surfaces) };
var lines = { options: keysOf(Lines), labels: labelsOf(Lines), abouts: aboutsOf(Lines) };
var ornaments = { options: keysOf(Ornaments), labels: labelsOf(Ornaments), abouts: aboutsOf(Ornaments) };
var pointingEnds = keysWith(Ends, "pointing", true);
var leaningSurfaces = keysWith(Surfaces, "leans", true);
var noGradient = keysWith(Surfaces, "noGradient", true);
var noTexture = keysWith(Surfaces, "noTexture", true);
var noDepth = keysWith(Surfaces, "noDepth", true);
var colorlessLines = keysWith(Lines, "usesColor", false);
var widthlessLines = keysWith(Lines, "usesWidth", false);

// every style setting: [allowed values] or [min, max] for numbers, and the default
var settings = {
    ends:        { options: ends.options, fallback: "rounded" },
    pointing:    { options: ["right", "left", "both"], fallback: "right" },
    flatSide:    { options: ["none", "edge", "windows"], fallback: "none" },
    surface:     { options: surfaces.options, fallback: "filled" },
    fill:        { options: ["solid", "gradient", "glass"], fallback: "gradient" },
    gradientTo:  { options: ["accent", "palette", "spectrum", "lighter", "darker"], fallback: "spectrum" },
    gradientAcross: { bool: true, fallback: false },
    pattern:     { options: ["none", "stripes", "dots", "grid"], fallback: "none" },
    depth:       { options: ["flat", "raised", "sunken"], fallback: "flat" },
    lines:       { options: lines.options, fallback: "solid" },
    border:      { options: ["subtle", "text", "accent"], fallback: "subtle" },
    borderWidth: { range: [1, 4], fallback: 1 },
    railSide:    { options: ["windows", "edge", "both"], fallback: "windows" },
    outlineGradient: { bool: true, fallback: true },
    outlineGradientTo: { options: ["lighter", "accent", "palette", "spectrum"], fallback: "spectrum" },
    ornaments:   { options: ornaments.options, fallback: "none" },
    shadow:      { options: ["none", "soft", "strong"], fallback: "soft" },
    shadowColor: { options: ["dark", "accent"], fallback: "dark" }
};
var keys = [];
for (var sk in settings) keys.push(sk);

function defaults() {
    var out = {};
    for (var i = 0; i < keys.length; i++) out[keys[i]] = settings[keys[i]].fallback;
    return out;
}

// one value, checked
function cleanValue(key, v) {
    var s = settings[key];
    if (!s) return undefined;
    if (s.bool) return v === true || v === "true";
    if (s.range) {
        var n = typeof v === "number" ? v : parseFloat(v);
        return isFinite(n) ? Math.max(s.range[0], Math.min(s.range[1], Math.round(n))) : s.fallback;
    }
    return typeof v === "string" && s.options.indexOf(v) !== -1 ? v : s.fallback;
}

// the style keys of a dock, each checked. `outline: true` from older configs becomes
// an accent line, so a dock looks the same after an update
function clean(d) {
    var out = {};
    var had = d && typeof d === "object";
    for (var i = 0; i < keys.length; i++) {
        var k = keys[i];
        out[k] = cleanValue(k, had ? d[k] : undefined);
    }
    if (had && d.outline === true && d.border === undefined) out.border = "accent";
    // Scroll ends were round ends with the Scrolls ornament's curls: they are that now
    if (had && d.ends === "scroll") {
        out.ends = "capsule";
        if (d.ornaments === undefined || d.ornaments === "none") out.ornaments = "scrolls";
    }
    return out;
}

// just the style part of a dock (for undo)
function styleOf(d) {
    var out = {};
    for (var i = 0; i < keys.length; i++) out[keys[i]] = d[keys[i]];
    return out;
}

// ---- colors ----------------------------------------------------------------------------

function rgb(c) {
    if (c && typeof c === "object" && typeof c.r === "number") return [c.r * 255, c.g * 255, c.b * 255];
    var h = typeof c === "string" ? c : "";
    if (!/^#[0-9a-fA-F]{6}$/.test(h)) return [128, 128, 128];
    return [parseInt(h.substr(1, 2), 16), parseInt(h.substr(3, 2), 16), parseInt(h.substr(5, 2), 16)];
}
function mix(a, b, t) { return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t]; }
function css(c, a) {
    var al = typeof a === "number" ? Math.max(0, Math.min(1, a)) : 1;
    return "rgba(" + Math.round(c[0]) + "," + Math.round(c[1]) + "," + Math.round(c[2]) + "," + al + ")";
}
function lum(c) { return (0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]) / 255; }

// ---- the theme's colors, for gradients -------------------------------------------------
//
// pal.spectrum is the theme's own colors in order (see Service.qml). A gradient that uses
// more than the accent runs through all of them. Without any (Custom and Monochrome colors,
// or a theme with none) it runs through shades of the accent instead, so a Monochrome dock
// stays without a hue.

// every color of the theme, in its order: [r, g, b] each, two at least
function spectrumOf(pal, mine) {
    const out = (pal && Array.isArray(pal.spectrum) ? pal.spectrum : []).filter(c => /^#[0-9a-fA-F]{6}$/.test(c)).map(c => rgb(c));
    if (out.length === 1) out.unshift(mine);
    if (out.length === 0) return [mine, mix(mine, [255, 255, 255], 0.45), mix(mine, [0, 0, 0], 0.4)];
    return out;
}
// one color of the theme next to the accent (the second one, like Vitrine's "Next theme color")
function paletteOf(pal, mine) {
    const src = pal && Array.isArray(pal.spectrum) ? pal.spectrum.filter(c => /^#[0-9a-fA-F]{6}$/.test(c)) : [];
    if (src.length === 0) return mix(mine, [255, 255, 255], 0.45);
    return rgb(src[src.length > 1 ? 1 : 0]);
}

// ---- where the dock is -----------------------------------------------------------------

// which side of the shape faces the windows, in the painter's terms (start = its top
// before the flip for side docks)
function innerFor(edge) { return edge === "bottom" || edge === "right" ? "start" : "end"; }
function isVertical(edge) { return edge === "left" || edge === "right"; }

// how much room the canvas leaves around the shape, for shadows, glows and ornaments
function marginFor(d) {
    var Ln = Lines.byKey[d.lines] || {};
    var S = Surfaces.byKey[d.surface] || {};
    if (d.shadow === "strong") return 16;
    if (d.shadow === "soft" || Ln.glow === true || S.ownShadow === true) return 11;
    return 3;
}

// the corner radius the painter gets: capsule ends are fully round, rounded ends use
// the Corner radius setting, every other end draws its own corners
function radiusOf(d) {
    if (d.ends === "capsule") return 999;
    if (d.ends === "rounded") return typeof d.radius === "number" ? d.radius : 16;
    return 0;
}

// ---- the parameters Paint.js draws from ------------------------------------------------
//
// d: the dock's settings, pal: { bg, fg, ac, hot } as "#rrggbb", w/h: the canvas,
// margin: room around the shape, opts: { edge, tone (accent override) }

function params(d, pal, w, h, margin, opts) {
    var o = opts || {};
    var edge = o.edge || "bottom";
    var opacity = typeof d.opacity === "number" ? d.opacity : 90;
    var base = rgb(pal.bg), fg = rgb(pal.fg), mine = rgb(o.tone || pal.ac);
    var S = Surfaces.byKey[d.surface] || Surfaces.byKey.filled;
    var k = typeof S.fill === "number" ? S.fill : 1;
    if (d.fill === "glass") k *= 0.55;
    var alpha = k * opacity / 100;
    var ramp = spectrumOf(pal, mine);
    var target = d.gradientTo === "lighter" ? mix(base, [255, 255, 255], 0.2)
               : d.gradientTo === "darker" ? mix(base, [0, 0, 0], 0.35)
               : d.gradientTo === "palette" ? mix(base, paletteOf(pal, mine), 0.45)
               : d.gradientTo === "spectrum" ? mix(base, ramp[ramp.length - 1], 0.45)
               : mix(base, mine, 0.45);
    // Theme colors: the fill runs through several of them, each tinted into the dock's color
    var gradientOn = d.fill === "gradient" && S.noGradient !== true;
    var fillStops = gradientOn && d.gradientTo === "spectrum"
        ? ramp.map(function (c) { return css(mix(base, c, 0.45), alpha); }) : [];
    var Ln = Lines.byKey[d.lines] || Lines.byKey.none;
    var lw = 0, lineBase = mine, lineAlpha = 0.85;
    if (Ln.usesColor !== false) {
        lw = d.borderWidth;
        if (d.border === "text") { lineBase = fg; lineAlpha = 0.55; }
        else if (d.border === "subtle") { lineBase = fg; lineAlpha = 0.16; }
    }
    var lineColor = Ln.usesColor !== false ? css(lineBase, lineAlpha) : "";
    var grad = d.outlineGradient === true;
    var fadeTo = d.outlineGradientTo;
    var lineGrad = [], markGrad = [];
    if (grad && fadeTo === "spectrum") {
        // lines and accents run through the theme's colors
        if (lw > 0) lineGrad = [css(lineBase, lineAlpha)].concat(ramp.map(function (c) { return css(c, 0.95); }));
        markGrad = [css(mine, 0.9)].concat(ramp.map(function (c) { return css(c, 0.9); }));
    } else if (grad) {
        // the second color: a lighter shade (the default), the accent, or the theme's next color
        var lineEnd = fadeTo === "accent" ? css(mine, 0.95)
                    : fadeTo === "palette" ? css(paletteOf(pal, mine), 0.95)
                    : css(mix(lineBase, [255, 255, 255], 0.55), Math.max(lineAlpha, 0.6));
        var markEnd = fadeTo === "palette" ? css(paletteOf(pal, mine), 0.9)
                    : css(mix(mine, [255, 255, 255], 0.55), 0.9);
        if (lw > 0) lineGrad = [css(lineBase, lineAlpha), lineEnd];
        markGrad = [css(mine, 0.9), markEnd];
    }

    var blur = 0, shadow = "";
    // the painted shadow/glow blur can be turned off by the caller: when the
    // bar is hidden, or when the user disables blur. Any of these aliases works.
    var blurOn = true;
    if (o) {
        var aliases = ["blur", "shadowBlur", "shadows", "shadow", "blurEnabled"];
        for (var bi = 0; bi < aliases.length; bi++) {
            var bv = o[aliases[bi]];
            if (bv === false || bv === 0 || bv === "false" || bv === "none") blurOn = false;
        }
        if (o.barHidden === true || o.barVisible === false || o.barShown === false) blurOn = false;
    }
    if (d.shadow !== "none" && blurOn) {
        if (d.shadowColor === "accent") { blur = d.shadow === "strong" ? 14 : 8; shadow = css(mine, d.shadow === "strong" ? 0.8 : 0.55); }
        else { blur = d.shadow === "strong" ? 14 : 8; shadow = css([0, 0, 0], d.shadow === "strong" ? 0.55 : 0.35); }
    }
    if (blurOn && Ln.glow === true && blur === 0) { blur = 8; shadow = css(mine, 0.5); }
    if (blurOn && S.ownShadow === true && blur === 0) { blur = 10; shadow = css([0, 0, 0], 0.5); }
    blur = Math.min(blur, Math.max(0, margin - 2));
    if (!blurOn) { blur = 0; shadow = ""; }

    var inner = innerFor(edge);
    var edgeSide = inner === "start" ? "end" : "start";
    var flat = d.flatSide === "edge" ? edgeSide : (d.flatSide === "windows" ? inner : "");
    var lightBase = lum(base) > 0.6;
    var dense = S.noDepth !== true;
    return {
        width: w, height: h, margin: margin, vertical: isVertical(edge),
        dir: d.pointing === "left" || d.pointing === "both" ? d.pointing : "right",
        flat: flat,
        pattern: dense && d.pattern !== "none" ? d.pattern : "", patternColor: css(fg, 0.07),
        depth: dense && d.depth !== "flat" ? d.depth : "",
        light: lightBase ? css([255, 255, 255], 0.7) : css([255, 255, 255], 0.16),
        dark: lightBase ? css([0, 0, 0], 0.18) : css([0, 0, 0], 0.35),
        r: radiusOf(d), ends: d.ends,
        edge: "", concave: false, inner: inner,
        surface: d.surface, lines: d.lines, ornament: d.ornaments,
        fill: css(base, alpha),
        fill2: gradientOn ? css(target, alpha) : "",
        fillStops: fillStops,
        gradAcross: d.gradientAcross === true,
        glass: d.fill === "glass" && S.noGradient !== true,
        glassColor: lightBase ? css([255, 255, 255], 0.8) : css(fg, 0.22),
        line: lineColor, lineWidth: lw, lineGrad: lineGrad, markGrad: markGrad, lineAngle: 0,
        mark: css(mine, 0.9), markWidth: Math.max(1, d.borderWidth), bracket: 7,
        second: css(mix(base, mine, 0.28), alpha),
        splitColor: css(mix(base, mine, 0.5), alpha),
        frameColors: [css(mix(mine, [255, 255, 255], 0.55)), css(mine), css(mix(mine, [0, 0, 0], 0.45)), css(mix(mine, [255, 255, 255], 0.3))],
        velvetSheen: css(mix(base, lightBase ? [255, 255, 255] : mine, lightBase ? 0.35 : 0.3), alpha),
        head: css(mix(base, mine, 0.7), Math.max(alpha, 0.85)),
        metal: [css(mix(base, [255, 255, 255], lightBase ? 0.5 : 0.22), alpha), css(base, alpha),
                css(mix(base, [0, 0, 0], lightBase ? 0.12 : 0.3), alpha), css(mix(base, [255, 255, 255], lightBase ? 0.25 : 0.1), alpha)],
        frost: css(lightBase ? [255, 255, 255] : mix(base, [255, 255, 255], 0.35), lightBase ? 0.55 : 0.32 * opacity / 100),
        key: css(lightBase ? mix(base, [0, 0, 0], 0.4) : mix(base, mine, 0.55), Math.max(alpha, 0.6)),
        railSide: d.railSide,
        shadow: shadow, shadowBlur: blur, shadowShift: 0
    };
}

// ---- room for the icons ------------------------------------------------------------------
//
// Pointed, notched and curled ends reach into the dock. This measures how far, on the
// shape's real outline, across the band the icons sit in, so the first and last icon
// never touch the end. Remembered per kind of end and thickness.
var roomCache = {};
// ornaments that sit inside each end (Scrolls, Crown, Laurels), as a share of the thickness
var ORNAMENT_ROOM = { scrolls: 0.62, crown: 0.72, laurels: 0.55 };
function endRoom(d, thick, band) {
    var e = Ends.byKey[d.ends];
    var curls = typeof ORNAMENT_ROOM[d.ornaments] === "number";
    if (!e || ((d.ends === "rounded" || d.ends === "square") && !curls)) return 0;
    var r = Math.min(radiusOf(d), thick / 2);
    var dir = d.pointing === "left" || d.pointing === "both" ? d.pointing : "right";
    var key = d.ends + "|" + dir + "|" + Math.round(thick) + "|" + Math.round(band) + "|" + r + "|" + d.ornaments;
    if (roomCache[key] !== undefined) return roomCache[key];
    var L = 600, T = thick;
    var tr = Trace.trace(function (c) { Paint.outline(c, 0, 0, L, T, r, d.ends, "", "", dir, "end"); });
    var pts = tr.pts, worst = 0;
    for (var row = 0; row <= 12; row++) {
        var v = band + (T - 2 * band) * row / 12, xs = [];
        for (var i = 0; i < pts.length; i++) {
            var p = pts[i], q = pts[(i + 1) % pts.length];
            if ((p[1] <= v && q[1] > v) || (q[1] <= v && p[1] > v)) xs.push(p[0] + (q[0] - p[0]) * (v - p[1]) / (q[1] - p[1]));
        }
        xs.sort(function (a, b) { return a - b; });
        for (var j = 0; j + 1 < xs.length; j += 2) {
            if (xs[j] <= L / 2 && xs[j + 1] >= L / 2) worst = Math.max(worst, xs[j], L - xs[j + 1]);
        }
    }
    // ornaments that sit inside each end
    if (curls) worst = Math.max(worst, T * ORNAMENT_ROOM[d.ornaments]);
    var out = Math.ceil(worst > 0.5 ? worst + 2 : 0);
    roomCache[key] = out;
    return out;
}
