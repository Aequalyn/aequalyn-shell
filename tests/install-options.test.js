// node tests/install-options.test.js -- the install chooser's catalogue stays
// complete, unique and safe: every group has choices, every package name is a
// plain one, and no source-branded wording leaks into the UI.
const assert = require("assert");
const path = require("path");
const load = require("./jsload.js");
const O = load(path.join(__dirname, "../plugins/installMenu/InstallOptions.js"));
const PackageIds = load(path.join(__dirname, "../plugins/store/PackageIds.js"));

let n = 0;
const ok = (c, msg) => { assert.ok(c, msg); n++; };

const wanted = ["all", "ai", "service", "development", "editor", "style", "gaming", "browser", "terminal", "other"];
ok(JSON.stringify(O.categories.map(c => c.key)) === JSON.stringify(wanted), "the nine groups are there, in order");

const ids = O.options.map(o => o.id);
ok(new Set(ids).size === ids.length, "every choice has a unique id");
ok(ids.indexOf("system-install") < 0, "the fresh-system install is not a Super + I choice");
ok(O.options.every(o => o.label !== "Install Aequalyn"), "no fresh-system install label in the chooser");
// These open a picker or a sign-in page, so there is nothing to take back off.
const withoutRemove = ["svc-chromium-account", "style-theme", "style-background", "game-retro-launcher"];
for (const o of O.options) {
    ok(wanted.indexOf(o.category) >= 0, o.id + " is in a known group");
    ok(typeof o.label === "string" && o.label.length > 0, o.id + " has a name");
    ok(Array.isArray(o.cmd) && o.cmd.length > 0, o.id + " has a command");
    if (o.cmd[0] === "qs" && o.cmd[4] === "package") {
        ok(/^[A-Za-z0-9@._+-]{1,128}$/.test(o.cmd[6]), o.id + " uses a plain package name");
    }
    const rem = O.uninstall(o);
    if (withoutRemove.indexOf(o.id) >= 0) {
        ok(rem.length === 0, o.id + " has nothing to remove");
    } else {
        ok(Array.isArray(rem) && rem.length > 0, o.id + " has a remove command");
        if (o.cmd[0] === "qs" && o.cmd[4] === "package") {
            ok(rem[4] === "remove" && rem[5] === o.cmd[5] && rem[6] === o.cmd[6],
                o.id + " removes the same package it installs");
        } else if (o.cmd[0] === "aequalyn-ai-tool") {
            ok(rem[0] === "aequalyn-ai-tool" && rem[1] === "remove" && rem[2] === o.cmd[2],
                o.id + " removes the same agent it installs");
        } else if (o.cmd[0] === "aequalyn-webapp") {
            ok(rem[0] === "aequalyn-webapp" && rem[1] === "remove" && rem[2] === "--name",
                o.id + " removes the web app it adds");
        }
    }
}
for (const key of wanted.slice(1)) {
    ok(O.options.filter(o => o.category === key).length >= 4, key + " has choices of its own");
    const apps = O.options.filter(o => o.category === key && o.cmd[0] === "qs" && o.cmd[4] === "package");
    ok(apps.length >= 30, key + " has thirty installable apps");
}
const packaged = O.options.filter(o => o.cmd[0] === "qs" && o.cmd[4] === "package");
let flatpakCount = 0, snapCount = 0;
for (const o of packaged) {
    const alt = PackageIds.forOption(o);
    ok(typeof alt.flatpak === "string" && typeof alt.snap === "string",
        o.id + " has Flatpak and Snap id fields");
    if (alt.flatpak) {
        ok(/^[A-Za-z0-9._-]{3,128}$/.test(alt.flatpak), o.id + " uses a plain Flatpak id");
        flatpakCount++;
    }
    if (alt.snap) {
        ok(/^[a-z0-9][a-z0-9-]{1,127}$/.test(alt.snap), o.id + " uses a plain Snap id");
        snapCount++;
    }
}
ok(flatpakCount >= 60, "most category apps have a Flatpak path");
ok(snapCount >= 60, "most category apps have a Snap path");

for (const o of O.options.filter(x => x.category !== "all")) {
    const also = O.related(o);
    ok(also.length > 0 && also.indexOf(o.label) < 0, o.id + " has a see-also list without itself");
}

// The chooser's live state: one sweep says what is here, so install cannot run
// twice and remove cannot offer something that is gone. Flatpak/Snap editions
// of a curated app and agents installed outside the tool count as installed.
const stateText = [
    "#pacman", "firefox", "codex",
    "#flatpak", "com.visualstudio.code",
    "#snap",
    "#agents", JSON.stringify([
        { id: "codex", installed: true },
        { id: "opencode", installed: false, availableElsewhere: true,
          systemManager: "pacman", systemId: "opencode" }
    ]),
    "#webapps", JSON.stringify({ apps: [{ name: "Microsoft 365" }] }),
    "#containers", "aequalyn-postgres"
].join("\n");
const state = O.stateFromText(stateText);
const choice = id => O.options.find(o => o.id === id);
ok(state.ready && state.pacman.indexOf("firefox") >= 0 && state.agents.length === 2
    && state.webapps[0] === "Microsoft 365", "the state sweep parses every section");
ok(!O.blankState().ready && O.options.every(o => !O.isInstalled(o, O.blankState())),
    "a state that has not arrived blocks every action");
ok(O.isInstalled(choice("web-firefox"), state) && !O.isInstalled(choice("web-chrome"), state),
    "an installed package is known and an absent one is not");
ok(JSON.stringify(O.removal(choice("web-firefox"), state))
    === JSON.stringify(["qs", "ipc", "call", "store", "remove", "arch", "firefox"]),
    "removing that package goes through the same Store path");
ok(O.installedVia(choice("ed-vscode"), state) === "flatpak"
    && O.removal(choice("ed-vscode"), state)[6] === "com.visualstudio.code",
    "a Flatpak edition of a curated app removes by its Flatpak id");
ok(O.isInstalled(choice("ai-codex"), state)
    && O.removal(choice("ai-codex"), state)[0] === "aequalyn-ai-tool",
    "an agent installed by its tool is known and removes by its tool");
ok(O.installedVia(choice("ai-opencode"), state) === "system:pacman"
    && JSON.stringify(O.removal(choice("ai-opencode"), state))
    === JSON.stringify(["qs", "ipc", "call", "store", "remove", "arch", "opencode"]),
    "an agent installed by pacman is known and removes through the Store");
ok(O.isInstalled(choice("svc-microsoft"), state)
    && O.removal(choice("svc-microsoft"), state)[1] === "remove",
    "an existing web app is known and removes by name");
ok(O.isInstalled(choice("dev-docker-db"), state)
    && O.removal(choice("dev-docker-db"), state).length > 0,
    "the setup container is known and can be taken back off");

const text = JSON.stringify({ categories: O.categories, options: O.options });
for (const word of ["omarchy", "omaudix", "baroque", "multi-docks", "qempexe"]) {
    ok(!text.toLowerCase().includes(word), "no " + word + " wording in the chooser");
}

console.log("install options: " + n + " ok");
