// node tests/sandbox-settings.test.js -- settings of sandboxed plugins (night
// light, battery guard, breaks, disk watch) must be reachable from the main
// shell. Their KitStore lives in the watchdog process, so KitHost.get() is null
// there and the Settings page used to write into thin air.
const assert = require("assert");
const fs = require("fs");
const path = require("path");

let n = 0;
const ok = (c, msg) => { assert.ok(c, msg); n++; };
const root = path.join(__dirname, "..");
const read = f => fs.readFileSync(path.join(root, f), "utf8");

const bridge = read("plugins/kit/SandboxSettings.qml");
const host = read("tools/watchdog/host/shell.qml");
const page = read("settings/center/PluginSettings.qml");
const quick = read("plugins/bar/widgets/BrightnessQuick.qml");
const kit = read("plugins/kit/qmldir");

ok(kit.includes("singleton SandboxSettings 1.0 SandboxSettings.qml"),
    "the bridge is a shared singleton");

for (const marker of [
    "function value(id, key, fallback)",
    "function setValue(id, key, value)",
    "function refresh(id)",
    '"/aequalyn/watchdog/hosts/" + id',
    '"qs", "ipc", "-p", bridge.hostPath(id), "call", "sandbox",',
    '"set", id, key, JSON.stringify(value)',
    '"settings", id',
    "if (plugin && plugin.settingsStore) return plugin.settingsStore.get(key)"
]) ok(bridge.includes(marker), "bridge wires " + marker);

for (const marker of [
    "function settings(pluginId: string): string",
    "function set(pluginId: string, key: string, value: string): string",
    "JSON.stringify(store.values)",
    "store.set(key, v)"
]) ok(host.includes(marker), "sandbox host exposes " + marker);

ok(!page.includes("KitHost.get"), "Settings no longer reads the sandbox store in-process");
for (const marker of [
    "SandboxSettings.value(ps.plugin, key, fallback)",
    "SandboxSettings.setValue(ps.plugin, key, value)",
    "Component.onCompleted: SandboxSettings.refresh(ps.plugin)",
    "onPluginChanged: SandboxSettings.refresh(ps.plugin)",
    "onOnChanged: if (ps.on) SandboxSettings.refresh(ps.plugin)"
]) ok(page.includes(marker), "plugin settings page uses the bridge: " + marker);

ok(!quick.includes("KitHost.get(\"nightLight\")"), "quick panel no longer reads a null nightLight store");
for (const marker of [
    'SandboxSettings.value("nightLight", "mode", "")',
    'SandboxSettings.refresh("nightLight")',
    'SandboxSettings.setValue("nightLight", "mode", "on")',
    'SandboxSettings.setValue("nightLight", "mode", "off")',
    'SandboxSettings.setValue("nightLight", "mode", "schedule")'
]) ok(quick.includes(marker), "quick panel uses the bridge: " + marker);

console.log("sandbox-settings: " + n + " checks passed");
