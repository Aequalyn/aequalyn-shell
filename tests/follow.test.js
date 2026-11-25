// node tests/follow.test.js -- what follows the bar or a dock takes its look as it is: every
// end, surface, line and ornament has its card and its cursor, with the same colors.
const assert = require("assert");
const path = require("path");
const load = require("./jsload.js");
const R = p => path.join(__dirname, "..", p);
const Follow = load(R("style/Follow.js"));
const Style = load(R("style/Style.js"));
const Bar = load(R("style/BarLooks.js"));
const Colors = load(R("style/Colors.js"));
const Show = load(R("plugins/showcase/qml/js/Schema.js"));
const Look = load(R("plugins/showcase/qml/js/Look.js"));
const Plume = load(R("plugins/plume/js/Schema.js"));
const Cursor = load(R("plugins/plume/js/Cursor.js"));

let n = 0;
const ok = (c, msg) => { assert.ok(c, msg); n++; };
const same = (a, b, msg) => { assert.deepStrictEqual(JSON.parse(JSON.stringify(a)), JSON.parse(JSON.stringify(b)), msg); n++; };

const theme = { bgBase: "#101018", textPrimary: "#e8e8f0", accentPrimary: "#f2c53d", accentCyan: "#62d0ff",
                accentGreen: "#7fc465", accentOrange: "#c99b6e", accentRed: "#ef6b73", borderColors: ["#f2c53d", "#b8860b", "#ffe9a3"] };
const pal = Colors.fromTheme(theme);
const th = { fg: Look.hex3(pal.fg), barText: Look.hex3(pal.fg), accent: Look.hex3(pal.ac), urgent: Look.hex3(pal.hot),
             bg: Look.hex3(pal.bg), palette: pal.spectrum, borders: pal.borders, borderAngle: 45 };
const ctx = { accent: Look.hex3(pal.ac), foreground: Look.hex3(pal.fg), background: Look.hex3(pal.bg),
              palette: pal.spectrum.map(Look.hex3), border: pal.borders.map(Look.hex3), borderAngle: 45 };
const cfg0 = Show.resolve({}), plume0 = Plume.resolve({}, {});

// ---- nothing follows until it is asked to
ok(cfg0.followColors === "own" && cfg0.followStyle === "own", "Showcase follows nothing at first");
ok(plume0.followColors === "own" && plume0.followStyle === "own", "nor does the cursor");
ok(Show.lookKeys.indexOf("followStyle") < 0 && Plume.lookKeys.indexOf("followStyle") < 0, "a look does not turn it on or off");
ok(Plume.cursorKeys.indexOf("followStyle") < 0, "nor does a cursor look");
ok(!("stops" in Cursor.design(plume0, ctx)), "a cursor that follows nothing is the one it was");

// ---- a look as a card: every value is one the card's settings know, and as the bar has it
function wornCard(src) { return Object.assign({}, cfg0, Follow.card(src)); }
function wornCursor(src) { return Object.assign({}, plume0, Follow.cursor(src)); }
function checkSource(src, name) {
    const c = Follow.card(src);
    for (const k in c) {
        if (k === "followed" || k === "followedEdge") continue;
        same(Show.clean(k, c[k]), c[k], name + ": a card's " + k + " " + c[k]);
    }
    for (const k of ["surface", "fill", "gradientTo", "pattern", "depth", "lines", "border", "borderWidth", "outlineGradient", "outlineGradientTo", "ornaments"])
        ok(c[k] === src.style[k], name + ": the card's " + k + " is the bar's");
    ok(c.cardOpacity === src.style.opacity, name + ": its opacity too");
    const k = Follow.cursor(src);
    for (const key in k) {
        if (key === "followed") continue;
        same(Plume.cleanValue(key, k[key]), k[key], name + ": a cursor's " + key + " " + k[key]);
    }
    ok(k.cursorSurface === src.style.surface && k.cursorOrnament === src.style.ornaments, name + ": the cursor's surface and ornaments");
    ok(k.cursorLine === (src.style.lines === "none" ? "solid" : src.style.lines), name + ": and its line");

    // there and back: a card in this look leads the bar to the look itself
    const back = Follow.fromCard(Object.assign({}, cfg0, c), src.edge);
    for (const key of Style.keys) {
        if (key === "flatSide" && (src.edge === "left" || src.edge === "right")) continue;       // a card has no such side
        if (key === "shadowColor" && src.style.shadow === "none") continue;
        if (key === "shadow" && src.style.shadowColor === "accent" && src.style.shadow === "strong") continue;
        same(back.style[key], src.style[key], name + ": back from a card, " + key);
    }
    const led = Follow.fromCursor(Object.assign({}, plume0, k), src.edge);
    for (const key of ["surface", "fill", "pattern", "depth", "ornaments", "borderWidth"])
        if (key !== "borderWidth" || src.style.lines !== "none") ok(led.style[key] === src.style[key], name + ": back from a cursor, " + key);
    for (const one of [back, led]) {
        const bar = Follow.bar(one, { mode: one.mode, customBg: "#000000", customFg: "#ffffff", accentColor: "#ff0000" });
        const cleaned = Bar.clean(Object.assign({}, Bar.defaults(), bar));
        for (const key in bar) same(cleaned[key], bar[key], name + ": a bar takes " + key + " " + bar[key]);
        const dock = Follow.dock(one, null);
        for (const key in dock) if (key in Style.settings) same(Style.cleanValue(key, dock[key]), dock[key], name + ": a dock takes " + key);
        ok(dock.style === undefined, name + ": and leaves its colors when they are its own");
    }

    // the card is painted with the colors the bar is
    const worn = wornCard(src), w = { kind: "clock", card: "auto" };
    const colors = Look.colorsFor(worn, th, w, 0, 0.5);
    const p = Look.cardParams(worn, th, colors, 200, 120, 14);
    const b = Style.params(Object.assign({}, src.style, { radius: 8 }), pal, 200, 120, 14, { edge: src.edge });
    for (const key of ["fill", "fill2", "fillStops", "lineGrad", "markGrad", "mark", "second", "splitColor", "metal", "frost", "key", "head",
                       "frameColors", "velvetSheen", "pattern", "patternColor", "depth", "light", "dark", "glass", "gradAcross"])
        same(p[key], b[key], name + ": a card's " + key + " is the bar's");
    ok(/^<svg/.test(Cursor.svgFor("left_ptr", Cursor.design(Object.assign(wornCursor(src), { cursorColor: "background", cursorColor2: "accent" }), ctx))), name + ": the cursor draws");
    const svg = Cursor.svgFor("left_ptr", Cursor.design(wornCursor(src), ctx));
    ok(!/undefined|NaN|null/.test(svg), name + ": with nothing missing");
}
for (const l of Bar.looks) checkSource(Follow.source(Bar.applyLook(Bar.defaults(), l.key), "top", "theme"), "bar look " + l.key);

const base = Object.assign(Style.defaults(), { opacity: 80, radius: 12 });
for (const key of ["ends", "surface", "lines", "ornaments", "gradientTo", "outlineGradientTo", "border", "shadow", "shadowColor", "pattern", "depth", "fill", "pointing"])
    for (const v of Style.settings[key].options)
        for (const edge of ["top", "left"]) checkSource(Follow.source(Object.assign({}, base, { [key]: v }), edge, "theme"), key + " " + v + " on the " + edge);

// a whole theme of every cursor
for (const s of ["filled", "frost", "clear", "stained"]) {
    const src = Follow.source(Object.assign({}, base, { surface: s, fill: "gradient", lines: "rope" }), "top", "theme");
    const t = Cursor.theme(Cursor.design(wornCursor(src), ctx), "plume-a", "default");
    ok(t.shapes.length > 5 && t.shapes.every(x => x.files.every(f => !/undefined|NaN/.test(f.text))), "every cursor with " + s);
}

// ---- which side is which
const side = (edge, set) => Follow.card(Follow.source(Object.assign({}, base, set), edge, "theme"));
ok(side("top", { flatSide: "edge" }).flatCorners === "top" && side("top", { flatSide: "windows" }).flatCorners === "bottom", "square corners under a top bar");
ok(side("bottom", { flatSide: "edge" }).flatCorners === "bottom" && side("left", { flatSide: "edge" }).flatCorners === "none", "and elsewhere");
ok(side("bottom", { railSide: "windows" }).railSide === "top" && side("left", { railSide: "windows" }).railSide === "right", "the rail faces the windows");

// ---- the accent tint is in the fill once
const tinted = Follow.source(Object.assign({}, base, { barTint: 20 }), "top", "theme");
const tp = Look.cardParams(wornCard(tinted), th, Look.colorsFor(wornCard(tinted), th, { kind: "clock", card: "auto" }, 0, 0.5), 200, 120, 14);
same(tp.fill, Style.params(tinted.style, pal, 200, 120, 14, { edge: "top" }).fill, "a tinted bar's card is tinted as much");

// ---- a change is seen: the cursor is made again, and only then
const k1 = Cursor.key(Cursor.design(wornCursor(Follow.source(base, "top", "theme")), ctx));
ok(k1 === Cursor.key(Cursor.design(wornCursor(Follow.source(base, "top", "theme")), ctx)), "the same look is the same cursor");
ok(k1 !== Cursor.key(Cursor.design(wornCursor(Follow.source(Object.assign({}, base, { surface: "velvet" }), "top", "theme")), ctx)), "another surface is another");
ok(k1 !== Cursor.key(Cursor.design(wornCursor(Follow.source(base, "top", "theme")), Object.assign({}, ctx, { accent: [10, 200, 90] }))), "and so is another theme");

// ---- colors
same(Follow.cursorColors(plume0, true), { cursorColor: "background", cursorColor2: "accent" }, "in the bar's shape: its fill and its accent");
const mine = Object.assign({}, plume0, { cursorColor: "custom", cursorColor2: "white", cursorLineColor: "black" });
const got = Object.assign({}, mine, Follow.cursorColors(mine, false));
ok(["custom", "white", "black"].every(x => [got.cursorColor, got.cursorColor2, got.cursorLineColor].indexOf(x) < 0), "followed colors are only the theme's");
ok(Follow.effectColors("theme", "custom") === "theme" && Follow.effectColors("theme", "palette") === "palette"
   && Follow.effectColors("borders", "custom") === "border" && Follow.effectColors("palette", "rainbow") === "palette", "the trail's too");

// ---- fonts
ok(Show.clean("font", "") === "" && Show.clean("font", "*mono") === "*mono" && Show.clean("font", "Playfair Display") === "Playfair Display", "every font option is kept");
ok(Show.clean("font", "*other") === "Inter" && Show.itemByKey.font.options.every(o => typeof Show.itemByKey.font.labels[o] === "string"), "nothing else is, and each has a name");
ok(cfg0.fontScope === "own", "styles keep their own lettering until a font is picked");

// ---- every card and every arrow can lead
for (const f of Show.itemByKey.frame.options) {
    const l = Follow.fromCard(Object.assign({}, cfg0, { frame: f }), "top");
    ok(f === "none" ? l === null : Style.settings.ends.options.indexOf(l.style.ends) >= 0, "card " + f + " leads a bar");
}
for (const a of Plume.byKey.cursorShape.options)
    ok(Style.settings.ends.options.indexOf(Follow.fromCursor(Object.assign({}, plume0, { cursorShape: a }), "top").style.ends) >= 0, "arrow " + a + " leads a bar");

// ---- a theme's look
const Match = load(R("style/Match.js"));
const cards = Match.cardKeys(Show);
ok(cards.indexOf("widgets") < 0 && cards.indexOf("enabled") < 0 && cards.indexOf("savedLooks") < 0, "it leaves the widgets alone");
ok(["frame", "surface", "font", "weight", "colorMode", "customBg", "followStyle"].every(k => cards.indexOf(k) >= 0), "and has the cards, type and colors");
same(Match.cardOf(Show, Object.assign({}, cfg0, { surface: "velvet", frame: "nonsense" })).surface, "velvet", "kept as it is");
ok(Match.cardOf(Show, { frame: "nonsense" }).frame === "none", "and checked");
const curs = Match.cursorKeys(Plume);
ok(curs.indexOf("cursorShape") >= 0 && curs.indexOf("trail") >= 0 && curs.indexOf("hideAfter") < 0 && curs.every(k => Plume.byKey[k]), "the cursor, its trail and halo");
ok(Match.clean(null) === null && Match.clean("x") === null && Match.clean({ bar: 3 }) === null, "a broken one is none");
same(Match.clean({ bar: {}, now: "x", ui: 5, docks: [1, {}] }), { bar: {}, docks: [{}], now: "bar", nowDock: 0 }, "a half broken one is what is left of it");
const Looks = load(R("style/AequalynLooks.js"));
ok(Match.pickFor("gold", Looks.bar) === Match.pickFor("gold", Looks.bar) && Bar.lookByKey[Match.pickFor("gold", Looks.bar)], "a picked look is the same every time");
ok(new Set(["gold", "ruby", "cobalt", "mirage", "opal", "reef"].map(t => Match.pickFor(t, Looks.bar))).size > 3, "and not the same for all");
const many = {}; for (let i = 0; i < 230; i++) many["t" + i] = {};
const kept = Match.trim(many, "t0");
ok(Object.keys(kept).length === 200 && kept.t0 && kept.t229 && !kept.t1, "the oldest go first, never the one that is on");

// ---- rows that wait
for (const k of ["frame", "surface", "lines", "ornaments", "shadow"])
    ok(Show.itemByKey[k].when.some(c => c.key === "followStyle"), k + " waits while it is followed");
ok(!Show.itemByKey.padding.when.some(c => c.key === "followStyle") && Show.itemByKey.colorMode.when.some(c => c.key === "followColors"), "the room inside is yours; the colors wait");
ok(!Plume.active(Plume.byKey.cursorSurface, Object.assign({}, plume0, { pointerTheme: Plume.MINE, followStyle: "bar" }))
   && Plume.active(Plume.byKey.cursorSurface, Object.assign({}, plume0, { pointerTheme: Plume.MINE })), "so do the cursor's");
console.log("follow: " + n + " ok");
