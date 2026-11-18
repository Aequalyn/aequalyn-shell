.pragma library
.import "../Draw.js" as Draw

// Sunset: gold on the left, through coral and rose, to violet on the right; the loud
// parts glow warmer and brighter.
var stops = [[255, 196, 92], [255, 128, 96], [236, 84, 128], [150, 82, 190]];
var color = {
    key: "sunset",
    label: "Sunset",
    about: "Gold through coral and rose to violet, the loud parts glowing brighter.",
    at(t, v, c) {
        const base = Draw.along(stops, t);
        const lvl = v >= 0 ? v : (typeof c.level === "number" ? c.level : 0.5);
        return Draw.mix(base, [255, 236, 200], Math.max(0, lvl - 0.6) * 0.6);
    }
};
