// node tests/watchdog-lock.test.js -- one supervisor at a time, however busy it is
const fs = require("fs"), os = require("os"), path = require("path"), cp = require("child_process");
const wd = path.join(__dirname, "../tools/watchdog/aequalyn-watchdog");
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "aqwd"));
let fails = 0;
const ok = (c, what) => { if (!c) { fails++; console.log("FAIL", what); } };
for (const d of ["bin", "run", "home/.config/quickshell"]) fs.mkdirSync(path.join(tmp, d), { recursive: true });
fs.writeFileSync(path.join(tmp, "home/.config/quickshell/shell.qml"), "");
// a shell that runs, and answers its heartbeat
fs.writeFileSync(path.join(tmp, "bin/qs"), '#!/bin/sh\n[ "$1" = ipc ] && { echo pong; exit 0; }\nexec sleep 120\n', { mode: 0o755 });
const env = { HOME: tmp + "/home", XDG_RUNTIME_DIR: tmp + "/run", PATH: tmp + "/bin:" + process.env.PATH, LANG: "C.UTF-8" };
const run = (...a) => cp.spawnSync("python3", [wd, ...a], { env, encoding: "utf8", timeout: 60000 });
// the supervisors of this test: their runtime folder is in their environment
const ours = () => fs.readdirSync("/proc").filter(p => /^\d+$/.test(p)).filter(p => {
    try {
        return fs.readFileSync(`/proc/${p}/cmdline`, "utf8").includes("aequalyn-watchdog")
            && fs.readFileSync(`/proc/${p}/environ`, "utf8").includes("XDG_RUNTIME_DIR=" + tmp);
    } catch (e) { return false; }
}).map(Number);
const all = () => fs.readdirSync("/proc").filter(p => /^\d+$/.test(p)).filter(p => {
    try { return fs.readFileSync(`/proc/${p}/environ`, "utf8").includes("XDG_RUNTIME_DIR=" + tmp); } catch (e) { return false; }
}).map(Number);
const sleep = s => cp.spawnSync("sleep", [String(s)]);
try {
    ok(run("start").status === 0, "it starts");
    ok(ours().length === 1, "one supervisor: " + ours());
    const first = ours()[0];
    process.kill(first, "SIGSTOP");                     // too busy to answer
    const r = run("start");
    ok(r.status === 0 && /already running/.test(r.stdout), "a busy one is not replaced: " + r.stdout + r.stderr);
    run("ensure");
    ok(ours().join() === String(first), "still the one: " + ours());
    process.kill(first, "SIGCONT");
    sleep(1);
    ok(run("status").status === 0, "it answers again");
    process.kill(first, "SIGKILL");                     // it really died
    sleep(0.5);
    ok(run("start").status === 0 && ours().length === 1 && ours()[0] !== first, "a dead one is replaced: " + ours());
    // stopped and started at once, as an update does
    run("stop");
    ok(run("start").status === 0, "started again right after a stop");
    sleep(1);
    ok(ours().length === 1 && run("status").status === 0, "one, and it answers: " + ours());
    run("stop");
    sleep(2);
    // several at once
    const many = [1, 2, 3, 4].map(() => cp.spawn("python3", [wd, "start"], { env, stdio: "ignore" }));
    sleep(6);
    ok(ours().filter(p => !many.some(m => m.pid === p)).length === 1, "four starts at once make one: " + ours());
} finally {
    for (const p of all()) if (p !== process.pid) try { process.kill(p, "SIGKILL"); } catch (e) {}
    sleep(0.3);
    fs.rmSync(tmp, { recursive: true, force: true });
}
console.log(`watchdog lock: ${fails} failures`);
process.exit(fails ? 1 : 0);
