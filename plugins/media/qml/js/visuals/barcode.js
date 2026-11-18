.pragma library

// Barcode: full-height lines packed close, each as thick and as bright as its part of
// the music: a pattern that reads the song.
var visual = {
    key: "barcode",
    label: "Barcode",
    about: "Full-height lines packed close, each as thick and bright as its part of the music.",
    draw(g) {
        const { ctx, w, h } = g;
        const n = Math.max(8, Math.min(48, Math.floor(w / 3)));
        const cell = w / n;
        for (let i = 0; i < n; i++) {
            const v = g.clamp(g.at(i, n), 0, 1);
            const lw = Math.max(0.6, cell * (0.15 + 0.75 * v));
            ctx.fillStyle = g.color(i / (n - 1), v, 0.35 + 0.65 * v);
            ctx.fillRect(i * cell + (cell - lw) / 2, 0, lw, h);
        }
    }
};
