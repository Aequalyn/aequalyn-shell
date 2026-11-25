// node tests/watchdog-gate.test.js -- a root request reaches the person and gets its answer,
// whatever the shell and the supervisor are doing meanwhile (a login, a restart, a busy loop)
const fs = require("fs"), os = require("os"), path = require("path"), cp = require("child_process");
const wd = path.join(__dirname, "../tools/watchdog/aequalyn-watchdog");
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "aqgate"));
let fails = 0, n = 0;
const ok = (c, what) => { n++; if (!c) { fails++; console.log("FAIL", what); } };
const P = p => path.join(tmp, p);
for (const d of ["bin", "run", "home/.config/quickshell", "home/.config/aequalyn", "cmd"]) fs.mkdirSync(P(d), { recursive: true });
fs.writeFileSync(P("home/.config/quickshell/shell.qml"), "");
fs.writeFileSync(P("home/.config/aequalyn/watchdog.json"), JSON.stringify({ escalationTimeoutSeconds: 12, escalationCommandTimeoutSeconds: 3 }));
// what the desktop declares: an ordinary action, a slow one, and one a person starts and stays in
const act = (id, extra) => Object.assign({ id, label: id, about: "", command: [P("bin/root-" + id)] }, extra);
fs.writeFileSync(P("home/.config/quickshell/Plugins.js"), `var list = [ { id: "settings", label: "S", needsRoot: ${JSON.stringify([
    act("colour"), act("slow"), act("wizard", { interactive: true })])} } ];`);
for (const [id, body] of [["colour", ""], ["slow", "sleep 30"], ["wizard", "sleep 6"]])
    fs.writeFileSync(P("bin/root-" + id), `#!/bin/sh\necho start >> ${P("ran-" + id)}\n${body}\necho end >> ${P("ran-" + id)}\n`, { mode: 0o755 });
// sudo: the password "live", on stdin
fs.writeFileSync(P("bin/sudo"), '#!/bin/sh\nread pw\n[ "$pw" = live ] || { sleep 1; echo "Sorry, try again." >&2; exit 1; }\nwhile [ "$1" != "--" ]; do shift; done; shift\nexec "$@"\n', { mode: 0o755 });
// the shell: answers once it is up, shows what it is asked, runs what the test tells it to
// (as its own child), and takes its processes with it when it goes
fs.writeFileSync(P("bin/qs"), `#!/usr/bin/env python3
import json, os, signal, subprocess, sys, time
T = ${JSON.stringify(tmp)}
def ready():
    try: pid = int(open(T + "/ready").read()); os.kill(pid, 0); return pid
    except Exception: return 0
if sys.argv[1] == "ipc":
    if not ready(): sys.exit(1)
    fn, args = sys.argv[4], sys.argv[5:]
    if fn == "escalationRequest":
        d = json.loads(args[0]); d["shell"] = ready()
        open(T + "/asked", "a").write(json.dumps(d) + "\\n")
    if fn == "escalationGone": open(T + "/gone", "a").write(args[0] + "\\n")
    print("{}" if fn == "health" else "ok"); sys.exit(0)
kids = []
def bye(*_):
    try: os.unlink(T + "/ready")
    except OSError: pass
    for k in kids:
        try: k.kill()
        except OSError: pass
    os._exit(0)
signal.signal(signal.SIGTERM, bye)
time.sleep(float(open(T + "/delay").read() or 0) if os.path.exists(T + "/delay") else 0)
open(T + "/ready", "w").write(str(os.getpid()))
while True:
    for f in sorted(os.listdir(T + "/cmd")):
        if not f.endswith(".sh"): continue
        c = open(T + "/cmd/" + f).read(); os.unlink(T + "/cmd/" + f)
        kids.append(subprocess.Popen(["sh", "-c", c], stdin=subprocess.DEVNULL))
    for k in kids: k.poll()
    time.sleep(0.1)
`, { mode: 0o755 });
fs.symlinkSync(wd, P("bin/aequalyn-watchdog"));
for (const t of ["notify-send"]) fs.writeFileSync(P("bin/" + t), "#!/bin/sh\n", { mode: 0o755 });
const env = { HOME: P("home"), XDG_RUNTIME_DIR: P("run"), PATH: P("bin") + ":" + process.env.PATH, LANG: "C.UTF-8" };
const run = (...a) => cp.spawnSync("python3", [wd, ...a], { env, encoding: "utf8", timeout: 60000 });
const sleep = s => cp.spawnSync("sleep", [String(s)]);
const until = (f, s) => { const end = Date.now() + s * 1000; for (;;) { const v = f(); if (v) return v; if (Date.now() > end) return null; sleep(0.1); } };
const read = p => { try { return fs.readFileSync(P(p), "utf8"); } catch (e) { return ""; } };
const asked = () => read("asked").trim().split("\n").filter(Boolean).map(JSON.parse);
const gone = () => read("gone").trim().split("\n").filter(Boolean);
let seq = 0;
const inShell = c => { const f = P("cmd/" + String(seq++).padStart(4, "0")); fs.writeFileSync(f, c); fs.renameSync(f, f + ".sh"); };
// ask from the shell (detached: as the control center does, it outlives a restart)
const ask = (action, tag, how) => inShell(`${how === undefined ? "setsid -w " : how}aequalyn-watchdog exec-root --as settings ${action} > ${P("out-" + tag)} 2>&1; echo "rc $?" >> ${P("out-" + tag)}`);
const answered = (tag, s) => until(() => /rc \d+/.test(read("out-" + tag)) && read("out-" + tag), s);
const decide = (id, what, pw) => inShell(`printf '%s\\n' '${pw || ""}' | aequalyn-watchdog decide ${id} ${what}`);
const window = (action, after, s) => until(() => asked().slice(after).find(r => r.action === action), s);
const all = () => fs.readdirSync("/proc").filter(p => /^\d+$/.test(p)).filter(p => {
    try { return fs.readFileSync(`/proc/${p}/environ`, "utf8").includes("XDG_RUNTIME_DIR=" + tmp); } catch (e) { return false; }
}).map(Number);
const supervisor = () => Number(read("run/aequalyn-watchdog.pid"));
try {
    ok(run("start").status === 0, "the supervisor starts");
    until(() => read("ready"), 5);

    // ---- the plain way
    ask("colour", "a"); let w = window("colour", 0, 8);
    ok(w, "a request opens its window");
    if (w) decide(w.requestId, "once", "live");
    ok(/rc 0/.test(answered("a", 8) || ""), "allowed: it runs " + read("out-a"));
    ok(/end/.test(read("ran-colour")), "as root");
    ask("colour", "b"); w = window("colour", 1, 8); if (w) decide(w.requestId, "once", "wrong");
    ok(/rc 1\b/.test(answered("b", 10) || ""), "a wrong password is a failure " + read("out-b"));
    ask("colour", "c"); w = window("colour", 2, 8); if (w) decide(w.requestId, "deny");
    ok(/denied by the user/.test(answered("c", 8) || ""), "denied is denied");

    // ---- the live ISO's login: a request nobody asked for is open, the shell restarts, and
    // then the person clicks Install
    let at = asked().length;
    ask("colour", "d"); ok(window("colour", at, 8), "the login's own request is open");
    run("restart", "shell"); until(() => read("ready"), 8);
    at = asked().length;
    ask("wizard", "e"); w = window("wizard", 0, 10);
    ok(w, "the wizard's window opens right after the restart " + read("out-e"));
    ok(until(() => { const s = new Set(asked().map(r => r.shell)); return s.size > 1 && asked().some(r => r.action === "colour" && r.shell === Number(read("ready"))); }, 8),
       "and the open request is asked again in the new shell");
    ok(w && w.interactive === true, "the window knows a person is waiting for it");
    if (w) decide(w.requestId, "once", "live");
    ok(/rc 0/.test(answered("e", 12) || "") && !/end/.test(read("ran-wizard")), "it answers once the wizard is running " + read("out-e"));
    w = asked().filter(r => r.action === "colour").pop(); decide(w.requestId, "once", "live");
    // (the process that started it went with the old shell; the request did not)
    ok(until(() => /"ok": true/.test(read("out-d")), 8), "the first request gets its answer too " + read("out-d"));
    ok(until(() => /end/.test(read("ran-wizard")), 12), "the wizard is not cut off by the time limit (3 s)");

    // ---- an ordinary command is
    at = asked().length; ask("slow", "f"); w = window("slow", at, 8); if (w) decide(w.requestId, "once", "live");
    ok(/rc 124/.test(answered("f", 15) || ""), "an ordinary one is stopped at the time limit " + read("out-f"));

    // ---- clicked while the shell is on its way back
    fs.writeFileSync(P("delay"), "4");
    at = asked().length; ask("wizard", "g"); sleep(1); process.kill(Number(read("ready")), "SIGKILL"); fs.rmSync(P("ready"), { force: true });
    w = until(() => asked().slice(at).filter(r => r.action === "wizard").find(r => r.shell === Number(read("ready"))), 25);
    ok(w, "a shell that comes back is asked " + read("out-g"));
    if (w) decide(w.requestId, "once", "live");
    ok(/rc 0/.test(answered("g", 15) || ""), "and its answer counts " + read("out-g"));
    fs.rmSync(P("delay"));
    until(() => (read("ran-wizard").match(/end/g) || []).length === 2, 12);

    // ---- a supervisor that is busy
    at = asked().length; process.kill(supervisor(), "SIGSTOP"); ask("colour", "h"); sleep(5); process.kill(supervisor(), "SIGCONT");
    w = window("colour", at, 10); ok(w, "a busy supervisor is waited for " + read("out-h"));
    if (w) decide(w.requestId, "once", "live");
    ok(/rc 0/.test(answered("h", 10) || ""), "and answers " + read("out-h"));

    // ---- the same thing twice, and a request whose asker is gone
    at = asked().length; ask("colour", "i"); w = window("colour", at, 8); ask("colour", "j");
    ok(/already waiting/.test(answered("j", 8) || ""), "the same request twice is one " + read("out-j"));
    decide(w.requestId, "deny"); answered("i", 8);
    at = asked().length; ask("colour", "k", "exec "); w = window("colour", at, 8);
    cp.spawnSync("pkill", ["-KILL", "-f", `${tmp}/bin/aequalyn-watchdog exec-root`]);
    ok(w && until(() => gone().includes(w.requestId), 8), "a request whose asker is gone is taken back");
    at = asked().length; ask("colour", "l"); w = window("colour", at, 8); ok(w, "and another can be made at once " + read("out-l"));
    ok(/no answer in time/.test(answered("l", 18) || "") && gone().includes(w ? w.requestId : "?"), "no answer is a denial, and its window goes");

    // ---- still no door for anyone else
    ok(/not a supervised process/.test(run("exec-root", "--as", "settings", "colour").stdout), "a terminal is refused");
    at = asked().length; ask("colour", "m"); w = window("colour", at, 8);
    ok(run("decide", w ? w.requestId : "x", "once").status !== 0, "a stranger cannot answer");
    ok(!/start\n.*start\n.*start\n.*start\n.*start/s.test(read("ran-colour")), "nothing ran without an answer");
    if (w) decide(w.requestId, "deny");
} finally {
    for (const p of all()) if (p !== process.pid) try { process.kill(p, "SIGKILL"); } catch (e) {}
    sleep(0.3);
    if (process.env.KEEP) { console.log(tmp); console.log(read("home/.local/state/aequalyn/watchdog/watchdog.log").split("\n").slice(-60).join("\n")); }
    else fs.rmSync(tmp, { recursive: true, force: true });
}
console.log(`watchdog gate: ${n} checks, ${fails} failures`);
process.exit(fails ? 1 : 0);
