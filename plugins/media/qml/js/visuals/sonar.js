.pragma library

// Sonar: a sweep that goes round like a radar; where it passes, the music leaves blips,
// farther out the higher the sound, brighter the louder, fading as it moves on.
var visual = {
    key: "sonar",
    label: "Sonar",
    about: "A radar sweep that leaves blips where it passes, farther out for higher sounds.",
    square: true,
    draw(g) {
        const { ctx, w, h, mem } = g;
        const cx = w / 2, cy = h / 2, r = Math.min(w, h) / 2 - 1;
        mem.a = ((mem.a || 0) + 0.12) % (2 * Math.PI);
        if (!mem.blips) mem.blips = [];
        const n = 6;
        for (let i = 0; i < n; i++) {
            const v = g.clamp(g.at(i, n), 0, 1);
            if (v > 0.25) mem.blips.push({ a: mem.a, d: (i + 0.6) / n, v: v, life: 1 });
        }
        mem.blips = mem.blips.filter(b => (b.life -= 0.035) > 0).slice(-60);
        ctx.strokeStyle = g.color(0.5, -1, 0.2);
        ctx.lineWidth = 0.8;
        for (const k of [0.5, 1]) { ctx.beginPath(); ctx.arc(cx, cy, r * k, 0, 2 * Math.PI); ctx.stroke(); }
        // the sweep, with a fading wedge behind it
        for (let t = 0; t < 8; t++) {
            const a = mem.a - t * 0.07;
            ctx.strokeStyle = g.color(0.6, -1, 0.5 * (1 - t / 8));
            ctx.lineWidth = 1;
            ctx.beginPath();
            ctx.moveTo(cx, cy);
            ctx.lineTo(cx + Math.cos(a) * r, cy + Math.sin(a) * r);
            ctx.stroke();
        }
        for (const b of mem.blips) {
            ctx.fillStyle = g.color(b.d, b.v, b.life);
            ctx.beginPath();
            ctx.arc(cx + Math.cos(b.a) * r * b.d, cy + Math.sin(b.a) * r * b.d, 0.8 + b.v * 1.6, 0, 2 * Math.PI);
            ctx.fill();
        }
    }
};
