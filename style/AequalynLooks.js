.pragma library
.import "Style.js" as Style

// Aequalyn's own looks for the bar and the docks, in five families, and the
// ensembles that dress both at once. Each look names only the keys it sets;
// everything else goes back to its default, so nothing from the last look
// lingers. Colors are never touched: they stay with Atelier's palette.
//
//   Calm      quiet, out of the way
//   Isles     groups of widgets as islands
//   Pebbles   a shape per widget
//   Glow      light, gradients and glass
//   Crafted   materials and ornament

var families = [
    { key: "calm",    label: "Calm",    about: "Quiet and out of the way" },
    { key: "isles",   label: "Isles",   about: "Groups of widgets as islands" },
    { key: "pebbles", label: "Pebbles", about: "A shape for every widget" },
    { key: "glow",    label: "Glow",    about: "Light, gradients and glass" },
    { key: "crafted", label: "Crafted", about: "Materials and ornament" }
];

// ---- the bar --------------------------------------------------------------------
var bar = [
  // calm
  { key: "horizon",  label: "Horizon",  family: "calm", about: "One plain band, the Aequalyn default",
    set: { shape: "full", surface: "filled", lines: "none", fill: "solid", border: "subtle", shadow: "none", hover: "fill" } },
  { key: "veil",     label: "Veil",     family: "calm", about: "No band at all, an accent line underneath",
    set: { shape: "full", surface: "clear", lines: "none", edgeLine: true, hover: "underline", separators: "dot", shadow: "none" } },
  { key: "strata",   label: "Strata",   family: "calm", about: "A layered band with dividers between groups",
    set: { shape: "full", surface: "ledge", lines: "inset", border: "subtle", dividers: true, shadow: "soft", hover: "fill" } },
  { key: "shoal",    label: "Shoal",    family: "calm", about: "A floating pill, a hand's width off the edge",
    set: { shape: "pill", ends: "rounded", radius: 14, surface: "filled", lines: "solid", border: "subtle", shadow: "soft", edgeGap: 6, sideGap: 14 } },
  { key: "hush",     label: "Hush",     family: "calm", about: "A pill that is only as long as its widgets",
    set: { shape: "pill", pillFit: true, ends: "capsule", surface: "faint", lines: "none", shadow: "none", edgeGap: 6, padding: 10 } },
  // isles
  { key: "archipelago", label: "Archipelago", family: "isles", about: "Three soft islands, left, middle and right",
    set: { shape: "islands", ends: "rounded", radius: 12, surface: "filled", lines: "solid", border: "subtle", shadow: "soft", edgeGap: 6, padding: 8 } },
  { key: "atoll",    label: "Atoll",    family: "isles", about: "Islands hanging from the edge, curving into it",
    set: { shape: "islands", ends: "rounded", radius: 14, attach: true, concave: true, surface: "filled", lines: "none", shadow: "none", edgeGap: 4, padding: 10 } },
  { key: "lagoon",   label: "Lagoon",   family: "isles", about: "Frosted capsules you can see the wallpaper through",
    set: { shape: "islands", ends: "capsule", surface: "frost", fill: "glass", lines: "solid", border: "subtle", shadow: "soft", opacity: 78, padding: 10 } },
  { key: "cairn",    label: "Cairn",    family: "isles", about: "Cut stone islands with a raised edge",
    set: { shape: "islands", ends: "chamfer", surface: "bevel", lines: "none", depth: "raised", shadow: "soft", padding: 10 } },
  { key: "delta",    label: "Delta",    family: "isles", about: "Islands that point away from the middle",
    set: { shape: "islands", ends: "arrow", pointingBar: "outward", surface: "filled", lines: "solid", border: "accent", shadow: "none", padding: 12, separators: "slash" } },
  { key: "reef",     label: "Reef",     family: "isles", about: "A wide middle island, matching sides",
    set: { shape: "islands", ends: "capsule", surface: "twotone", lines: "none", shadow: "soft", centerMin: 320, mirrorSides: true, centerStyle: "tinted" } },
  // pebbles
  { key: "pebbles",  label: "Pebbles",  family: "pebbles", about: "Every widget in its own round stone",
    set: { shape: "widgets", ends: "capsule", surface: "filled", lines: "none", shadow: "soft", pillGap: 3 } },
  { key: "seeds",    label: "Seeds",    family: "pebbles", about: "Leaf shapes, leaning outward",
    set: { shape: "widgets", ends: "leaf", pointingBar: "outward", surface: "filled", lines: "none", shadow: "soft", pillGap: 3 } },
  { key: "prism",    label: "Prism",    family: "pebbles", about: "Every widget in the next color of the theme",
    set: { shape: "widgets", ends: "capsule", surface: "faint", lines: "solid", border: "accent", colorMode: "palette", shadow: "none", pillGap: 3 } },
  { key: "keys",     label: "Keys",     family: "pebbles", about: "Keycaps you could press",
    set: { shape: "widgets", ends: "rounded", radius: 6, surface: "keycap", lines: "none", depth: "raised", shadow: "soft", pillGap: 3 } },
  { key: "shards",   label: "Shards",   family: "pebbles", about: "Slanted glass splinters",
    set: { shape: "widgets", ends: "slant", surface: "frost", fill: "glass", lines: "solid", shadow: "none", pillGap: 2 } },
  // glow
  { key: "ember",    label: "Ember",    family: "glow", about: "Islands lit from below, glowing in the accent",
    set: { shape: "islands", ends: "capsule", surface: "underglow", lines: "none", shadow: "strong", shadowColor: "accent", opacity: 80 } },
  { key: "borealis", label: "Borealis", family: "glow", about: "The whole theme in one gradient",
    set: { shape: "pill", ends: "capsule", surface: "faint", fill: "gradient", gradientTo: "spectrum", lines: "solid", outlineGradient: true, outlineGradientTo: "spectrum", borderWidth: 2, shadow: "soft", shadowColor: "accent", edgeGap: 6, sideGap: 14 } },
  { key: "tideline", label: "Tideline", family: "glow", about: "A wave running along the band",
    set: { shape: "full", surface: "faint", lines: "wavy", border: "accent", railSide: "windows", shadow: "none", hover: "glow" } },
  { key: "firefly",  label: "Firefly",  family: "glow", about: "Small lights around every widget",
    set: { shape: "widgets", ends: "capsule", surface: "faint", lines: "glow", border: "accent", shadow: "none", pillGap: 4 } },
  { key: "nocturne", label: "Nocturne", family: "glow", about: "A night sky with a few stars",
    set: { shape: "islands", ends: "capsule", surface: "nebula", lines: "solid", border: "accent", ornaments: "stars", shadow: "none", padding: 10 } },
  // crafted
  { key: "basalt",   label: "Basalt",   family: "crafted", about: "Dark stone held with rivets",
    set: { shape: "islands", ends: "square", surface: "carbon", lines: "solid", ornaments: "rivets", shadow: "strong", padding: 10 } },
  { key: "loom",     label: "Loom",     family: "crafted", about: "Leather, stitched by hand",
    set: { shape: "islands", ends: "rounded", radius: 10, surface: "leather", lines: "stitched", border: "text", shadow: "soft", padding: 10 } },
  { key: "grove",    label: "Grove",    family: "crafted", about: "Warm wood with studs",
    set: { shape: "pill", ends: "rounded", radius: 10, surface: "wood", lines: "solid", ornaments: "studs", shadow: "soft", edgeGap: 6, sideGap: 14 } },
  { key: "contour",  label: "Contour",  family: "crafted", about: "A map's height lines",
    set: { shape: "full", surface: "topo", lines: "inset", dividers: true, shadow: "none" } },
  { key: "gallery",  label: "Gallery",  family: "crafted", about: "Framed in gold, for a salon",
    set: { shape: "islands", ends: "cartouche", surface: "velvet", lines: "gilded", ornaments: "fleurons", shadow: "strong", padding: 12 } }
];

// ---- the docks --------------------------------------------------------------------
// Style keys only: where a dock sits and how it hides are its own.
var dock = [
  { key: "horizon",  label: "Horizon",  family: "calm",    about: "Plain, rounded",
    set: { ends: "rounded", surface: "filled", fill: "solid", lines: "none", border: "subtle", shadow: "soft" } },
  { key: "veil",     label: "Veil",     family: "calm",    about: "Barely there",
    set: { ends: "capsule", surface: "faint", fill: "solid", lines: "solid", border: "subtle", shadow: "none" } },
  { key: "strata",   label: "Strata",   family: "calm",    about: "A shelf for your apps",
    set: { ends: "square", surface: "ledge", fill: "solid", lines: "inset", shadow: "soft" } },
  { key: "lagoon",   label: "Lagoon",   family: "isles",   about: "Frosted glass",
    set: { ends: "capsule", surface: "frost", fill: "glass", lines: "solid", border: "subtle", shadow: "soft" } },
  { key: "cairn",    label: "Cairn",    family: "isles",   about: "Cut stone",
    set: { ends: "chamfer", surface: "bevel", fill: "solid", depth: "raised", lines: "none", shadow: "soft" } },
  { key: "delta",    label: "Delta",    family: "isles",   about: "Pointing both ways",
    set: { ends: "arrow", pointing: "both", fill: "solid", lines: "solid", border: "accent", shadow: "none" } },
  { key: "pebbles",  label: "Pebbles",  family: "pebbles", about: "One round stone",
    set: { ends: "capsule", surface: "filled", fill: "gradient", gradientTo: "darker", lines: "none", shadow: "soft" } },
  { key: "keys",     label: "Keys",     family: "pebbles", about: "A keyboard row",
    set: { ends: "rounded", surface: "keycap", fill: "solid", depth: "raised", lines: "none", shadow: "soft" } },
  { key: "ember",    label: "Ember",    family: "glow",    about: "Lit from below",
    set: { ends: "capsule", surface: "underglow", fill: "solid", lines: "none", shadow: "strong", shadowColor: "accent" } },
  { key: "borealis", label: "Borealis", family: "glow",    about: "The theme in one gradient",
    set: { ends: "capsule", surface: "faint", fill: "gradient", gradientTo: "spectrum", lines: "solid", outlineGradient: true, outlineGradientTo: "spectrum", borderWidth: 2, shadowColor: "accent" } },
  { key: "tideline", label: "Tideline", family: "glow",    about: "A wave along the windows' side",
    set: { ends: "rounded", surface: "faint", fill: "solid", lines: "wavy", border: "accent", railSide: "windows", shadow: "none" } },
  { key: "nocturne", label: "Nocturne", family: "glow",    about: "Night sky",
    set: { ends: "capsule", surface: "nebula", fill: "solid", lines: "solid", border: "accent", ornaments: "stars", shadow: "none" } },
  { key: "basalt",   label: "Basalt",   family: "crafted", about: "Stone and rivets",
    set: { ends: "square", surface: "carbon", fill: "solid", lines: "solid", ornaments: "rivets", shadow: "strong" } },
  { key: "loom",     label: "Loom",     family: "crafted", about: "Stitched leather",
    set: { ends: "rounded", surface: "leather", fill: "solid", lines: "stitched", border: "text", shadow: "soft" } },
  { key: "grove",    label: "Grove",    family: "crafted", about: "Wood and studs",
    set: { ends: "rounded", surface: "wood", fill: "solid", lines: "solid", ornaments: "studs", shadow: "soft" } },
  { key: "gallery",  label: "Gallery",  family: "crafted", about: "A gilded frame",
    set: { ends: "cartouche", surface: "velvet", fill: "solid", lines: "gilded", ornaments: "fleurons", shadow: "strong" } }
];

// ---- ensembles: the bar and every dock in one click ----------------------------------
// dock: "follow" = the docks wear the bar's look; else a dock look of their own.
var ensembles = [
  { key: "still",     label: "Still",     about: "Horizon bar, docks in the same plain cloth",       bar: "horizon",     dock: "follow" },
  { key: "tide",      label: "Tide",      about: "Floating shoal above, frosted lagoon docks",       bar: "shoal",       dock: "lagoon" },
  { key: "islands",   label: "Islands",   about: "Archipelago bar, docks as its fourth island",      bar: "archipelago", dock: "follow" },
  { key: "harbour",   label: "Harbour",   about: "Atoll hanging from the top, a strata shelf below",  bar: "atoll",       dock: "strata" },
  { key: "hearth",    label: "Hearth",    about: "Ember glow everywhere",                            bar: "ember",       dock: "follow" },
  { key: "aurora",    label: "Aurora",    about: "Borealis bar and docks",                           bar: "borealis",    dock: "follow" },
  { key: "midnight",  label: "Midnight",  about: "Nocturne skies, veil docks",                       bar: "nocturne",    dock: "veil" },
  { key: "workshop",  label: "Workshop",  about: "Basalt bar, stitched leather docks",               bar: "basalt",      dock: "loom" }
];

function byKey(list, key) {
    for (var i = 0; i < list.length; i++) if (list[i].key === key) return list[i];
    return null;
}
function inFamily(list, family) {
    if (!family || family === "all") return list;
    return list.filter(function (l) { return l.family === family; });
}

// a dock look as a full set of style keys
function dockSet(key) {
    var L = byKey(dock, key);
    if (!L) return null;
    var out = Style.defaults();
    for (var k in L.set) out[k] = Style.cleanValue(k, L.set[k]);
    return out;
}
// the dock look a dock is wearing, or ""
function dockLookOf(d) {
    for (var i = 0; i < dock.length; i++) {
        var want = dockSet(dock[i].key), same = true;
        for (var j = 0; j < Style.keys.length; j++)
            if (d[Style.keys[j]] !== want[Style.keys[j]]) { same = false; break; }
        if (same) return dock[i].key;
    }
    return "";
}
