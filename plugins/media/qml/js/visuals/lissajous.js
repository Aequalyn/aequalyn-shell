.pragma library

// Lissajous: the sound wave drawn against itself a moment later, as an X-Y scope
// does: a tone draws a loop, a chord a knot, noise a cloud.
var visual = {
    key: "lissajous",
    label: "Lissajous",
    about: "The wave against itself a moment later, as an X-Y scope draws it: loops, knots, clouds.",
    scope: true,
    square: true,
    draw(g) {
        const { ctx, w, h, levels } = g;
        const m = levels.length;
        const cx = w / 2, cy = h / 2, r = Math.min(w, h) / 2 - 1.5;
        ctx.strokeStyle = g.color(0.5, -1, 0.18);
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.arc(cx, cy, r, 0, 2 * Math.PI);
        ctx.stroke();
        if (m < 8) return;
        const lag = Math.max(1, Math.floor(m / 6));
        const xs = [], ys = [];
        for (let i = 0; i + lag < m; i++) {
            xs.push(cx + g.clamp(Number(levels[i]) || 0, -1, 1) * r);
            ys.push(cy - g.clamp(Number(levels[i + lag]) || 0, -1, 1) * r);
        }
        g.glowLine(xs, ys, true, 1.2);
    }
};
