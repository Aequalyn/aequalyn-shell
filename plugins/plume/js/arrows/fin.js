.pragma library

// A fin: a sleek, fast silhouette inspired by a shark fin.
function outline() {
    const out = [[0, 0]];
    for (let i = 1; i <= 16; i++) {
        const t = i / 16;
        const y = 21 * t;
        const x = 7.2 * Math.pow(t, 0.55) * Math.pow(1 - t * 0.18, 1.2);
        out.push([x, y]);
    }
    out.push([3.8, 22.8], [0, 20.2], [-2.4, 22.0]);
    for (let i = 16; i >= 1; i--) {
        const t = i / 16;
        const y = 21 * t;
        const x = -2.6 * Math.pow(t, 0.8) * (0.6 + 0.4 * (1 - t));
        out.push([x, y]);
    }
    return out;
}

var arrow = {
    key: "fin",
    label: "Fin",
    about: "A sleek fin-shaped arrow with fast, flowing lines.",
    upright: true,
    points: outline()
};
