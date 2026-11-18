.pragma library

// VU: two analog needles, the low end and the high end, that swing up with the music
// and fall back gently, over a scale that turns red at the top.
var visual = {
    key: "vu",
    label: "VU needles",
    about: "Two analog needles, the lows and the highs, swinging up and falling back gently.",
    draw(g) {
        const { ctx, w, h, mem, st } = g;
        const half = w / 2;
        const lows = g.clamp(st.bass * 1.1, 0, 1);
        let highs = 0;
        for (let i = 0; i < 8; i++) highs += g.clamp(g.at(8 + i, 16), 0, 1);
        highs = g.clamp(highs / 8 * 1.6, 0, 1);
        // needles have weight: up quickly, down slowly
        mem.a = mem.a === undefined ? 0 : (lows > mem.a ? mem.a + (lows - mem.a) * 0.5 : mem.a - 0.04);
        mem.b = mem.b === undefined ? 0 : (highs > mem.b ? mem.b + (highs - mem.b) * 0.5 : mem.b - 0.04);
        const r = Math.min(half * 0.8, h * 0.95);
        for (const [k, val] of [[0, Math.max(0, mem.a)], [1, Math.max(0, mem.b)]]) {
            const cx = half * k + half / 2, cy = h - 1;
            const a0 = Math.PI * 1.18, a1 = Math.PI * 1.82;
            ctx.lineWidth = Math.max(1.5, r * 0.12);
            ctx.lineCap = "butt";
            for (let s = 0; s < 10; s++) {
                const t0 = s / 10, t1 = (s + 0.8) / 10;
                ctx.strokeStyle = s >= 8 ? "rgba(235,80,80,0.85)" : g.color(t0, -1, 0.35);
                ctx.beginPath();
                ctx.arc(cx, cy, r, a0 + (a1 - a0) * t0, a0 + (a1 - a0) * t1);
                ctx.stroke();
            }
            const a = a0 + (a1 - a0) * val;
            ctx.strokeStyle = g.color(0.5 + k * 0.5, val);
            ctx.lineWidth = 1.5;
            ctx.lineCap = "round";
            ctx.beginPath();
            ctx.moveTo(cx, cy);
            ctx.lineTo(cx + Math.cos(a) * r * 1.05, cy + Math.sin(a) * r * 1.05);
            ctx.stroke();
        }
    }
};
