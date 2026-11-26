// node tests/watchdog-session.test.js -- a supervisor never outlives its Hyprland session
const fs = require("fs"), os = require("os"), path = require("path"), cp = require("child_process");
const wd = path.join(__dirname, "../tools/watchdog/aequalyn-watchdog");
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "aqwd"));
let fails = 0;
const ok = (c, what) => { if (!c) { fails++; console.log("FAIL", what); } };
for (const d of ["bin", "run", "home/.config/quickshell"]) fs.mkdirSync(path.join(tmp, d), { recursive: true });
fs.writeFileSync(path.join(tmp, "home/.config/quickshell/shell.qml"), "");
fs.writeFileSync(path.join(tmp, "bin/qs"), '#!/bin/bash\n[ "$1" = ipc ] && { echo pong; exit 0; }\nexec -a qs python3 -c "import time; time.sleep(120)" "$@"\n', { mode: 0o755 });
const config = tmp + "/home/.config/quickshell";
const session = sig => {                                // a running Hyprland: its socket
    fs.mkdirSync(path.join(tmp, "run/hypr", sig), { recursive: true });
    fs.writeFileSync(path.join(tmp, "run/hypr", sig, ".socket.sock"), "");
};
const logout = sig => fs.rmSync(path.join(tmp, "run/hypr", sig, ".socket.sock"));
const envOf = sig => ({ HOME: tmp + "/home", XDG_RUNTIME_DIR: tmp + "/run", PATH: tmp + "/bin:" + process.env.PATH,
                        LANG: "C.UTF-8", HYPRLAND_INSTANCE_SIGNATURE: sig });
const run = (sig, ...a) => cp.spawnSync("python3", [wd, ...a], { env: envOf(sig), encoding: "utf8", timeout: 60000 });
const procs = (what, sig) => fs.readdirSync("/proc").filter(p => /^\d+$/.test(p)).filter(p => {
    try {
        const env = fs.readFileSync(`/proc/${p}/environ`, "utf8");
        return fs.readFileSync(`/proc/${p}/cmdline`, "utf8").includes(what)
            && env.includes("XDG_RUNTIME_DIR=" + tmp + "/run") && (!sig || env.includes("HYPRLAND_INSTANCE_SIGNATURE=" + sig + "\0"));
    } catch (e) { return false; }
}).map(Number);
const all = () => fs.readdirSync("/proc").filter(p => /^\d+$/.test(p)).filter(p => {
    try { return fs.readFileSync(`/proc/${p}/environ`, "utf8").includes("XDG_RUNTIME_DIR=" + tmp); } catch (e) { return false; }
}).map(Number);
const sleep = s => cp.spawnSync("sleep", [String(s)]);
try {
    // a logout: the supervisor leaves, and takes its shell with it
    session("A");
    ok(run("A", "start").status === 0, "it starts");
    sleep(1);
    ok(procs("aequalyn-watchdog", "A").length === 1 && procs("import time", "A").length === 1, "one supervisor, one shell");
    logout("A");
    sleep(7);
    ok(procs("aequalyn-watchdog", "A").length === 0, "the supervisor left with its session: " + procs("aequalyn-watchdog", "A"));
    ok(procs("import time", "A").length === 0, "and its shell too: " + procs("import time", "A"));
    ok(!fs.existsSync(path.join(tmp, "run/aequalyn-watchdog.stopped")), "not a deliberate stop: ensure may start one");

    // a shell left from an ended session is replaced, never adopted
    const stale = cp.spawn(tmp + "/bin/qs", ["-n", "-p", config], { env: envOf("B"), stdio: "ignore", detached: true });
    sleep(0.5);
    session("C");
    ok(run("C", "start").status === 0, "it starts in the new session");
    sleep(2);
    ok(procs("import time", "B").length === 0, "the old session's shell was stopped: " + procs("import time", "B"));
    ok(procs("import time", "C").length === 1, "this session has its own shell: " + procs("import time", "C"));

    // a shell of a session still running is adopted as before
    run("C", "stop");
    sleep(2);
    const kept = procs("import time", "C");
    ok(run("C", "start").status === 0 && kept.length === 1, "started again");
    sleep(2);
    ok(procs("import time", "C").join() === kept.join(), "the live session's shell was adopted: " + procs("import time", "C"));
    stale.unref();
} finally {
    for (const p of all()) if (p !== process.pid) try { process.kill(p, "SIGKILL"); } catch (e) {}
    sleep(0.3);
    fs.rmSync(tmp, { recursive: true, force: true });
}
console.log(`watchdog session: ${fails} failures`);
process.exit(fails ? 1 : 0);
