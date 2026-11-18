.pragma library
.import "../Draw.js" as Draw

// Fire: embers when quiet, deep red rising through orange to a white-hot yellow when
// loud.
var stops = [[90, 16, 8], [200, 40, 16], [250, 120, 20], [255, 210, 80], [255, 250, 220]];
var color = {
    key: "fire",
    label: "Fire",
    about: "Embers when quiet, deep red through orange to white-hot yellow when loud.",
    at(t, v, c) {
        const lvl = v >= 0 ? v : (typeof c.level === "number" ? c.level : 0.5);
        return Draw.along(stops, Math.max(0, Math.min(1, lvl)));
    }
};
