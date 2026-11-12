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
    var list = [t.accentPrimary, t.accentCyan, t.accentGreen, t.accentOrange, t.accentRed];
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
