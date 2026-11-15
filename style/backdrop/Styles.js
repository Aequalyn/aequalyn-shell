// The ways the desktop can sit behind a full-screen panel (control center, pickers,
// clipboard, power menu, launcher, screens). Every one except "instant" is drawn by the
// shell on a still picture of the desktop taken as the panel opens, so it can come and
// go smoothly; "instant" is the compositor's own blur, live but with no transition.
.pragma library

var list = [
    { key: "smooth",    label: "Smooth blur",   sub: "The desktop melts into a blur and back" },
    { key: "zoom",      label: "Blur and zoom", sub: "It blurs and sinks back a little" },
    { key: "frost",     label: "Frost",         sub: "A pale, frosted glass" },
    { key: "iris",      label: "Iris",          sub: "The blur opens out from the middle" },
    { key: "mosaic",    label: "Mosaic",        sub: "It breaks into soft tiles" },
    { key: "maelstrom", label: "Maelstrom",     sub: "It swirls into a whirlpool" },
    { key: "instant",   label: "Instant",       sub: "Live blur, no transition" },
    { key: "dim",       label: "Dim only",      sub: "Just darker, no blur" }
];

var keys = list.map(function (s) { return s.key; });

function valid(key) { return keys.indexOf(key) >= 0 ? key : "smooth"; }
