.pragma library
.import "../Draw.js" as Draw

// Aurora: green, teal and violet curtains drifting slowly across the visual, on their
// own time, brighter where the music is loud.
var stops = [[60, 230, 140], [40, 200, 200], [120, 120, 240], [200, 90, 220], [60, 230, 140]];
var color = {
    key: "aurora",
    label: "Aurora",
    about: "Green, teal and violet curtains drifting slowly across, brighter where it is loud.",
    at(t, v, c) {
        const drift = (Date.now() / 9000) % 1;
        const x = (t * 0.6 + drift + 0.15 * Math.sin(t * 6.28 + drift * 6.28)) % 1;
        const base = Draw.along(stops, x < 0 ? x + 1 : x);
        const lvl = v >= 0 ? v : (typeof c.level === "number" ? c.level : 0.5);
        return [base[0], base[1], base[2], 0.55 + 0.45 * lvl];
    }
};
