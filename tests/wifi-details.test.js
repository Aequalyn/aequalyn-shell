// node tests/wifi-details.test.js -- clicking a Wi-Fi network opens its details:
// credentials, saved-password reveal through the root gate, Forget, and a
// fast.com speed test drawn as two half-dial gauges.
const assert = require("assert");
const fs = require("fs");
const path = require("path");
const cp = require("child_process");

let n = 0;
const ok = (c, msg) => { assert.ok(c, msg); n++; };
const root = path.join(__dirname, "..");
const read = f => fs.readFileSync(path.join(root, f), "utf8");

const page = read("settings/center/pages/Wifi.qml");
const service = read("plugins/wifi/WifiService.qml");
const gauge = read("settings/center/SpeedGauge.qml");
const qmldir = read("settings/center/qmldir");
const plugins = read("Plugins.js");

// -- clicking a row selects it, buttons still act immediately ---------------
for (const marker of [
    "property string selectedSsid: \"\"",
    "readonly property var selectedNetwork: WifiService.networkForSsid(page.selectedSsid)",
    "clickable: true",
    "onClicked: page.selectNetwork(modelData)",
    'title: "Network details"',
    'text: "Forget"',
    "WifiService.forgetNetwork(page.selectedNetwork)"
]) ok(page.includes(marker), "Wi-Fi page wires " + marker);

// -- editing saved credentials and revealing the saved password -------------
for (const marker of [
    "function updateCredentials(ssid, identity, password, caCert)",
    '"802-11-wireless-security": { psk: String(password) }',
    "function revealPassword(ssid)",
    "wifi-reveal.json",
    "exec-root --as settings wifi-reveal-password",
    '"id": "wifi-reveal-password"',
    '"/usr/local/bin/aequalyn-wifi-secrets"'
]) {
    const found = page.includes(marker) || service.includes(marker) || plugins.includes(marker);
    ok(found, "credentials/reveal path includes " + marker);
}

const secrets = path.join(root, "tools/wifi/aequalyn-wifi-secrets");
ok((fs.statSync(secrets).mode & 0o111) !== 0, "the secrets helper is executable");
const secretsSrc = read("tools/wifi/aequalyn-wifi-secrets");
for (const marker of [
    "SUDO_USER",
    "wifi-reveal.json",
    'for setting, key in (("802-11-wireless-security", "psk"), ("802-1x", "password"))',
    "os.unlink(path)"
]) ok(secretsSrc.includes(marker), "secrets helper: " + marker);
let r = cp.spawnSync("python3", [secrets], {
    input: "", encoding: "utf8", env: Object.assign({}, process.env, { SUDO_USER: "" }), timeout: 10000
});
ok(r.status !== 0 && JSON.parse(r.stdout).ok === false, "the helper refuses callers without SUDO_USER");

// -- fast.com speed test and the two gauges ---------------------------------
for (const marker of [
    "function runSpeedTest()",
    "function stopSpeedTest()",
    "property real speedDownload: 0",
    "property real speedUpload: 0",
    "onRunningChanged: root.speedRunning = running",
    'd.phase === "download"',
    'd.phase === "upload"',
    "aequalyn-wifi-speed",
    'text: \'Measured with <a href="https://fast.com">fast.com</a>\''
]) ok(service.includes(marker) || page.includes(marker), "speed test wires " + marker);

for (const marker of [
    "property real value: 0",
    "ctx.arc(cx, cy, r, Math.PI, 2 * Math.PI)",
    "ctx.arc(cx, cy, r, Math.PI, Math.PI + Math.PI * gauge.ratio)",
    "label: \"DOWNLOAD\"",
    "label: \"UPLOAD\""
]) ok(gauge.includes(marker) || page.includes(marker), "gauges render " + marker);
ok(qmldir.includes("SpeedGauge 1.0 SpeedGauge.qml"), "the gauge type is registered in qmldir");

const speed = path.join(root, "tools/wifi/aequalyn-wifi-speed");
ok((fs.statSync(speed).mode & 0o111) !== 0, "the speed helper is executable");
r = cp.spawnSync("python3", [speed, "--self-test"], { encoding: "utf8", timeout: 10000 });
ok(r.status === 0 && JSON.parse(r.stdout).selfTest === true, "speed helper self-test passes");
const speedSrc = read("tools/wifi/aequalyn-wifi-speed");
for (const marker of [
    "https://api.fast.com/netflix/speedtest/v2",
    'RANGE = "/range/0-26214400"',
    "def upload_worker(",
    '"provider": "fast.com"'
]) ok(speedSrc.includes(marker), "speed helper uses fast.com: " + marker);

// -- installs ship both the PATH helpers and the pinned root helper ----------
const installer = path.join(path.dirname(root), "aequalyn/install.sh");
const apply = path.join(path.dirname(root), "aequalyn-installer/lib/apply.sh");
if (fs.existsSync(installer)) {
    const text = fs.readFileSync(installer, "utf8");
    for (const f of ["aequalyn-wifi-speed", "aequalyn-wifi-eap", "aequalyn-wifi-secrets"])
        ok(text.includes(f), "install.sh ships " + f);
}
if (fs.existsSync(apply)) {
    const text = fs.readFileSync(apply, "utf8");
    for (const f of ["aequalyn-wifi-speed", "aequalyn-wifi-secrets"])
        ok(text.includes(f), "the ISO installer ships " + f);
}

console.log("wifi-details: " + n + " checks passed");
