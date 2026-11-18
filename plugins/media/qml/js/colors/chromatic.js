.pragma library
.import "../Draw.js" as Draw

// Chromatic: every pitch its own hue, the low notes red, the high ones violet, and
// each as bright and as rich as it is loud: quiet notes stay pale and dim.
var color = {
    key: "chromatic",
    label: "Chromatic",
    about: "A hue per pitch, lows red to highs violet, each as bright and rich as it is loud.",
    at(t, v, c) {
        const lvl = v >= 0 ? v : (typeof c.level === "number" ? c.level : 0.5);
        return Draw.hsl(0.78 * t, 0.25 + 0.7 * lvl, 0.32 + 0.33 * lvl);
    }
};
