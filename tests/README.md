# Tests

This directory holds two kinds of checks:

1. **Fast source/unit tests** (Node, no desktop session needed) — see [Unit tests](#unit-tests).
2. **A live-session harness** (Python, needs Hyprland + the running shell) — see [Live-session harness](#live-session-harness).

Nothing here needs a particular machine, username, monitor name or install path.
Home/config locations come from `HOME`, `XDG_CONFIG_HOME` and `XDG_STATE_HOME`.

## Unit tests

Run everything from the repository root:

```sh
for t in tests/*.test.js; do node "$t"; done
```

Each file prints either `… N checks passed` / `… N ok` or `FAIL <what>` lines and
exits non-zero when a check fails. Most are source assertions: they read QML/JS
and look for the wiring that makes a feature work. They do **not** need a
running shell (the watchdog tests create their own temporary sandbox).

| File | What it checks | A failure means |
| --- | --- | --- |
| `control-center-style.test.js` | Clipboard page uses Control Center's own tabs, search, plugin rows and actions. | The page regressed to a pasted-in plugin panel. |
| `follow.test.js` | Things that follow the bar or a dock inherit their look consistently (ends, surfaces, lines, ornaments, colours). | A look/theme binding or style card is missing. |
| `install-lists.test.js` | Install chooser is two live lists (groups / choices) with Super+I and Super+R. | The chooser lost its grouping, refresh or key handling. |
| `install-options.test.js` | Catalogue entries are complete, unique, plain package names, with no brand wording leaking into the UI. | Bad catalogue data or source-branded text. |
| `keybinds.test.js` | The shipped key catalogue stays in sync with the generated keybinds, including reserved names and the web/clipboard keys. | A key was documented but not bound, or a reserved key was reused. |
| `lock_styles.test.js` | Lock plugin style/settings wiring. | A lock style or its settings binding broke. |
| `looks.test.js` | Every look, dock look and ensemble is valid and survives cleaning; layouts do not overlap; bar defaults are intact. | A look definition or the style cleaner is wrong. |
| `nav-arrows.test.js` | Left/Right move between Control Center's rail and list (and in Store); Up/Down move inside the chosen list. | Navigation keys were rebound or lost. |
| `notification-history.test.js` | Notification log model (snapshot, JSON round-trip, delete, search, DND marker), archive-before-suppress, history panel, grouped views, row Copy/Delete, Clear all, shortcut and palette entry. | A missed notification might not be recoverable, or its UI wiring is gone. |
| `plugin-manager-swap.test.js` | PluginManager watches the config-swap marker, treats swap failures as transient and schedules a retry. | A config update could leave plugins unloaded. |
| `sandbox-settings.test.js` | Settings of sandboxed plugins reach their store over the sandbox host's IPC bridge (night light, battery guard, breaks, disk watch). | Those plugin settings become silent no-ops again. |
| `store-install.test.js` | Store's Apps list uses the install chooser's categories without embedding its pages. | Store/install chooser wiring drifted. |
| `watchdog-gate.test.js` | A root request reaches the approval window and its answer, including during login, shell restart or a busy loop. | Privileged actions could hang or bypass consent. |
| `watchdog-lock.test.js` | Only one supervisor at a time, even under contention. | Two supervisors could fight over the shell. |
| `watchdog-session.test.js` | The supervisor never outlives its Hyprland session. | Stale supervisors would linger after logout. |
| `wifi-details.test.js` | Clicking a Wi-Fi row opens its details: credentials, saved-password reveal through the root gate, Forget, and the two fast.com gauges. | Network detail actions are no-ops. |
| `wifi-restricted.test.js` | Captive-portal detection/hand-off, enterprise (eduroam) joining, and the libnm helper that never puts a password in argv. | Restricted networks cannot be joined safely. |

Two extra static checks are worth running after editing QML or generated data:

```sh
python3 tools/cc-index.py --check   # Settings search index is up to date
timeout 8 quickshell -p ./shell.qml # config loads without QML type/binding errors
```

## Live-session harness

`tests/live/` contains a Python harness that checks the **running** desktop:
keybinds, every plugin (opened, screenshotted, closed, original state restored),
and watchdog cleanup.

```sh
python3 tests/live/shell_test.py
python3 tests/live/shell_test.py --keybinds-only --no-smoke
python3 tests/live/shell_test.py --plugins-only --only calculator,emoji
```

It needs a running Hyprland session with the Aequalyn shell, `qs`, `hyprctl`,
`grim`, `node` and Python 3. All dependencies are external tools; nothing is
installed by the harness. Output defaults to `~/Videos/Aequalyn-test-<timestamp>/`
(override with `--out DIR`).

The harness reads live plugin metadata from `~/.config/quickshell` by default.
Override it if the session uses another config dir:

```sh
AEQUALYN_SHELL_DIR=/path/to/quickshell/config python3 tests/live/shell_test.py
```

Use `--script-monitor NAME` and `--plugin-monitor NAME` if the terminal and the
plugin UIs should live on specific monitors; otherwise monitors are detected at
runtime. See [tests/live/README.md](live/README.md) for the full guide.

**Watchdog accounting.** The harness snapshots the supervisor's disabled list
and Settings' enabled plugin list before the run. Anything the watchdog kills
*during* the run (for example a host that got SIGTERM during a restart and hit
its crash limit) is reported and re-enabled with `aequalyn-watchdog enable <id>`
at the end — including when a phase aborts. A failure to restore is a failed run.

## Interpreting a run

- `keybinds.json` / `keybinds.txt`: one row per live bind with PASS / FAIL / SKIP.
  A FAIL is a finding about your keybinds (wrong command, duplicate, unexpected
  bind); SKIP means the optional plugin behind it is off.
- `plugins/results.json` / `results.md`: per-plugin status, notes and screenshot
  paths. `screenshot_source` says whether a shot shows the plugin (`plugin`) or
  is only a fallback snapshot (`snapshot`).
- `watchdog.json`: `killed_during_test`, `reenabled`, `failed_to_reenable`,
  `still_off`. `ok: true` means nothing was killed or everything killed came
  back up.
- `results.json` / `results.md`: combined verdict. Overall exit status is
  `0` = all enabled checks passed and the watchdog state was restored,
  `1` = at least one finding, `2` = the harness itself could not run.

Findings are facts about the desktop under test, not necessarily bugs in the
shell. Fix the config or the feature, then rerun; reports are written per run so
they can be compared.
