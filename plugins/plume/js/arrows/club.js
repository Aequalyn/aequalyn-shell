.pragma library

// A club suit: three rounded lobes and a stem, with a pointed top.
function circle(cx, cy, r, start, end, steps) {
    const pts = [];
    for (let i = 0; i <= steps; i++) {
        const a = start + (end - start) * i / steps;
        pts.push([cx + r * Math.cos(a), cy + r * Math.sin(a)]);
    }
    return pts;
}

function outline() {
    const out = [[0, 0]];
    // right shoulder to right lobe
    for (let i = 1; i <= 8; i++) {
        const t = i / 8;
        const y = 7.5 * t;
        const x = 4.2 * Math.sin(Math.PI * Math.pow(t, 0.85));
        out.push([x, y]);
    }
    // right lobe
    const rr = 4.0, rcx = 4.6, rcy = 11.0;
    for (let i = 1; i <= 14; i++) {
        const a = -Math.PI * 0.78 + Math.PI * 1.56 * i / 14;
        out.push([rcx + rr * Math.cos(a), rcy + rr * Math.sin(a)]);
    }
    // stem right
    out.push([2.1, 15.0], [3.4, 21.0], [0, 21.0]);
    // stem left
    out.push([-3.4, 21.0], [-2.1, 15.0]);
    // left lobe
    const lr = 4.0, lcx = -4.6, lcy = 11.0;
    for (let i = 1; i <= 14; i++) {
        const a = Math.PI * 0.22 + Math.PI * 1.56 * i / 14;
        out.push([lcx + lr * Math.cos(a), lcy + lr * Math.sin(a)]);
    }
    // left shoulder up to tip
    for (let i = 7; i >= 1; i--) {
        const t = i / 8;
        const y = 7.5 * t;
        const x = -4.2 * Math.sin(Math.PI * Math.pow(t, 0.85));
        out.push([x, y]);
    }
    return out;
}

var arrow = {
    key: "club",
    label: "Club",
    about: "A club suit symbol with three lobes and a stem.",
    upright: true,
    points: outline()
};
