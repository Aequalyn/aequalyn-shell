.pragma library

// A comet: a pointed head with a flared tail.
function outline() {
    const out = [[0, 0]];
    for (let i = 1; i <= 10; i++) { const t = i / 10; out.push([4.8 * Math.sin(t * Math.PI / 2) * (0.7 + 0.3 * t), 17.5 * t]); }
    out.push([6.2, 20.5], [3.2, 18.8], [0, 22.5], [-3.2, 18.8], [-6.2, 20.5]);
    for (let i = 10; i >= 1; i--) { const t = i / 10; out.push([-4.8 * Math.sin(t * Math.PI / 2) * (0.7 + 0.3 * t), 17.5 * t]); }
    return out;
}

var arrow = {
    key: "comet",
    label: "Comet",
    about: "A pointed comet with a flared tail.",
    upright: true,
    points: outline()
};
