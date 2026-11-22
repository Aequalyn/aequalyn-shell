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
    set: { shape: "islands", ends: "cartouche", surface: "velvet", lines: "gilded", ornaments: "fleurons", shadow: "strong", padding: 12 } },
  // the classic set, rebuilt in Aequalyn's parts
  { key: "classic",  label: "Classic",  family: "calm", about: "A plain band with a soft shadow",
    set: { shape: "full", surface: "filled", lines: "none", fill: "solid", border: "subtle", edgeLine: false, dividers: false, separators: "none", hover: "fill", openMark: "line", opacity: 100, barTint: 0, shadow: "soft" } },
  { key: "floating", label: "Floating", family: "calm", about: "A rounded pill held off the edge",
    set: { shape: "pill", pillFit: false, ends: "rounded", radius: 12, attach: false, surface: "filled", lines: "solid", fill: "solid", border: "subtle", shadow: "soft", shadowColor: "dark", edgeGap: 6, sideGap: 12, separators: "none" } },
  { key: "islands",  label: "Isles",    family: "isles", about: "One rounded island per group",
    set: { shape: "islands", ends: "rounded", radius: 10, attach: false, surface: "filled", lines: "solid", fill: "solid", border: "subtle", shadow: "soft", shadowColor: "dark", regions: "all", centerStyle: "same", edgeGap: 6, padding: 6 } },
  { key: "capsules", label: "Capsules", family: "isles", about: "A little capsule for each widget",
    set: { shape: "widgets", ends: "capsule", attach: false, surface: "filled", lines: "none", fill: "solid", border: "subtle", shadow: "soft", shadowColor: "dark", pillGap: 2, regions: "all" } },
  { key: "tabs",     label: "Tabs",     family: "isles", about: "Islands joined to the screen edge",
    set: { shape: "islands", ends: "rounded", radius: 12, attach: true, concave: true, surface: "filled", lines: "none", fill: "solid", border: "subtle", shadow: "none", edgeGap: 4, padding: 8 } },
  { key: "outline",  label: "Outline",  family: "isles", about: "A bare shape and one bright line",
    set: { shape: "islands", ends: "rounded", radius: 8, attach: false, surface: "faint", lines: "solid", border: "accent", borderWidth: 1, shadow: "none", fill: "solid", opacity: 100 } },
  { key: "rail",     label: "Rail",     family: "isles", about: "A square rail with a single line",
    set: { shape: "islands", ends: "square", attach: false, surface: "faint", lines: "rail", borderWidth: 2, shadow: "none", fill: "solid", opacity: 60 } },
  { key: "brackets", label: "Brackets", family: "crafted", about: "Bare shapes held in brackets",
    set: { shape: "islands", ends: "square", attach: false, surface: "clear", lines: "none", ornaments: "brackets", bracket: 7, borderWidth: 2, shadow: "none" } },
  { key: "neon",     label: "Neon",     family: "glow", about: "A lit tube with an accent glow",
    set: { shape: "islands", ends: "capsule", attach: false, surface: "filled", lines: "glow", border: "accent", borderWidth: 1, shadow: "strong", shadowColor: "accent", fill: "solid", opacity: 70 } },
  { key: "hex",      label: "Hex",      family: "isles", about: "Arrows pointing both ways",
    set: { shape: "widgets", ends: "arrow", pointingBar: "both", attach: false, surface: "filled", lines: "none", fill: "solid", border: "subtle", shadow: "soft", shadowColor: "dark", pillGap: 2 } },
  { key: "ribbon",   label: "Ribbon",   family: "isles", about: "A folded band with room to breathe",
    set: { shape: "islands", ends: "ribbon", attach: false, surface: "filled", lines: "none", fill: "solid", border: "subtle", shadow: "soft", shadowColor: "dark", padding: 12 } },
  { key: "cut",      label: "Cut",      family: "isles", about: "Chamfered corners, a bright cut edge",
    set: { shape: "islands", ends: "chamfer", attach: false, surface: "faint", lines: "solid", border: "accent", borderWidth: 1, shadow: "none", depth: "flat" } },
  { key: "leaf",     label: "Leaf",     family: "isles", about: "Little leaves pointing outward",
    set: { shape: "widgets", ends: "leaf", pointingBar: "outward", attach: false, surface: "filled", lines: "none", fill: "solid", border: "subtle", shadow: "soft", shadowColor: "dark", pillGap: 2 } },
  { key: "tickets",  label: "Tickets",  family: "isles", about: "Scalloped pieces in two tones",
    set: { shape: "widgets", ends: "scallop", attach: false, surface: "twotone", lines: "none", fill: "solid", border: "subtle", shadow: "soft", shadowColor: "dark", pillGap: 2 } },
  { key: "tags",     label: "Tags",     family: "isles", about: "Drops with an inset label line",
    set: { shape: "islands", ends: "drop", pointingBar: "outward", attach: false, surface: "filled", lines: "inset", border: "accent", borderWidth: 1, shadow: "soft", shadowColor: "dark", padding: 10 } },
  { key: "lantern",  label: "Lantern",  family: "glow", about: "A soft underglow, nothing else",
    set: { shape: "islands", ends: "capsule", attach: false, surface: "underglow", lines: "none", fill: "solid", border: "subtle", shadow: "none" } },
  { key: "aurora",   label: "Aurora",   family: "glow", about: "Window-border colors fading along the edge",
    set: { shape: "islands", ends: "capsule", attach: false, surface: "faint", lines: "solid", border: "border", borderWidth: 2, outlineGradient: true, outlineGradientTo: "border", outlineGradientDir: "theme", colorMode: "borders", fill: "gradient", gradientTo: "border", shadow: "soft", shadowColor: "accent" } },
  { key: "arrows",   label: "Arrows",   family: "crafted", about: "Pointing outward, with slashes between",
    set: { shape: "islands", ends: "arrow", pointingBar: "outward", attach: false, surface: "filled", lines: "none", fill: "solid", border: "subtle", shadow: "soft", shadowColor: "dark", padding: 10, separators: "slash" } },
  { key: "slanted",  label: "Slanted",  family: "crafted", about: "Slender pieces leaning one way",
    set: { shape: "widgets", ends: "slant", pointingBar: "right", attach: false, surface: "filled", lines: "none", fill: "solid", border: "subtle", shadow: "none", pillGap: 2 } },
  { key: "paper",    label: "Paper",    family: "crafted", about: "A quiet band, gently tinted",
    set: { shape: "islands", ends: "rounded", radius: 14, attach: false, surface: "filled", lines: "none", fill: "solid", border: "subtle", shadow: "soft", shadowColor: "dark", centerStyle: "tinted", barTint: 6 } },
  { key: "glass",    label: "Glass",    family: "glow", about: "See-through capsules",
    set: { shape: "pill", ends: "capsule", attach: false, surface: "filled", lines: "solid", fill: "glass", border: "subtle", shadow: "soft", shadowColor: "dark", opacity: 80 } },
  { key: "chrome",   label: "Chrome",   family: "crafted", about: "Brushed metal with a fine edge",
    set: { shape: "islands", ends: "capsule", attach: false, surface: "metal", lines: "solid", border: "subtle", borderWidth: 1, shadow: "soft", shadowColor: "dark" } },
  { key: "arcade",   label: "Arcade",   family: "crafted", about: "Pixels and battlements",
    set: { shape: "widgets", ends: "castle", attach: false, surface: "crt", lines: "solid", border: "accent", borderWidth: 1, shadow: "none", pillGap: 2 } },
  { key: "comets",   label: "Comets",   family: "glow", about: "Slanting shapes with a comet surface",
    set: { shape: "islands", ends: "slant", pointingBar: "outward", attach: false, surface: "comet", lines: "none", border: "subtle", shadow: "soft", shadowColor: "dark", padding: 10 } },
  { key: "jigsaw",   label: "Jigsaw",   family: "crafted", about: "Puzzle pieces in candy colors",
    set: { shape: "widgets", ends: "puzzle", attach: false, surface: "candy", lines: "none", border: "subtle", shadow: "soft", shadowColor: "dark", pillGap: 2 } },
  { key: "ornate",   label: "Ornate",   family: "crafted", about: "Gilded scrollwork and rosettes",
    set: { shape: "islands", ends: "cartouche", attach: false, surface: "filled", lines: "gilded", ornaments: "rosettes", shadow: "strong", shadowColor: "dark", padding: 12 } },
  { key: "rococo",   label: "Rococo",   family: "crafted", about: "Filigree on curled ends",
    set: { shape: "widgets", ends: "fleur", attach: false, surface: "filled", lines: "none", ornaments: "filigree", border: "subtle", shadow: "soft", shadowColor: "dark", pillGap: 2 } },
  { key: "versailles", label: "Versailles", family: "crafted", about: "Scrolls on damask",
    set: { shape: "pill", ends: "capsule", ornaments: "scrolls", attach: false, surface: "damask", lines: "solid", border: "subtle", shadow: "soft", shadowColor: "dark" } },
  { key: "opera",    label: "Opera",    family: "crafted", about: "Velvet, diamonds and an accent line",
    set: { shape: "islands", ends: "cartouche", attach: false, surface: "velvet", lines: "solid", ornaments: "diamonds", border: "accent", borderWidth: 1, shadow: "soft", shadowColor: "dark", padding: 10 } },
  { key: "mono",     label: "Mono",     family: "calm", about: "Squares and greys, no hue at all",
    set: { shape: "islands", ends: "square", attach: false, surface: "filled", lines: "solid", border: "text", borderWidth: 1, shadow: "none", colorMode: "monochrome", fill: "solid" } },
  { key: "minimal",  label: "Minimal",  family: "calm", about: "An accent line and nothing else",
    set: { shape: "full", surface: "clear", lines: "none", edgeLine: true, dividers: false, hover: "underline", openMark: "line", separators: "dot", shadow: "soft" } },
  { key: "rainbow",  label: "Rainbow",  family: "glow", about: "Widgets dressed in the theme's colors",
    set: { shape: "widgets", ends: "capsule", attach: false, surface: "faint", lines: "solid", border: "accent", colorMode: "palette", paletteUse: "accent", shadow: "none" } }
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
    set: { ends: "cartouche", surface: "velvet", fill: "solid", lines: "gilded", ornaments: "fleurons", shadow: "strong" } },
  { key: "plain",    label: "Plain",    family: "calm",    about: "Nothing added",
    set: {} },
  { key: "glass",    label: "Glass",    family: "calm",    about: "Frosted and see-through",
    set: { ends: "capsule", surface: "frost", fill: "glass", lines: "solid", border: "subtle", shadow: "none" } },
  { key: "outline",  label: "Outline",  family: "calm",    about: "Just an accent line",
    set: { surface: "faint", lines: "solid", border: "accent", shadow: "none" } },
  { key: "neon",     label: "Neon",     family: "glow",    about: "A lit tube",
    set: { ends: "capsule", surface: "faint", lines: "neon", shadow: "none" } },
  { key: "metal",    label: "Metal",    family: "crafted", about: "Riveted sheet metal",
    set: { ends: "chamfer", surface: "metal", lines: "solid", ornaments: "rivets", shadow: "strong" } },
  { key: "arcade",   label: "Arcade",   family: "crafted", about: "Pixels and battlements",
    set: { ends: "castle", surface: "crt", lines: "solid", border: "accent", shadow: "none" } },
  { key: "paper",    label: "Paper",    family: "crafted", about: "Ink on a page",
    set: { ends: "folded", surface: "filled", lines: "sketch", border: "text", shadow: "soft" } },
  { key: "workshop", label: "Workshop", family: "crafted", about: "Wood and stitches",
    set: { surface: "wood", lines: "stitched", border: "text", ornaments: "studs", shadow: "strong" } },
  { key: "saddle",   label: "Saddle",   family: "crafted", about: "Stitched leather",
    set: { surface: "leather", lines: "stitched", border: "accent", ornaments: "rivets" } },
  { key: "ribbon",   label: "Ribbon",   family: "isles",   about: "A folded band",
    set: { ends: "ribbon", surface: "twotone", lines: "solid", border: "accent" } },
  { key: "arrows",   label: "Arrows",   family: "crafted", about: "Pointing both ways",
    set: { ends: "arrow", pointing: "both", lines: "solid", border: "accent", shadow: "soft" } },
  { key: "deco",     label: "Deco",     family: "crafted", about: "A framed plaque",
    set: { ends: "plaque", surface: "filled", lines: "double", border: "accent", ornaments: "deco" } },
  { key: "salon",    label: "Salon",    family: "crafted", about: "Velvet and rosettes",
    set: { ends: "cartouche", surface: "velvet", lines: "gilded", ornaments: "rosettes", shadow: "strong" } },
  { key: "palace",   label: "Palace",   family: "crafted", about: "A crowned facade",
    set: { ends: "dome", surface: "damask", lines: "gilded", ornaments: "crown", shadow: "strong" } },
  { key: "chapel",   label: "Chapel",   family: "crafted", about: "Stained glass and filigree",
    set: { ends: "fleur", surface: "stained", lines: "gilded", ornaments: "filigree" } },
  { key: "nebula",   label: "Nebula",   family: "glow",    about: "Stars in deep space",
    set: { ends: "capsule", surface: "nebula", lines: "glow", border: "accent", ornaments: "stars", shadow: "none" } }
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
