const fs = require("fs");
const path = require("path");
const root = path.resolve(__dirname, "..");
function read(p) { return fs.readFileSync(path.join(root, p), "utf8"); }
let pass = 0, fail = 0;
function ok(cond, msg) { if (cond) { pass++; console.log("ok - " + msg); } else { fail++; console.log("not ok - " + msg); } }

const pm = read("PluginManager.qml");
ok(pm.includes("quickshell-config-swap"), "PluginManager watches config swap marker");
ok(pm.includes("configSwapActive"), "PluginManager exposes config swap active state");
ok(pm.includes("Plugin failed to load during config swap:"), "swap failures are logged as transient");
ok(pm.includes("scheduleSwapRetry"), "swap failures schedule retry");
ok(pm.includes("Retrying plugin after config swap:"), "swap retry is logged");
ok(!/turnOffFailed\(id\)\s*\n\s*return\s*\n\s*\}\s*\n\s*pm\.loadFailFirst/.test(pm) || pm.includes("if (pm.configSwapActive) {"), "swap active path avoids disable");
ok(pm.includes("if (pm.configSwapActive) return"), "grace timer skips while swap active");

console.log(`\n# ${pass} pass, ${fail} fail`);
if (fail) process.exit(1);
