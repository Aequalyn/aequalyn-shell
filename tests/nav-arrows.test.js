// node tests/nav-arrows.test.js -- ← → move between the square rail and the
// text list beside it in Control Center and Store. ↑ ↓ then move in whichever
// list was picked. The install chooser keeps its own two lists unchanged.
const assert = require("assert");
const fs = require("fs");
const path = require("path");

let n = 0;
const ok = (c, msg) => { assert.ok(c, msg); n++; };
const root = path.join(__dirname, "..");
const read = f => fs.readFileSync(path.join(root, f), "utf8");
const center = read("settings/ControlCenter.qml");
const store = read("plugins/store/Store.qml");
const chooser = read("plugins/installMenu/InstallLists.qml");

for (const marker of [
    'property string navSide: "pages"',
    "function focusRail()",
    "function focusPages()",
    'event.key === Qt.Key_Left && !root.searching',
    'event.key === Qt.Key_Right && !root.searching',
    'root.navSide === "rail" && !root.searching',
    'root.navSide = side.visible ? "pages" : "rail"',
    'border.width: cat.on || (root.navSide === "rail"',
    'border.width: root.navSide === "pages" && side.visible',
    "← →  rail / list"
]) {
    ok(center.includes(marker), "Control Center wires " + marker);
}

for (const marker of [
    'property string navSide: "sections"',
    "function focusRail()",
    "function focusSections()",
    "function stepCategory(delta)",
    "function stepSection(delta)",
    "root.queryActive || root.pickOpen || root.appPage || titleSearch.activeFocus",
    "} else if (event.key === Qt.Key_Left) {",
    "} else if (event.key === Qt.Key_Right) {",
    'if (root.navSide === "rail") root.stepCategory(-1); else root.stepSection(-1);',
    'if (root.navSide === "rail") root.stepCategory(1); else root.stepSection(1);',
    'root.navSide === "rail" && !root.queryActive && !root.pickOpen && !root.appPage',
    'root.navSide === "sections" && sectionNav.visible',
    "← →  rail / list"
]) {
    ok(store.includes(marker), "Store wires " + marker);
}

for (const marker of [
    "function focusCategory()",
    "function focusOptions()",
    "event.key === Qt.Key_Left",
    "event.key === Qt.Key_Right"
]) {
    ok(chooser.includes(marker), "the install chooser keeps " + marker);
}

for (const word of ["omarchy", "omaudix", "baroque", "multi-docks", "qempexe"]) {
    ok(!(center + store).toLowerCase().includes(word), "no " + word + " wording in the navigation");
}

console.log("nav arrows: " + n + " ok");
