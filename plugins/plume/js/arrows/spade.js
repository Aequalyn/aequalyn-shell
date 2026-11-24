.pragma library

// A spade suit: a sharp point that swells into two lobes, on a flared stem.
function curve(a, b, c, d, steps) {
    const pts = [];
    for (let i = 1; i <= steps; i++) {
        const t = i / steps, u = 1 - t;
        pts.push([u * u * u * a[0] + 3 * u * u * t * b[0] + 3 * u * t * t * c[0] + t * t * t * d[0],
                  u * u * u * a[1] + 3 * u * u * t * b[1] + 3 * u * t * t * c[1] + t * t * t * d[1]]);
    }
    return pts;
}

function outline() {
    // the right half, from the tip down to the middle of the foot
    const right = [[0, 0]]
        .concat(curve([0, 0], [1.4, 4.6], [8.4, 7.2], [8.4, 12.2], 12))
        .concat(curve([8.4, 12.2], [8.4, 15.4], [5.6, 17.0], [3.5, 16.2], 8))
        .concat(curve([3.5, 16.2], [2.5, 15.8], [1.7, 15.2], [1.2, 14.6], 4))
        .concat(curve([1.2, 14.6], [1.3, 17.8], [2.2, 20.0], [3.9, 21.2], 6));
    const left = right.slice(1).reverse().map(p => [-p[0], p[1]]);
    return right.concat(left);
}

var arrow = {
    key: "spade",
    label: "Spade",
    about: "A spade suit symbol with a sharp point and a stem.",
    upright: true,
    points: outline()
};
