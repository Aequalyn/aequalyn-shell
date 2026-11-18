.pragma library

// Tunnel: frames that rush out from the middle towards you, a new one on every beat,
// faster the louder it gets.
var visual = {
    key: "tunnel",
    label: "Tunnel",
    about: "Frames rushing out from the middle towards you, a new one on every beat.",
    draw(g) {
        const { ctx, w, h, mem, st } = g;
        if (!mem.rings) { mem.rings = []; mem.last = 0; }
        mem.last = (mem.last || 0) + 1;
        if ((st.bass > 0.45 && mem.last > 4) || mem.last > 14) { mem.rings.push(0); mem.last = 0; }
        const speed = 0.015 + st.level * 0.05;
        mem.rings = mem.rings.map(z => z + speed * (1 + z * 2)).filter(z => z < 1);
        for (const z of mem.rings) {
            const rw = w * z, rh = h * z;
            ctx.strokeStyle = g.color(z, st.level, 1 - z * 0.7);
            ctx.lineWidth = 0.6 + z * 1.6;
            ctx.beginPath();
            const x = (w - rw) / 2, y = (h - rh) / 2, rad = Math.min(rh / 2, 4 * z);
            ctx.moveTo(x + rad, y);
            ctx.arcTo(x + rw, y, x + rw, y + rh, rad);
            ctx.arcTo(x + rw, y + rh, x, y + rh, rad);
            ctx.arcTo(x, y + rh, x, y, rad);
            ctx.arcTo(x, y, x + rw, y, rad);
            ctx.stroke();
        }
    }
};
