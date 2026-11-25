.pragma library
.import "Style.js" as Style

// The bar's or a dock's look, worn by something that is not one: a Showcase card or the
// cursor made in Plume. They have the same surfaces, lines and ornaments under the same
// names, so those are taken as they are; only a shape's name, and which side is which,
// need translating. Plain functions, so they can be tested.
//
// A source is { style, edge, mode }: style has every Style.js key (cleaned) with the
// opacity, radius, barTint, paletteUse, outlineGradientDir, shadowDir and accentCap that go
// with them; edge is where on the screen it is; mode is its color mode.

function source(s, edge, mode) {
    var style = Style.clean(s);
    style.opacity = typeof s.opacity === "number" ? s.opacity : 100;
    style.radius = typeof s.radius === "number" ? s.radius : 10;
    style.barTint = typeof s.barTint === "number" ? s.barTint : 0;
    style.paletteUse = s.paletteUse === "fill" ? "fill" : "accent";
    style.outlineGradientDir = ["diagonal", "across", "theme"].indexOf(s.outlineGradientDir) >= 0 ? s.outlineGradientDir : "along";
    style.shadowDir = s.shadowDir === "windows" ? "windows" : "around";
    style.accentCap = ["start", "end", "both"].indexOf(s.accentCap) >= 0 ? s.accentCap : "none";
    return { style: style, edge: ["bottom", "left", "right"].indexOf(edge) >= 0 ? edge : "top",
             mode: ["palette", "borders", "custom", "monochrome"].indexOf(mode) >= 0 ? mode : "theme" };
}

// how much of the accent is in the fill (as Style.params has it)
function tintOf(style) { return Math.min(0.6, (style.barTint || 0) / 100 + (style.paletteUse === "fill" ? 0.22 : 0)); }

// the side of a thing that faces the windows, and the side at the screen's edge
var across = { top: ["bottom", "top"], bottom: ["top", "bottom"], left: ["right", "left"], right: ["left", "right"] };
function sideOf(which, edge) {
    if (which === "both") return "both";
    return (across[edge] || across.top)[which === "edge" ? 1 : 0];
}

// ---- a Showcase card ---------------------------------------------------------------------

// the ends whose card has another name (Showcase's own cloud, tab and cartouche are other shapes)
var frames = { capsule: "pill", chamfer: "cut", tab: "tabbed", cloud: "puff", cartouche: "carved" };
// and the cards no end is like: the nearest one
var cardEnds = { ticket: "bite", arch: "dome", ogee: "dome", crest: "fleur", hexagon: "arrow", polaroid: "square",
                 circle: "capsule", scroll: "capsule", cloud: "scallop", tab: "stepped", cartouche: "brace" };
for (var fk in frames) cardEnds[frames[fk]] = fk;

// Showcase's settings (its Shape, Surface, Lines and Ornaments tabs), as the source has them
function card(src) {
    var s = src.style;
    var flat = s.flatSide === "none" ? "none" : sideOf(s.flatSide, src.edge);
    return {
        frame: frames[s.ends] || s.ends,
        pointing: s.pointing,
        flatCorners: flat === "top" || flat === "bottom" ? flat : "none",
        radius: s.radius,
        surface: s.surface, cardOpacity: s.opacity,
        fill: s.fill, gradientTo: s.gradientTo, gradientDir: s.gradientAcross ? "down" : "corner",
        pattern: s.pattern, depth: s.depth,
        shadow: s.shadow === "none" ? "none" : (s.shadowColor === "accent" ? "glow" : (s.shadow === "strong" ? "deep" : "soft")),
        lines: s.lines, border: s.border, borderWidth: s.borderWidth, railSide: sideOf(s.railSide, src.edge),
        outlineGradient: s.outlineGradient, outlineGradientTo: s.outlineGradientTo,
        ornaments: s.ornaments,
        followed: s, followedEdge: src.edge
    };
}

// the other way: Showcase's settings as a source, for a bar at `edge`; null without a card
function fromCard(c, edge) {
    if (!c || c.frame === "none") return null;
    var sides = across[edge] || across.top;
    function which(side) { return side === sides[1] ? "edge" : "windows"; }
    return source({
        ends: cardEnds[c.frame] || c.frame, pointing: c.pointing,
        flatSide: c.flatCorners === "none" || (edge === "left" || edge === "right") ? "none" : which(c.flatCorners),
        radius: Math.min(24, c.radius), opacity: Math.max(10, c.cardOpacity),
        surface: c.surface, fill: c.fill, gradientTo: c.gradientTo, gradientAcross: c.gradientDir === "down",
        pattern: c.pattern, depth: c.depth,
        shadow: c.shadow === "none" ? "none" : (c.shadow === "deep" || c.shadow === "lifted" ? "strong" : "soft"),
        shadowColor: c.shadow === "glow" ? "accent" : "dark",
        lines: c.lines, border: c.border, borderWidth: Math.min(4, c.borderWidth),
        railSide: c.railSide === "both" ? "both" : which(c.railSide),
        outlineGradient: c.outlineGradient, outlineGradientTo: c.outlineGradientTo, ornaments: c.ornaments
    }, edge, c.colorMode);
}

// ---- the cursor --------------------------------------------------------------------------

// the arrow nearest to each kind of end, and how round its corners are
var arrows = {
    rounded: ["classic", -1], capsule: ["chunky", 100], square: ["classic", 0], chamfer: ["wedge", 0],
    slant: ["shard", 0], arrow: ["dart", 0], ribbon: ["chevron", 10], bite: ["barb", 20],
    leaf: ["leaf", 40], stepped: ["pixel", 0], tab: ["kite", 10], drop: ["teardrop", 40],
    swoop: ["fin", 30], bullet: ["bullet", 40], folded: ["prism", 0], zigzag: ["volt", 0],
    scallop: ["bloom", 40], bulge: ["chunky", 60], wave: ["feather", 40], brace: ["rune", 20],
    castle: ["pixel", 0], teeth: ["barb", 0], puzzle: ["club", 50], needle: ["needle", 0],
    cloud: ["club", 80], cartouche: ["kite", 20], fleur: ["spade", 30], plaque: ["diamond", 10],
    oval: ["teardrop", 100], stamp: ["crystal", 10], dome: ["bullet", 80], corbel: ["talon", 20]
};
// a bar can fade into the wallpaper; a cursor must not
var MIN_OPACITY = 75;
var caps = { start: "tip", end: "tail", both: "both" };
// a line's color, in the cursor's words
var lineColors = { subtle: "subtle", text: "foreground", accent: "accent", border: "border" };

// Plume's settings for the cursor, as the source has them
function cursor(src) {
    var s = src.style;
    var shape = arrows[s.ends] || arrows.rounded;
    var out = {
        cursorShape: shape[0],
        cursorRound: shape[1] < 0 ? Math.min(100, Math.round(s.radius * 4)) : shape[1],
        cursorSurface: s.surface, cursorFill: s.fill,
        cursorGradientDir: s.gradientAcross ? "across" : "along",
        cursorPattern: s.pattern, cursorDepth: s.depth,
        cursorOpacity: Math.max(MIN_OPACITY, s.opacity), cursorTint: Math.round(tintOf(s) * 100),
        cursorLine: s.lines, // the lines a bar draws in its accent whatever their color is set to
        cursorLineColor: Style.colorlessLines.indexOf(s.lines) >= 0 ? "accent" : (lineColors[s.border] || "subtle"), cursorLineWidth: s.borderWidth,
        cursorLineGradient: s.outlineGradient, cursorLineFadeDir: s.outlineGradientDir,
        cursorOrnament: s.ornaments, cursorCap: caps[s.accentCap] || "none",
        cursorShadow: s.shadow, cursorShadowColor: s.shadowColor,
        cursorShadowDir: s.shadowDir === "windows" ? "below" : "around",
        followed: s
    };
    // a cursor has to be found on a window of its own color: a bar's plain band has no
    // line and needs none, the cursor gets a quiet one
    if (s.lines === "none") { out.cursorLine = "solid"; out.cursorLineColor = "subtle"; out.cursorLineWidth = 1; out.cursorLineGradient = false; }
    return out;
}

// the other way: the cursor's settings as a source, for a bar at `edge`
var endOf = {};
for (var ak in arrows) if (!endOf[arrows[ak][0]]) endOf[arrows[ak][0]] = ak;
var gradients = { second: "accent", palette: "palette", accent: "accent", border: "border", lighter: "lighter", darker: "darker" };
var borders = { foreground: "text", accent: "accent", border: "border", border2: "border" };
function fromCursor(c, edge) {
    return source({
        ends: endOf[c.cursorShape] || "rounded", radius: Math.min(24, Math.round(c.cursorRound / 4)), opacity: c.cursorOpacity,
        surface: c.cursorSurface, fill: c.cursorFill, gradientTo: gradients[c.cursorGradientTo] || "accent",
        gradientAcross: c.cursorGradientDir === "across", pattern: c.cursorPattern, depth: c.cursorDepth,
        barTint: c.cursorTint, lines: c.cursorLine, border: borders[c.cursorLineColor] || "subtle", borderWidth: c.cursorLineWidth,
        outlineGradient: c.cursorLineGradient, outlineGradientTo: gradients[c.cursorLineFadeTo] || "accent",
        outlineGradientDir: c.cursorLineFadeDir, ornaments: c.cursorOrnament,
        accentCap: c.cursorCap === "tip" ? "start" : (c.cursorCap === "tail" ? "end" : c.cursorCap),
        shadow: c.cursorShadow === "none" || c.cursorShadow === "soft" ? c.cursorShadow : "strong", shadowColor: c.cursorShadowColor,
        shadowDir: c.cursorShadowDir === "below" ? "windows" : "around"
    }, edge, "theme");
}

// ---- the bar and the docks ---------------------------------------------------------------

// a source's look onto the bar, or onto a dock. colors: { mode, customBg, customFg,
// accentColor } to bring those along, or null to leave them
function bar(src, colors) {
    var out = { enabled: true };
    for (var k in src.style) out[k] = src.style[k];
    if (colors) {
        out.colorMode = colors.mode;
        if (colors.mode === "custom") { out.customBg = colors.customBg; out.customFg = colors.customFg; out.accentColor = colors.accentColor; }
    }
    return out;
}
function dock(src, colors) {
    var out = Style.styleOf(src.style);
    out.opacity = src.style.opacity; out.radius = Math.max(1, src.style.radius);
    if (colors) {
        out.style = colors.mode === "custom" || colors.mode === "monochrome" ? colors.mode : "theme";
        if (colors.mode === "custom") { out.customBg = colors.customBg; out.customFg = colors.customFg; out.accentColor = colors.accentColor; }
    }
    return out;
}

// The cursor's colors when they are followed: the bar's fill and accent when it wears its
// look too, otherwise your own choices with anything that is not the theme's replaced.
function cursorColors(cfg, shaped) {
    if (shaped) return { cursorColor: "background", cursorColor2: "accent" };
    var own = ["custom", "white", "black"];
    var out = {};
    if (own.indexOf(cfg.cursorColor) >= 0) out.cursorColor = "accent";
    if (own.indexOf(cfg.cursorColor2) >= 0) out.cursorColor2 = "foreground";
    if (own.indexOf(cfg.cursorLineColor) >= 0) out.cursorLineColor = "auto";
    return out;
}

// the trail's and the halo's color mode when colors are followed
function effectColors(mode, now) {
    if (mode === "palette") return "palette";
    if (mode === "borders") return "border";
    return ["theme", "palette", "border"].indexOf(now) >= 0 && mode === "theme" ? now : "theme";
}

// the colors a fill and a line run through, [r, g, b] each, as Style.params has them for a
// bar. base: the fill's color, line: the line's, t: { accent, palette, border } as lists
function fillStops(s, base, t) {
    var white = [255, 255, 255], black = [0, 0, 0], mix = Style.mix;
    if (s.fill !== "gradient") return [];
    var ramp = ramps(t), bor = t.border && t.border.length ? t.border : ramp;
    if (s.gradientTo === "spectrum") return ramp.map(function (c) { return mix(base, c, 0.45); });
    if (s.gradientTo === "border") return bor.length > 1 ? bor.map(function (c) { return mix(base, c, 0.45); }) : [base, mix(base, bor[0], 0.35)];
    var to = s.gradientTo === "lighter" ? mix(base, white, 0.2) : s.gradientTo === "darker" ? mix(base, black, 0.35)
           : s.gradientTo === "palette" ? mix(base, next(t), 0.45) : mix(base, t.accent, 0.45);
    return [base, to];
}
function lineStops(s, line, t) {
    var ramp = ramps(t), bor = t.border && t.border.length ? t.border : ramp;
    if (s.lines === "none") return [];
    if (!s.outlineGradient) return s.border === "border" && bor.length > 1 ? bor : [];
    if (s.outlineGradientTo === "spectrum") return [line].concat(ramp);
    if (s.outlineGradientTo === "border") return [line].concat(bor);
    if (s.outlineGradientTo === "accent") return [line, t.accent];
    if (s.outlineGradientTo === "palette") return [line, next(t)];
    return [line, Style.mix(line, [255, 255, 255], 0.55)];
}
function ramps(t) {
    var p = t.palette || [];
    if (p.length > 1) return p;
    if (p.length === 1) return [t.accent, p[0]];
    return [t.accent, Style.mix(t.accent, [255, 255, 255], 0.45), Style.mix(t.accent, [0, 0, 0], 0.4)];
}
function next(t) {
    var p = t.palette || [];
    return p.length === 0 ? Style.mix(t.accent, [255, 255, 255], 0.45) : p[p.length > 1 ? 1 : 0];
}
