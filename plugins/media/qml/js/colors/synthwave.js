.pragma library
.import "../Draw.js" as Draw

// Synthwave: hot pink and electric cyan, side by side in turns across the visual, the
// loud parts lit up to a glow.
var pink = [255, 60, 180], cyan = [40, 230, 255];
var color = {
    key: "synthwave",
    label: "Synthwave",
    about: "Hot pink and electric cyan in turns across, the loud parts lit up to a glow.",
    at(t, v, c) {
        const k = 0.5 + 0.5 * Math.sin(t * Math.PI * 4);
        const base = Draw.mix(pink, cyan, k);
        const lvl = v >= 0 ? v : (typeof c.level === "number" ? c.level : 0.5);
        return Draw.mix(base, [255, 255, 255], Math.max(0, lvl - 0.7));
    }
};
