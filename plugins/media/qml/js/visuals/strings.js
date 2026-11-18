.pragma library

// Strings: a few strings across, each a band of the music, shaking as hard as that
// band is loud, still when it is quiet.
var visual = {
    key: "strings",
    label: "Strings",
    about: "Strings across, one per range of the music, shaking as hard as it is loud.",
    draw(g) {
        const { ctx, w, h, st } = g;
        const n = 5;
        const seg = 28;
        for (let s = 0; s < n; s++) {
            const v = g.clamp(g.at(s, n), 0, 1);
            const y0 = h * (s + 0.5) / n;
            const amp = v * h / n * 0.9;
            const xs = [], ys = [];
            for (let i = 0; i <= seg; i++) {
                const x = i / seg;
                // a standing wave: still at both ends, the harmonic higher for higher strings
                xs.push(x * w);
                ys.push(y0 + Math.sin(Math.PI * x * (s + 1)) * Math.sin(st.phase * (2 + s) + s) * amp);
            }
            ctx.strokeStyle = g.color(s / (n - 1), v);
            ctx.lineWidth = 1 + v;
            ctx.beginPath();
            g.smooth(xs, ys);
            ctx.stroke();
        }
    }
};
