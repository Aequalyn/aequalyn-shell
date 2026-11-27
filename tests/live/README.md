# Live desktop test harness

Python harness for a running Aequalyn shell. It checks what the compositor and
the shell are actually doing, rather than reading source files.

```sh
python3 tests/live/shell_test.py
python3 tests/live/shell_test.py --keybinds-only --no-smoke
python3 tests/live/shell_test.py --plugins-only --only calculator,emoji
```

From the repository root. There is no install step; it uses your session's
`qs`, `hyprctl`, `grim`, `node`, `notify-send`, `wpctl` and Python 3. It writes
to `~/Videos/Aequalyn-test-<timestamp>/` unless `--out DIR` is given.

## Files

| File | Role |
| --- | --- |
| `shell_test.py` | Orchestrates the phases, guarantees screenshots, restores watchdog state, writes the combined report. |
| `keybind_test.py` | Read-only keybind checker: reads `hyprctl binds -j`, resolves each bind's real effect and compares it with the expected manifest. |
| `plugin_walkthrough.py` | Opens each registered plugin, screenshots it open and closed, closes it, restores its original enabled state. |
| `jsload.js` | Loads QML JS libraries in Node so plugin metadata can be read without a Qt build. |

`keybind_test.py` and `plugin_walkthrough.py` also run standalone; the
orchestrator is the usual entry point.

## Phases

1. **Keybinds** — every registered bind is matched to an expected command or
   dispatcher, checked for duplicates/unexpected entries and flag mistakes, and
   smoke-checked for executable/IPC targets (`--no-smoke` skips that part).
   Nothing is launched and no key is pressed.
2. **Plugins** — each plugin in the live registry is temporarily enabled if
   needed, opened, screenshotted, closed, screenshotted again, and returned to
   its original enabled state. Plugins with no standalone UI are captured via
   their Settings card. Anything without a screenshot is retried once, then a
   plain snapshot is taken as evidence.
3. **Watchdog restore** — see below.

## Options

```
--out DIR                 output directory
--keybinds-only           only the keybind phase
--plugins-only            only the plugin phase
--only IDS                comma-separated plugin ids (plugin phase)
--wait SECONDS            pause after each plugin phase (default 1.5)
--no-smoke                skip executable / IPC target existence checks
--record                  also record the plugin phase (aequalyn-record)
--dangerous               include the disruptive watchdog/root self-tests
--script-monitor NAME     monitor for this terminal
--plugin-monitor NAME     monitor where plugin UIs should appear
```

Environment overrides for non-standard installs:

```
AEQUALYN_SHELL_DIR        config dir holding Plugins.js / PluginInfo.js
                          (default: ~/.config/quickshell)
AEQUALYN_TEST_DIR         dir holding jsload.js (default: this directory)
```

Monitor names are detected at runtime; pass the options only when you want to
force a specific layout.

## Watchdog accounting

Some tests restart the shell or stress a plugin. The watchdog supervises
sandboxed plugins in separate processes and disables one that hits its crash
limit, which would otherwise leave the desktop missing that plugin after a test
run.

The harness snapshots:

- the supervisor's "turned off by the watchdog" list (`aequalyn-watchdog status`);
- the enabled plugin list in `~/.config/aequalyn/settings.json`.

At the end (also when a phase aborts), anything disabled during the run is
re-enabled with `aequalyn-watchdog enable <id>` and checked until it is up. If a
plugin cannot be restored, the run fails. `watchdog.json` records the before and
after state, what was killed, what was re-enabled, and anything still off.

## Output and interpretation

```
keybinds.json             keybind results, machine readable
keybinds.txt              keybind results, one line per bind
plugins/NN-<id>-open.png  plugin rendered, open
plugins/NN-<id>-closed.png plugin after closing
plugins/results.json      per-plugin log (status, notes, screenshots)
plugins/results.md        per-plugin table
watchdog.json             killed plugins and restoration result
results.json              combined machine-readable verdict
results.md                combined human-readable report
```

- **Keybind row**: `PASS` = live bind matches the manifest, `FAIL` = wrong or
  duplicate command, `SKIP` = optional plugin behind the bind is off. A FAIL is
  a finding about the current keybind configuration.
- **Plugin row**: `PASS` = opened and screenshotted, `FAIL`/`ERROR` = the plugin
  could not be opened or produced no usable screenshot, `SKIP` = deliberately
  not opened (disruptive self-test, or no scenario defined for a newly added
  plugin). `screenshot_source: plugin` means the shot shows the plugin;
  `snapshot` is a fallback of the current screen.
- **Watchdog**: `ok: true` means nothing was killed during the run, or every
  killed plugin came back. Check `killed_during_test` to see which ones;
  `failed_to_reenable` and `still_off` should be empty.
- **Exit status**: `0` = all enabled checks passed and watchdog state restored,
  `1` = at least one finding or an unrecoverable plugin, `2` = the harness could
  not start (missing Hyprland/shell, test module failed to load).

All reports are kept per run, so two runs can be compared after a config change.
Findings describe the desktop that was tested; they are not automatically bugs
in the shell.
