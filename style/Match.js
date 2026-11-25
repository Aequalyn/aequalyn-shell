.pragma library

// A theme's look, taken down and put back (plugins/kit/KitMatch.qml). Plain functions, so
// they can be tested. Each part is checked again by its owner when it is put on.

var MAX = 200;

function isObject(v) { return !!v && typeof v === "object" && !Array.isArray(v); }

// one kept look, or null
function clean(l) {
    if (!isObject(l)) return null;
    var out = {}, any = false;
    ["bar", "showcase", "cursor"].forEach(function (k) { if (isObject(l[k])) { out[k] = l[k]; any = true; } });
    if (Array.isArray(l.docks)) out.docks = l.docks.filter(isObject).slice(0, 16);
    ["ui", "mono"].forEach(function (k) { if (typeof l[k] === "string" && l[k].length <= 80) out[k] = l[k]; });
    out.now = ["bar", "dock", "showcase", "cursor"].indexOf(l.now) >= 0 ? l.now : "bar";
    out.nowDock = typeof l.nowDock === "number" ? l.nowDock : 0;
    return any ? out : null;
}

// Showcase's cards, type and colors: not which widgets there are, nor how they move or where
var cardTabs = ["Shape", "Surface", "Lines", "Ornaments", "Type", "Colors", "Follow"];
function cardKeys(schema) {
    var out = [];
    schema.groups.forEach(function (g) {
        if (cardTabs.indexOf(g.title) < 0) return;
        g.items.forEach(function (it) {
            if (it.kind === "palette") it.targets.forEach(function (t) { out.push(t.key); });
            else out.push(it.key);
        });
    });
    return out.concat(["presetColors", "lastLook"]);
}
function cardOf(schema, cfg) {
    var out = {};
    cardKeys(schema).forEach(function (k) { if (cfg[k] !== undefined) out[k] = schema.clean(k, cfg[k]); });
    return out;
}

// the cursor, its trail and its halo: not how it hides, nor the panel
function cursorKeys(schema) { return schema.cursorKeys.concat(schema.lookKeys, ["pointerTheme", "pointerSize", "followColors", "followStyle"]); }
function cursorOf(schema, cfg) {
    var out = {};
    cursorKeys(schema).forEach(function (k) { if (cfg[k] !== undefined) out[k] = schema.cleanValue(k, cfg[k]); });
    return out;
}

// no more than MAX kept, and never the one that is on
function trim(looks, keep) {
    var keys = Object.keys(looks), out = {};
    var drop = Math.max(0, keys.length - MAX);
    keys.forEach(function (k) { if (drop > 0 && k !== keep) { drop--; return; } out[k] = looks[k]; });
    return out;
}

// one of `list` for an id: the same one every time
function pickFor(id, list) {
    var h = 5381;
    for (var i = 0; i < id.length; i++) h = ((h * 33) ^ id.charCodeAt(i)) >>> 0;
    return list[h % list.length].key;
}
