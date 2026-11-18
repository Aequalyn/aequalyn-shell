.pragma library

// Spiral: the spectrum wound from the middle outwards, the lows inside, the highs at
// the edge, each point pushed out as loud as it is, the whole turning slowly.
var visual = {
    key: "spiral",
    label: "Spiral",
    about: "The spectrum wound from the middle out, lows inside, highs at the edge, turning.",
    square: true,
    draw(g) {
        const { ctx, w, h, st } = g;
        const cx = w / 2, cy = h / 2, R = Math.min(w, h) / 2 - 1;
        const n = 48, turns = 2.2;
        const xs = [], ys = [];
        for (let i = 0; i < n; i++) {
            const t = i / (n - 1);
            const a = t * turns * 2 * Math.PI + st.phase * 0.4;
            const r = R * (0.12 + 0.7 * t) + g.clamp(g.at(i, n), 0, 1) * R * 0.25;
            xs.push(cx + Math.cos(a) * r);
            ys.push(cy + Math.sin(a) * r);
        }
        g.glowLine(xs, ys, true, 1.1);
    }
};
