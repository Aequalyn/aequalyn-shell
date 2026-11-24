.pragma library

// A heart suit, the right way up as on a card, leaned a little. A heart's point is at its
// bottom, so the click lands on its upper left instead: the top of the left lobe.
function outline() {
    const n = 64, pts = [], lean = 16 * Math.PI / 180;
    for (let i = 0; i < n; i++) {
        const a = 2 * Math.PI * i / n;
        const x = 16 * Math.pow(Math.sin(a), 3);
        const y = -(13 * Math.cos(a) - 5 * Math.cos(2 * a) - 2 * Math.cos(3 * a) - Math.cos(4 * a));
        pts.push([x * 0.64 * Math.cos(lean) - y * 0.64 * Math.sin(lean),
                  x * 0.64 * Math.sin(lean) + y * 0.64 * Math.cos(lean)]);
    }
    // it starts where it reaches furthest up and to the left
    let at = 0;
    for (let i = 1; i < n; i++)
        if (pts[i][0] + 1.6 * pts[i][1] < pts[at][0] + 1.6 * pts[at][1]) at = i;
    const tip = pts[at];
    return pts.slice(at).concat(pts.slice(0, at)).map(p => [p[0] - tip[0], p[1] - tip[1]]);
}

var arrow = {
    key: "heart",
    label: "Heart",
    about: "A heart suit symbol, as on a card. The click lands on its upper left.",
    points: outline()
};
