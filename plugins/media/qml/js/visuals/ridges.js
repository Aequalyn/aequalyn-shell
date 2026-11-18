.pragma library

// Ridges: the last moments stacked as lines, the newest in front, each hiding those
// behind it, like a pulsar's pulses printed one over another.
var visual = {
    key: "ridges",
    label: "Ridges",
    about: "The last moments stacked as hills, the newest in front, hiding those behind.",
    draw(g) {
        const { ctx, w, h, mem } = g;
        const n = 24, rows = 6;
        const now = [];
        for (let i = 0; i < n; i++) now.push(g.clamp(g.at(i, n), 0, 1));
        if (!mem.rows) mem.rows = [];
        mem.tick = (mem.tick || 0) + 1;
        if (mem.tick % 3 === 0 || mem.rows.length === 0) {
            mem.rows.unshift(now);
            if (mem.rows.length > rows) mem.rows.length = rows;
        } else mem.rows[0] = now;
        const step = h / (rows + 2);
        for (let r = mem.rows.length - 1; r >= 0; r--) {
            const base = h - 1 - r * step;
            const lift = h * 0.55;
            const xs = [], ys = [];
            for (let i = 0; i < n; i++) {
                // the middle rises most, as the pulses did
                const bell = Math.exp(-Math.pow((i / (n - 1) - 0.5) * 3, 2));
                xs.push(i * w / (n - 1));
                ys.push(base - mem.rows[r][i] * lift * (0.35 + 0.65 * bell));
            }
            ctx.beginPath();
            g.smooth(xs, ys);
            ctx.lineTo(w, h);
            ctx.lineTo(0, h);
            ctx.closePath();
            ctx.fillStyle = "rgba(0,0,0,0.85)";
            ctx.globalCompositeOperation = "destination-out";
            ctx.fill();
            ctx.globalCompositeOperation = "source-over";
            ctx.beginPath();
            g.smooth(xs, ys);
            ctx.lineWidth = r === 0 ? 1.4 : 1;
            ctx.strokeStyle = g.gradient(1 - r / (rows + 1));
            ctx.stroke();
        }
    }
};
