.pragma library

// Bounce: a ball for each band, kicked up by the music and pulled back by gravity, so
// beats make them jump and they land in their own time.
var visual = {
    key: "bounce",
    label: "Bounce",
    about: "A ball per band, kicked up by the music and pulled back down by gravity.",
    draw(g) {
        const { ctx, h, mem } = g;
        const b = g.bands();
        const r = Math.max(1.2, Math.min(b.bw / 2, h / 6, 3.2));
        if (!mem.y || mem.y.length !== b.n) { mem.y = new Array(b.n).fill(0); mem.v = new Array(b.n).fill(0); }
        for (let i = 0; i < b.n; i++) {
            const lvl = g.clamp(g.at(i, b.n), 0, 1);
            // the music only pushes up; gravity does the rest
            if (lvl > mem.y[i] && mem.v[i] <= 0.02) mem.v[i] = (lvl - mem.y[i]) * 0.55 + 0.04;
            mem.v[i] -= 0.035;
            mem.y[i] = Math.max(0, mem.y[i] + mem.v[i]);
            if (mem.y[i] === 0 && mem.v[i] < 0) mem.v[i] = -mem.v[i] * 0.3;
            const x = i * (b.bw + b.gap) + b.bw / 2;
            const y = h - r - mem.y[i] * (h - 2 * r);
            ctx.fillStyle = g.color(i / (b.n - 1), lvl, 0.25);
            ctx.fillRect(x - 0.5, y, 1, h - y);
            ctx.fillStyle = g.color(i / (b.n - 1), lvl);
            ctx.beginPath();
            ctx.arc(x, y, r, 0, 2 * Math.PI);
            ctx.fill();
        }
    }
};
