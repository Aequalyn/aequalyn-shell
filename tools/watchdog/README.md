# The Aequalyn watchdog and plugin sandbox

QuickShell runs every plugin of the shell in one process, so one broken
plugin -- a segfault in a C++ path, an event loop that never comes back, a
growing leak -- can take the whole desktop down with it. QuickShell has no
sandbox of its own. This folder is the missing supervisor:

```
aequalyn-session-start ── aequalyn-watchdog (this repo's tool, in PATH)
                             ├── qs -p ~/.config/quickshell          the shell, supervised
                             ├── qs -p …/watchdog/hosts/<id>        sandboxed plugin #1
                             └── qs -p …/watchdog/hosts/<id>        sandboxed plugin #2
```

* The **shell** is supervised, not sandboxed: if it crashes, hangs or
  outgrows its RAM budget, the watchdog restarts it (it was ~600 MiB in
  normal use; the default ceiling is 900 MiB). It is never turned off --
  it is the desktop.
* Marked **plugins** run out of process, each as its own QuickShell
  instance through `tools/watchdog/host/shell.qml`. A plugin that fails
  loses only its own process. It is restarted with a growing delay, and
  if it keeps failing (3 times in 10 minutes by default) it is **turned
  off** -- removed from `enabledPlugins`, with a notification in the
  corner saying why -- instead of being restarted forever.
* **RAM is budgeted per process**, sampled from `/proc` (children
  included, so a plugin's `sh -c` helpers count against it). Three
  consecutive samples over budget, or one sample at twice the budget, is
  a breach: the process is stopped and the failure is recorded.
* **Hangs are detected** by heartbeat: the shell answers
  `qs ipc call watchdog ping`, each sandboxed plugin answers
  `qs ipc --pid <pid> call sandbox ping`. Two unanswered heartbeats
  (20 s apart, after a 20 s grace at start) and the process is restarted.

The in-shell side of all this is `plugins/watchdog/Watchdog.qml`
(instantiated by `shell.qml`), which also turns plugins on and off the
same way the Plugins page does, so the running state, the settings file
and the sandboxed processes always agree. `PluginManager.qml` skips
sandboxed plugins when loading in-process ones, and turns a plugin off
when it fails to even load.

## What runs in the sandbox

* Built-ins marked `sandbox: true` in `Plugins.js` -- currently
  `batteryGuard`, `breaks`, `diskWatch`, `nightLight`: background
  plugins with no windows of their own in the shell.
* Store (third-party) plugins whose manifest group is `"background"`
  (plugins with embedded UI -- group `"key"` or `"screen"` -- stay
  in-process, where the shell can embed their panels).
* Anything in `"forceSandbox"` in `~/.config/aequalyn/watchdog.json`,
  minus anything in `"noSandbox"` there (that list is pushed into the
  shell so its in-process loader picks those plugins back up).

A plugin is only supervised while it is enabled: `enabledPlugins` in
`~/.config/aequalyn/settings.json` is the single source of truth, and
the watchdog follows the file wherever it was changed (the Settings
page, its own CLI, or an automatic turn-off). Toggling a sandboxed
plugin in Settings → Plugins starts or stops its process within a
second, no restart needed.

Not everything *can* be sandboxed: a bar widget, a dock, an embedded
panel are child items of the shell's own windows, and each separate
QuickShell instance costs ~150 MiB RSS of its own (resident shared Qt
pages count per process), so sandboxing everything would spend far more
memory than it protects. The rule above is the balance: background
work and third-party code get a process each; the visual shell stays
whole.

## The CLI

```
aequalyn-watchdog start          # supervise the shell (idempotent; adopts a running shell)
aequalyn-watchdog status         # shell + sandboxed plugins: pid, RAM, failures, what is off
aequalyn-watchdog restart shell   # restart the shell in place (what aequalyn-shell-restart does)
aequalyn-watchdog restart <id>    # restart one sandboxed plugin
aequalyn-watchdog enable <id>     # turn a plugin on (through the shell, like the Settings page)
aequalyn-watchdog disable <id>   # turn one off, with a reason in the notification
aequalyn-watchdog sandboxed      # what would run out of process, and why
aequalyn-watchdog log [-n N]     # the supervisor's log
aequalyn-watchdog ensure         # start unless running or stopped by hand (the shell's keep-alive)
aequalyn-watchdog stop [--kill]  # stop supervising (processes keep running unless --kill)
aequalyn-watchdog test <id> leak|hang|crash   # restart a plugin in a failure-test mode
aequalyn-watchdog root-actions   # every root action every plugin declared (and its exact command)
aequalyn-watchdog exec-root <id> [--as <built-in>]   # a plugin's one door to root (see below)
aequalyn-watchdog decide <request> once|always|deny # the escalation window's answer (the window calls this)
```

The supervisor refuses to run as root, and everything under it -- the shell,
every plugin, every escalation -- is the user's session, by design.

`start` is what `aequalyn-session-start` runs at login, and what
`Watchdog.qml` spawns if it finds no supervisor. `stop` leaves everything
running and writes a marker (`$XDG_RUNTIME_DIR/aequalyn-watchdog.stopped`)
so the shell's keep-alive does not bring it straight back; `start` (or
`ensure`) clears the marker. The shell calls `ensure` every two minutes,
so a supervisor killed behind its back -- anything but a deliberate
`stop` -- is back within two minutes, adopting the running shell.
The next `start` also kills leftover sandbox instances (a previous
supervisor's hosts still hold their configs, and `qs -n` refuses a
duplicate) and starts them fresh.

The supervisor's own log is
`~/.local/state/aequalyn/watchdog/watchdog.log`, each process's output
is next to it in `logs/`, and the per-plugin host configs are generated
under `~/.local/state/aequalyn/watchdog/hosts/<id>/` (symlinks to the
real config folders, so `root:/` imports resolve as in the shell).

## Root: one gate, declared up front

Plugins are user code, and none of them may reach for root on their own.
The gate is the only door, and it has three locks on it, in this order:

1. **Declared.** A plugin that wants root says so in its manifest, before it
   is ever installed: `needsRoot` in `plugin.json` (a Store plugin) or a
   `needsRoot: [...]` on its line in `Plugins.js` (a built-in). Each action
   has an id, a label and a **fixed command** -- an argv pinned in the
   manifest, never something the plugin passes in at run time. The Store
   prints every declared action and its exact command while it checks the
   plugin; the Plugins page badges the card with `runs as root`.
2. **Pinned.** `aequalyn-watchdog exec-root <actionId>` connects to the
   supervisor's socket, and the kernel says who is on the other end
   (`SO_PEERCRED`): the caller is matched to the supervised unit its process
   chain really belongs to, so a plugin cannot ask as another one, and a
   process outside the supervised tree (a terminal, an orphan) is refused
   outright. A plugin unit may only ever ask for escalations: every other
   control command is refused when the caller belongs to one.
3. **Asked.** The supervisor calls the shell, which opens the escalation
   window (`plugins/watchdog/EscalationWindow.qml`): the plugin's name and
   version, the action, and the exact command about to run as root -- with
   the password field that feeds it. The password goes to
   `aequalyn-watchdog decide` on a pipe (never argv, never a log line), and
   from there over the uid-checked socket to the supervisor, which runs
   `sudo -S -- <the declared argv>` with the password on stdin. No answer in
   two minutes is a denial; "Always allow this" only remembers consent (the
   password is asked again, because sudo wants it); the run and its exit
   code are logged.

And under all of it, a tripwire: the supervisor walks every unit's process
tree on every RAM pass, and anything that looks like `sudo`, `pkexec`,
`su` or `doas` -- directly, in a shell script argument, behind `env` or
`timeout` -- is killed with its subtree, notified with the exact command
line, and counted as a failure like any other fault (three in ten minutes
turns the plugin off). The gate's own sudo is a child of the supervisor,
never of a unit, so it is never mistaken for a bypass. There are no
excused callers: the first-party flows (the browser colour policy, the
SDDM lock screen, the theme pack's install, the Store's Arch packages)
ride the same gate -- their actions are declared on their built-in's line
in `Plugins.js` (`settings`, `store`), their commands pinned to the
root-owned copies in `/usr/local/bin`, and their scripts stage what
varies (the colour, the theme name, the package ids) into
`~/.local/state/aequalyn/gate/`, where the root halves re-find it
through `SUDO_USER` and trust nothing beyond strict validation. Flows
that genuinely need a person at a keyboard (yay's build, snap's
confinement questions, the Aequalyn update itself) open a detached
terminal instead -- the user's own console, outside the supervised tree.

The boundary the gate keeps is between the desktop's code and the person:
everything the shell or a plugin starts is supervised -- unit trees are
walked, and the gate is the only door to root -- while everything a person
types into their own terminal is theirs. The tripwire never looks at
processes outside the supervised tree, exec-root refuses them outright
("a terminal already has sudo"), and the manual root paths stay manual
(`sudo aequalyn-sddm apply x` works; `gate-pkg` and friends answer "the
gate runs it, never a person"). A terminal the desktop opens for you to
read and type into is detached from the shell's tree on purpose: it is
your console from the first keystroke.

Honest limits, so nobody thinks this is more than it is: the tripwire is a
3-second sample over `/proc`, so a run that starts and exits between
samples is missed; a plugin can build its `sudo` call from concatenated
strings (the Store's static check over QML sources bans the words, but
cannot catch construction); and same-user code can in principle do
anything the user can. The gate is **consent made explicit and audited**,
not a hard wall -- a hard wall would need OS-level sandboxing
(bubblewrap/seccomp) around every plugin, which this watchdog
deliberately does not attempt. What it does guarantee: no plugin can run
so much as one root command without its command being written down in
its manifest for everyone to read, and a person pressing a button.

## Configuration

Everything has a working default; `~/.config/aequalyn/watchdog.json`
overrides any of it (create the file; it is read at `start`):

```json
{
  "shellRamMb": 900,
  "pluginRamMb": 256,
  "pluginRamMbById": { "weather": 512 },
  "heartbeatSeconds": 20,
  "heartbeatGraceSeconds": 20,
  "heartbeatTimeoutSeconds": 6,
  "ramCheckSeconds": 5,
  "ramBreachSamples": 3,
  "crashWindowMinutes": 10,
  "maxFailures": 3,
  "backoffMaxSeconds": 30,
  "forceSandbox": [],
  "noSandbox": [],
  "escalationTimeoutSeconds": 120,
  "escalationCommandTimeoutSeconds": 300
}
```

## What a sandboxed plugin can expect

Everything a background plugin needs keeps working out of process:

* `KitHost.notify()` goes through D-Bus (`notify-send`), so the shell's
  notification server still shows it.
* `KitStore` settings are files in `~/.local/state/aequalyn/<id>/` --
  shared with the main shell, written by either process.
* Its `IpcHandler` target is registered in its own instance and can be
  reached with `qs ipc --pid <pid> call <id> …` (the pid is in
  `aequalyn-watchdog status`). A bare `qs ipc call <id> …` reaches only
  the main shell, so key bindings that summon a *panel* belong to
  in-process plugins; that is why UI plugins are not sandboxed.
* The shared `theme` object is not available (there is no main shell in
  the process); background plugins do not draw, and each has its own
  fallback palette if it ever needs a colour.
* Each host registers with the desktop portals under its own app id
  (`org.aequalyn.sandbox.<id>`, via `QS_APP_ID`), not the shell's.

## Store plugins

A Store plugin is arbitrary code from a git repository, so the sandbox
rules matter most there:

* manifest `group: "background"` (the default) → sandboxed, its own
  process, full failure policy;
* manifest `group: "key"` or `"screen"` → in-process (its panels must be
  embeddable by the shell), covered by the load-error auto-off and the
  shell's own supervision;
* a manifest whose `id` is a built-in's (`Plugins.js`) is refused
  outright by `UserPlugins` *and* by the supervisor -- a Store plugin
  can never sit on `bar`, `docks`, or any other built-in id and shadow
  it;
* a broken manifest (unparseable JSON, invalid id, missing entry file)
  is skipped silently by the Store scan;
* the supervisor watches the Store directory itself, so a plugin
  installed or removed takes effect within a second even if no setting
  changed.

## Failure classes, and who catches what

| fault | where it can happen | what happens |
| --- | --- | --- |
| load error (broken QML) | anywhere | a ten-second grace first: an update swapping the config tree under the running shell fails loads only for a moment, and a load that comes good stops the clock. Still failing after it: the plugin is turned off, with a notification |
| crash (segfault, `kill -9`) | sandboxed | process dies, supervisor restarts it (2s→30s backoff), turns it off after 3 failures in 10 min |
| hang (event loop blocked) | sandboxed, or the whole shell | two unanswered heartbeats → the process is restarted |
| RAM runaway | sandboxed, or the whole shell | over budget 3 samples, or one sample at 2× budget → stopped, counts as a failure |
| runtime JS error (not a load error) | in-process | logged as a QML warning; the handler dies, the plugin is half-broken, nothing else is affected. The watchdog cannot see these -- they neither crash nor hang -- which is exactly why risky plugins belong in the sandbox, where their runtime errors usually progress to one of the caught classes |

Two reload facts worth knowing when testing plugins:

* QuickShell hot-reloads files that are **statically imported** into
  `shell.qml`, but not files loaded through `PluginManager`'s `Loader`
  (a plugin's own QML). Editing a plugin therefore does not reload it:
  touch a watched file (any shell-level QML) or run
  `aequalyn-shell-restart`.
* A settings file that becomes unreadable or unparseable is ignored by
  the supervisor until it is valid again: it keeps the last known
  enabled list instead of acting as if every plugin had been turned
  off. (The shell itself only reads the file at startup.)

## Testing the watchdog itself

Two ways to watch the protection work:

* **Watchdog self-test** (Settings → Plugins): a built-in plugin that stages
  the whole policy on itself when turned on -- crash, leak, crash, each step
  narrated in a notification, ending turned off by the watchdog. The demo
  runs only inside its sandbox: it refuses to do anything in-process, so it
  can never hurt the shell it is demonstrating the protection of.
* **Root gate self-test** (Settings → Plugins): the gate's own demo, a
  built-in whose one root action is pinned on its `Plugins.js` line. Turned
  on, it asks through the gate immediately -- the approval window names the
  plugin and the exact command, the password goes to sudo on a pipe, and a
  notification narrates the outcome: allowed and `/usr/bin/id -u` answers 0,
  denied (a click, Escape, or the two-minute timeout) and nothing ran.
  Both self-tests ask again at every enable, which for a demo is exactly
  the point -- but a planned restart (an update's restart-all) starts them
  quietly (AEQUALYN_PLUGIN_PLANNED), so an update never interrupts you.
* `aequalyn-watchdog test <id> <mode>` restarts any sandboxed plugin with a
  built-in fault, so single policies can be watched from `status`:

| mode | fault | exercised path |
| --- | --- | --- |
| `leak` | ~100 MiB/s of live JS | RAM budget: breach, stop, failure, restart |
| `hang` | event loop blocked forever | heartbeat: two misses, stop, failure |
| `crash` | `kill -9` on itself | crash: backoff restarts, then turn-off |
| `esc` | `sudo` straight from the process, no gate | tripwire: subtree killed, notification with the command, failure; three turn the plugin off |

A `restart` (by hand) clears the failure window and the test mode.
All three modes have been run for real against live sandboxed plugins,
as has the load-error path (a plugin with a syntax error is turned off
by the shell after a ten-second grace, in-process or Store), the Store
path (a background manifest runs sandboxed, a key manifest stays
in-process, ids that collide with built-ins are refused), supervisor
restarts and `kill -9` (the shell adopts back, hosts are cleaned and
respawned), concurrent CLI calls, and a corrupted settings file
(last-known state is kept).

## Notes and limits

* The supervisor is the process that restarts the shell; if *it* is
  killed nothing watches the desktop until it is started again (the
  shell itself spawns `aequalyn-watchdog start` on every load, and
  login runs it through `aequalyn-session-start`).
* In-process plugins are covered by the shell's own budget and
  heartbeat, and a plugin that fails to *load* is turned off by
  `PluginManager` with a notification -- but a crash *inside* an
  in-process plugin still takes the shell down; that is inherent to
  being in one process and is exactly why the risky ones are marked
  `sandbox: true`.
* A sandboxed plugin with `settings: true` shows its toggle in the
  Plugins page, but its detailed settings rows (which read the running
  plugin through `KitHost`) only appear while it runs in-process;
  sandboxed, its file-based settings are still there and unchanged.
