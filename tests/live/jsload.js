// Loads a QML JavaScript library (.pragma library / .import) in Node, so the
// style engine can be tested without a Qt build.
const fs = require("fs");
const path = require("path");
const cache = {};

function load(file) {
  const f = path.resolve(file);
  if (cache[f]) return cache[f];
  const ns = {};
  cache[f] = ns;
  const imports = [];
  let src = fs.readFileSync(f, "utf8")
    .replace(/^\.pragma.*$/m, "")
    .replace(/^\.import\s+"([^"]+)"\s+as\s+(\w+)\s*$/gm, (m, p, n) => { imports.push([p, n]); return ""; });
  const names = [...src.matchAll(/^(?:var|function)\s+(\w+)/gm)].map(m => m[1]);
  const args = imports.map(i => i[1]);
  const vals = imports.map(i => load(path.join(path.dirname(f), i[0])));
  Object.assign(ns, new Function(...args, src + "\nreturn {" + names.join(",") + "};")(...vals));
  return ns;
}

module.exports = load;
