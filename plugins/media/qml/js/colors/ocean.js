.pragma library
.import "../Draw.js" as Draw

// Ocean: deep blue where it is quiet, rising through teal to sea foam where it is
// loud, like a wave breaking.
var stops = [[20, 60, 140], [24, 130, 170], [60, 200, 190], [210, 250, 240]];
var color = {
    key: "ocean",
    label: "Ocean",
    about: "Deep blue when quiet, through teal, to sea foam when loud, like a wave breaking.",
    at(t, v, c) {
        const lvl = v >= 0 ? v : (typeof c.level === "number" ? c.level : 0.5);
        return Draw.along(stops, 0.15 + 0.85 * Math.max(0, Math.min(1, lvl * 0.8 + t * 0.2)));
    }
};
