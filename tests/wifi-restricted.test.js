// node tests/wifi-restricted.test.js -- restricted Wi-Fi: the Settings switch,
// captive-portal hand-off on Wayland, enterprise (eduroam) credentials, and the
// libnm helper that never puts a password in argv.
const assert = require("assert");
const fs = require("fs");
const path = require("path");
const cp = require("child_process");

let n = 0;
const ok = (c, msg) => { assert.ok(c, msg); n++; };
const root = path.join(__dirname, "..");
const read = f => fs.readFileSync(path.join(root, f), "utf8");

const settings = read("settings/AequalynSettings.qml");
const service = read("plugins/wifi/WifiService.qml");
const page = read("settings/center/pages/Wifi.qml");

// -- the permission switch is one persisted setting -------------------------
for (const marker of [
    "property bool wifiAllowRestricted: false",
    "allowRestricted: root.wifiAllowRestricted",
    "root.wifiAllowRestricted = pick(w.allowRestricted, false) === true"
]) ok(settings.includes(marker), "AequalynSettings persists " + marker);

for (const marker of [
    'setting: "wifiAllowRestricted"',
    'title: "Allow restricted networks"'
]) ok(page.includes(marker), "Wi-Fi page shows " + marker);

// -- captive portals: NM's PORTAL state, opened in the default browser ------
for (const marker of [
    "import Quickshell.Networking",
    "root.connectivity === NetworkConnectivity.Portal",
    'readonly property string captivePortalUrl: "http://neverssl.com/"',
    'Quickshell.execDetached(["xdg-open", root.captivePortalUrl])',
    "function onConnectivityChanged()",
    "root.maybeOpenPortal()",
    "Networking.checkConnectivity()"
]) ok(service.includes(marker), "WifiService handles portals: " + marker);
ok(service.indexOf("function maybeOpenPortal()") < service.indexOf("target: Networking"),
    "the portal guard is defined before the connectivity watcher");
ok(service.includes("if (!root.allowRestricted || !root.portalDetected || root.portalHandled) return"),
    "auto-open needs both the switch and a fresh PORTAL transition");

for (const marker of [
    "WifiService.portalDetected",
    'text: "Open login page"',
    'text: "I\'ve signed in — check again"',
    "WifiService.recheckConnectivity()"
]) ok(page.includes(marker), "Wi-Fi page offers " + marker);

// -- enterprise networks -----------------------------------------------------
for (const marker of [
    "security === WifiSecurityType.WpaEap || security === WifiSecurityType.Wpa2Eap",
    "function connectWithEap(network, identity, password, caCert)",
    "root.eapProc.write(root.eapPending)",
    "stdinEnabled: true"
]) ok(service.includes(marker), "WifiService joins EAP: " + marker);
ok(service.includes("root.eapPending = JSON.stringify({"), "credentials are sent on stdin, not in the command");

for (const marker of [
    "property bool askingEnterprise: false",
    "WifiService.isEnterprise(modelData.security)",
    'placeholder: "Username, e.g. user@example.edu"',
    'placeholder: "CA certificate file (optional)"',
    "WifiService.connectWithEap(net, eapIdentity.text, password.text, eapCa.text)",
    'text: page.askingEnterprise ? "Sign in" : "Join"'
]) ok(page.includes(marker), "Wi-Fi page offers " + marker);

// -- the helper itself -------------------------------------------------------
const helper = path.join(root, "tools/wifi/aequalyn-wifi-eap");
ok((fs.statSync(helper).mode & 0o111) !== 0, "the EAP helper is executable");
const source = read("tools/wifi/aequalyn-wifi-eap");
ok(source.includes("add_and_activate_connection_async"), "profile is added and activated in one call");
ok(source.includes("sys.stdin.read"), "credentials come from stdin");
ok(!source.includes("subprocess"), "the helper never spawns nmcli with a password");

const run = request => cp.spawnSync("python3", [helper], {
    input: JSON.stringify(request), encoding: "utf8", timeout: 15000
});
const valid = { ssid: "eduroam", identity: "user@example.edu", password: "s3cr3t",
    caCert: "/etc/ssl/certs/ca-certificates.crt", dryRun: true };
let r = run(valid);
ok(r.status === 0, "a valid dry run succeeds");
let payload = JSON.parse(r.stdout);
ok(payload.ok === true && payload.dryRun === true, "dry run reports what it would do");
ok(payload.settings["802-11-wireless-security"]["key-mgmt"] === "wpa-eap", "the profile uses WPA-Enterprise");
ok(JSON.stringify(payload.settings["802-1x"].eap) === '["peap"]', "the EAP method is PEAP");
ok(payload.settings["802-1x"]["phase2-auth"] === "mschapv2", "phase 2 is MSCHAPv2");
ok(payload.settings["802-1x"]["ca-cert"] === valid.caCert, "the CA certificate is passed through");
ok(!r.stdout.includes("s3cr3t"), "the dry-run output redacts the password");

r = run(Object.assign({}, valid, { caCert: "relative.pem" }));
ok(r.status !== 0 && JSON.parse(r.stdout).ok === false, "a relative CA path is rejected");

r = run(Object.assign({}, valid, { identity: "" }));
ok(r.status !== 0 && /identity/.test(JSON.parse(r.stdout).error), "an identity is required");

// -- installs link the helper on PATH (optional: sibling repos) --------------
const installer = path.join(path.dirname(root), "aequalyn/install.sh");
const apply = path.join(path.dirname(root), "aequalyn-installer/lib/apply.sh");
if (fs.existsSync(installer))
    ok(fs.readFileSync(installer, "utf8").includes("aequalyn-wifi-eap"), "install.sh links the helper");
if (fs.existsSync(apply))
    ok(fs.readFileSync(apply, "utf8").includes("aequalyn-wifi-eap"), "the ISO installer links the helper");

console.log("wifi-restricted: " + n + " checks passed");
