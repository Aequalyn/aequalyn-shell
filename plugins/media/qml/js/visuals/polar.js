.pragma library

// Polar: the spectrum as a closed shape round the middle, its outline pushed out where
// the music is loud, mirrored so it stays balanced, filled faintly inside.
var visual = {
    key: "polar",
    label: "Polar",
    about: "The spectrum as a closed shape round the middle, swelling where the music is loud.",
    square: true,
    draw(g) {
        const { ctx, w, h } = g;
        const cx = w / 2, cy = h / 2, R = Math.min(w, h) / 2 - 1;
        const n = 40;
        const xs = [], ys = [];
        for (let i = 0; i <= n; i++) {
            const t = i / n;
            // mirrored: the left half the lows to highs, the right half back again
            const k = t < 0.5 ? t * 2 : (1 - t) * 2;
            const v = g.clamp(g.at(Math.round(k * 15), 16), 0, 1);
            const a = t * 2 * Math.PI - Math.PI / 2;
            const r = R * (0.35 + 0.65 * v);
            xs.push(cx + Math.cos(a) * r);
            ys.push(cy + Math.sin(a) * r);
        }
        ctx.beginPath();
        g.smooth(xs, ys);
        ctx.closePath();
        ctx.fillStyle = g.color(0.5, -1, 0.18);
        ctx.fill();
        g.glowLine(xs, ys, true, 1.1);
    }
};
