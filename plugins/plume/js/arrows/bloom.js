.pragma library

// A blooming petal arrow: organic curves meeting a sharp tip.
function outline() {
    const out = [[0, 0]];
    const R = 18;
    for (let i = 1; i <= 18; i++) {
        const t = i / 18;
        const y = R * t;
        const bulb = Math.sin(Math.PI * t);
        const petal = 1 + 0.18 * Math.sin(Math.PI * t * 3);
        const x = 6.4 * Math.pow(bulb, 0.72) * petal;
        out.push([x, y]);
    }
    out.push([0, 21.5]);
    for (let i = 18; i >= 1; i--) {
        const t = i / 18;
        const y = R * t;
        const bulb = Math.sin(Math.PI * t);
        const petal = 1 + 0.18 * Math.sin(Math.PI * t * 3);
        const x = 6.4 * Math.pow(bulb, 0.72) * petal;
        out.push([-x, y]);
    }
    return out;
}

var arrow = {
    key: "bloom",
    label: "Bloom",
    about: "An organic petal arrow that blooms from a sharp tip.",
    upright: true,
    points: outline()
};
