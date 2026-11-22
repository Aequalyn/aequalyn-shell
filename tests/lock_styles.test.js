// node tests/lock_styles.test.js -- lock plugin style/settings wiring.
const assert = require("assert");
const fs = require("fs");
const path = require("path");

const root = path.join(__dirname, "..");
const read = p => fs.readFileSync(path.join(root, p), "utf8");

let n = 0;
const ok = (c, msg) => { assert.ok(c, msg); n++; };

const styles = [
  "classic","clean","mono","corner","pill","split","stack","dot","frame","glass",
  "line","terminal","neon","poster","orbit","dashboard","zen","vertical","duo","card",
  "nowplaying","binary","words","day","calendar","weather","quote","avatar","battery"
];

const lockView = read("plugins/lock/LockView.qml");
const lockService = read("plugins/lock/LockService.qml");
const lockQml = read("plugins/lock/Lock.qml");
const sleepPage = read("settings/center/pages/Sleep.qml");

// LockView interface
ok(/property bool use24h/.test(lockView), "LockView exposes use24h");
ok(/property string lockStyle/.test(lockView), "LockView exposes lockStyle");
ok(/property string userName/.test(lockView), "LockView exposes userName");
ok(/signal submitPassword\(string value\)/.test(lockView), "LockView submits password");
ok(/signal triggerGlance\(\)/.test(lockView), "LockView triggers glance");
ok(/property bool glanceScanning/.test(lockView), "LockView exposes glanceScanning");

// use24h formatting
ok(/timeFormat/.test(lockView) && /use24h \? "HH:mm" : "h:mm AP"/.test(lockView), "LockView respects use24h");

// style coverage
for (const style of styles) {
  ok(lockView.includes('"' + style + '"'), "LockView knows style: " + style);
}
ok(lockView.includes('return known.indexOf(s) >= 0 ? s : "classic"'), "LockView falls back to classic");

// LockService wiring
ok(/property bool use24h/.test(lockService), "LockService exposes use24h");
ok(/property string lockStyle/.test(lockService), "LockService exposes lockStyle");
ok(/use24h: root.use24h/.test(lockService), "LockService passes use24h to LockView");
ok(/lockStyle: root.lockStyle/.test(lockService), "LockService passes lockStyle to LockView");
ok(/function triggerGlanceScan\(\)/.test(lockService), "LockService exposes glance scan");
ok(/glancectl/.test(lockService), "LockService calls glancectl");

// Lock.qml settings sync
ok(/AequalynSettings.use24h/.test(lockQml), "Lock.qml reads use24h");
ok(/AequalynSettings.lockStyle/.test(lockQml), "Lock.qml reads lockStyle");
ok(/LockService.use24h/.test(lockQml), "Lock.qml syncs use24h");
ok(/LockService.lockStyle/.test(lockQml), "Lock.qml syncs lockStyle");

// Sleep settings page exposes all styles
for (const style of styles) {
  ok(sleepPage.includes('key: "' + style + '"'), "Sleep page exposes style: " + style);
}

console.log("ok", n, "checks");
