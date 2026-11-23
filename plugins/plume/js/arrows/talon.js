.pragma library

// A talon: a curved claw-like cursor with a fierce tip.
function outline() {
    const out = [[0, 0]];
    for (let i = 1; i <= 14; i++) {
        const t = i / 14;
        const y = 20 * t;
        const x = 2.2 * t + 4.8 * Math.sin(Math.PI * t) * Math.pow(t, 0.45);
        out.push([x, y]);
    }
    out.push([4.2, 22.5], [1.6, 20.2], [-0.8, 22.0], [-2.2, 19.0]);
    for (let i = 14; i >= 1; i--) {
        const t = i / 14;
        const y = 20 * t;
        const x = -1.2 * t - 3.2 * Math.sin(Math.PI * t) * Math.pow(1 - t * 0.35, 0.8);
        out.push([x, y]);
    }
    return out;
}

var arrow = {
    key: "talon",
    label: "Talon",
    about: "A curved claw-like arrow with a fierce, predatory tip.",
    points: outline()
};
