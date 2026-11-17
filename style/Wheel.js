.pragma library

// One step from a mouse wheel or a touchpad: +1 (up, or to the left), -1 (down, or to the
// right), or 0 while a touchpad swipe hasn't gone far enough yet. The way it moved most
// decides, so a sideways swipe goes sideways whatever little it also moved up or down,
// and moving nowhere does nothing (not "down").
// `acc` ({ v: 0 }, kept by the caller) adds a touchpad's small movements up: one step
// for each notch's worth (120), started again when the swipe turns round.
function step(event, acc) {
    const x = event.angleDelta.x, y = event.angleDelta.y;
    const v = Math.abs(x) > Math.abs(y) ? x : y;
    if (!v) return 0;
    if (!acc) return v > 0 ? 1 : -1;
    if (acc.v !== 0 && (acc.v > 0) !== (v > 0)) acc.v = 0;
    acc.v += v;
    if (Math.abs(acc.v) < 120) return 0;
    const s = acc.v > 0 ? 1 : -1;
    acc.v = 0;
    return s;
}

// How far to scroll something that moves smoothly (a bar region): the way it moved most.
function amount(event) {
    const x = event.angleDelta.x, y = event.angleDelta.y;
    return Math.abs(x) > Math.abs(y) ? x : y;
}
