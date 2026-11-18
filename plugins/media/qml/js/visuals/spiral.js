.pragma library

// Spiral: an endless spiral, a logarithmic one, so turning it looks like flowing in
// forever: no start and no end, never a jump. The music pushes its arm out as it winds
// in, the lows at the edge, the highs towards the middle; louder turns faster.
var visual = {
    key: "spiral",
    label: "Spiral",
    about: "An endless spiral flowing inwards, its arm pushed out by the music; louder turns faster.",
    square: true,
    draw(g) {
        const { ctx, w, h, mem, st } = g;
        const cx = w / 2, cy = h / 2, R = Math.min(w, h) / 2 - 1;
        // its own angle: it only grows, so the turn never wraps back and never jumps
        mem.a = (mem.a || 0) + 0.035 + st.level * 0.09;
        if (mem.a > 1e6) mem.a -= 2 * Math.PI * 1e5;
        const turns = 4, n = 120;
        const k = Math.log(40) / (turns * 2 * Math.PI);    // a 40-fold shrink over its turns
        for (const arm of [0, Math.PI]) {
            const xs = [], ys = [];
            for (let i = 0; i < n; i++) {
                const t = i / (n - 1);                      // 0 at the edge .. 1 in the middle
                const theta = t * turns * 2 * Math.PI;
                const v = g.clamp(g.at(Math.round(t * 15), 16), 0, 1);
                const r = R * Math.exp(-k * theta) * (1 + 0.22 * v * (1 - t));
                const a = theta + mem.a + arm;
                xs.push(cx + Math.cos(a) * r);
                ys.push(cy + Math.sin(a) * r);
            }
            ctx.globalAlpha = 1;
            g.glowLine(xs, ys, true, 1.1);
        }
    }
};
