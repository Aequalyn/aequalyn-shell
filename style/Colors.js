.pragma library

// The shell's palette (ThemeSwitcher's theme, QML colors) in the painter's
// terms: { bg, fg, ac, hot, spectrum } as "#rrggbb". Shared by the bar, the
// docks and every preview in Atelier, so they all agree.

function hex(c) {
    if (!c) return "#000000";
    if (typeof c === "string") return c.length === 7 ? c.toLowerCase() : "#" + c.slice(-6).toLowerCase();
    function h(v) { return ("0" + Math.round(v * 255).toString(16)).slice(-2); }
    return "#" + h(c.r) + h(c.g) + h(c.b);
}

var mono = { bg: "#161616", fg: "#e0e0e0", ac: "#ffffff", hot: "#ff6b5e", spectrum: [] };

function fromTheme(t) {
    if (!t || !t.bgBase) return mono;
    var spectrum = [];
    // a theme's own gradient (palette.borderColors) when it has one, else its accents
    var own = t.borderColors && t.borderColors.length >= 2 ? Array.from(t.borderColors) : null;
    var list = own || [t.accentPrimary, t.accentCyan, t.accentGreen, t.accentOrange, t.accentRed];
    for (var i = 0; i < list.length; i++) {
        var c = hex(list[i]);
        if (spectrum.indexOf(c) < 0) spectrum.push(c);
    }
    return { bg: hex(t.bgBase), fg: hex(t.textPrimary), ac: hex(t.accentPrimary), hot: hex(t.accentRed), spectrum: spectrum };
}

// a style's color mode on top of the theme: theme, custom, monochrome
function forMode(t, mode, d) {
    var base = fromTheme(t);
    if (mode === "monochrome") return mono;
    if (mode === "custom" && d)
        return { bg: d.customBg || base.bg, fg: d.customFg || base.fg, ac: d.accentColor || base.ac, hot: base.hot, spectrum: [] };
    return base;
}

// ---- the widgets' colours, in a pattern ------------------------------------------------
//
// The bar's widgets can take the theme's colours in turn: a is its first colour (the
// accent), b its second, c its third. A pattern is the run they repeat in, widget after
// widget along the bar: "ab" is a b a b ..., "abb" is a b b a b b ..., "all" goes through
// every colour the theme has.
var patterns = [
    { key: "all",  label: "Every colour in turn" },
    { key: "a",    label: "All the accent" },
    { key: "ab",   label: "a b a b" },
    { key: "abb",  label: "a b b" },
    { key: "aab",  label: "a a b" },
    { key: "aabb", label: "a a b b" },
    { key: "abc",  label: "a b c" }
];
function patternKey(k) {
    for (var i = 0; i < patterns.length; i++) if (patterns[i].key === k) return k;
    return "all";
}
// the colour of the widget at `order` (0 is the first along the bar), from the theme's
// colours (fromTheme(t).spectrum), "" when there are none
function inkAt(spectrum, pattern, order) {
    if (!spectrum || spectrum.length === 0 || order < 0) return "";
    var k = patternKey(pattern);
    if (k === "all") return spectrum[order % spectrum.length];
    var c = k.charCodeAt(order % k.length) - 97;           // a = 0, b = 1, c = 2
    return spectrum[c % spectrum.length];
}
