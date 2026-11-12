// node tests/looks.test.js -- every look, dock look and ensemble is valid and
// survives cleaning; the bar starts as Horizon; layouts never overlap.
const assert = require("assert");
const path = require("path");
const load = require("./jsload.js");
const S = p => path.join(__dirname, "../style", p);
const Looks = load(S("AequalynLooks.js"));
const Bar = load(S("BarLooks.js"));
const Style = load(S("Style.js"));
const Shapes = load(S("Shapes.js"));

let n = 0;
const ok = (c, msg) => { assert.ok(c, msg); n++; };

ok(Bar.lookOf(Bar.defaults()) === "horizon", "the bar starts as Horizon");

const seen = new Set();
for (const l of Looks.bar) {
  ok(!seen.has(l.key), "unique bar key " + l.key); seen.add(l.key);
  ok(Looks.byKey(Looks.families, l.family), "family of " + l.key);
  const c = Bar.applyLook(Bar.defaults(), l.key);
  for (const k in l.set) ok(JSON.stringify(c[k]) === JSON.stringify(l.set[k]), l.key + "." + k + " survives cleaning");
  ok(Bar.lookOf(c) === l.key, "recognised: " + l.key);
}
for (const l of Looks.dock) {
  const d = Looks.dockSet(l.key);
  for (const k in l.set) ok(d[k] === l.set[k], "dock " + l.key + "." + k + " survives cleaning");
  ok(Looks.dockLookOf(d) === l.key, "recognised dock look: " + l.key);
}
for (const e of Looks.ensembles) {
  ok(Looks.byKey(Looks.bar, e.bar), "ensemble " + e.key + " bar look exists");
  ok(e.dock === "follow" || Looks.byKey(Looks.dock, e.dock), "ensemble " + e.key + " dock look exists");
}

// colors survive a look
const mine = Object.assign(Bar.defaults(), { colorMode: "custom", customBg: "#1a1b26" });
ok(Bar.applyLook(mine, "ember").customBg === "#1a1b26", "a look keeps your colors");

// shapes stay inside the bar and don't overlap, for every look
const slots = [[10, 40, "left"], [56, 120, "left"], [900, 140, "center"], [1700, 60, "right"], [1770, 120, "right"]]
  .map(([a, len, region]) => ({ a, len, region, hovered: false, open: false }));
for (const l of Looks.bar) {
  const c = Bar.applyLook(Bar.defaults(), l.key);
  const out = Shapes.layout({ length: 1920, thickness: Shapes.thicknessFor(32, c), barSize: 32, edgeAtStart: true }, slots, c);
  const base = out.shapes.filter(s => s.role === "base").sort((a, b) => a.a - b.a);
  ok(base.length > 0, l.key + " paints something");
  for (let i = 0; i < base.length; i++) {
    ok(base[i].a >= 0 && base[i].a + base[i].len <= 1920, l.key + " stays inside");
    if (i > 0) ok(base[i].a >= base[i - 1].a + base[i - 1].len, l.key + " shapes don't overlap");
  }
}

console.log("ok", n, "checks");
