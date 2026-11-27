#!/usr/bin/env python3
"""
Aequalyn plugin walkthrough, interactive or non-interactive.

For every registered Aequalyn plugin this script:

1. temporarily enables the plugin if it is currently off;
2. calls an IPC action that makes the plugin (or its settings card) render;
3. pauses (or waits a fixed time in --auto mode) so the result can be checked;
4. calls the matching close action;
5. pauses/waits again to confirm that it closed;
6. restores the plugin to its original enabled state.

In --auto mode the terminal running this script is moved to the external
monitor, the internal monitor is focused for each plugin, and screenshots plus
a recording are saved automatically. This lets the walkthrough run unattended
while the plugin UI appears on the laptop screen and the script log stays on
the external screen.

Usage:
    tests/live/plugin_walkthrough.py
    tests/live/plugin_walkthrough.py --auto
    tests/live/plugin_walkthrough.py --auto --wait 2
    tests/live/plugin_walkthrough.py --no-record
    tests/live/plugin_walkthrough.py --only calculator,emoji
    tests/live/plugin_walkthrough.py --dry-run
    tests/live/plugin_walkthrough.py --dangerous
    tests/live/plugin_walkthrough.py --real-lock

During an interactive check:
    Enter   it opened / rendered / closed correctly
    s       save a screenshot and stay on this prompt
    r       retry (close and open again, or reopen after the close check)
    e       send Escape (handy for panels with no explicit close call)
    n       mark this check as failed and continue
    k       skip this plugin
    q       quit and restore everything
    ?       show this help again
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any

HOME = Path.home()
SHELL_DIR = Path(os.environ.get("AEQUALYN_SHELL_DIR", str(HOME / ".config" / "quickshell")))
TEST_DIR = Path(os.environ.get("AEQUALYN_TEST_DIR", str(Path(__file__).resolve().parent)))
VIDEOS = HOME / "Videos"
RUNTIME = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp"))
REC_STATE = RUNTIME / "aequalyn-record"

VOLUME_SINK = "@DEFAULT_AUDIO_SINK@"


class QuitWalkthrough(Exception):
    pass


@dataclass
class Scenario:
    open: list[str]
    close: list[str]
    note: str = ""
    dangerous: bool = False
    requires_interaction: bool = False


# Each plugin gets a visible action. Where a plugin has no "open" IPC call, its
# control-center card is used (`aequalyn pluginPage <id>`), which still proves
# that the plugin is registered and its settings render.
SCENARIOS: dict[str, Scenario] = {
    "bar": Scenario(
        ["qs ipc call bar quick"], ["qs ipc call bar quick"],
        "Opens the bar's quick panel; check the top strip and the panel.",
    ),
    "appLauncher": Scenario(
        ["qs ipc call launcher toggle"], ["qs ipc call launcher toggle"],
        "App launcher search panel.",
    ),
    "defaultApps": Scenario(
        ["qs ipc call defaults open"], ["qs ipc call defaults close"],
        "Default applications picker.",
    ),
    "programsMenu": Scenario(
        ["qs ipc call programs toggle"], ["qs ipc call programs toggle"],
        "Programs menu.",
    ),
    "installMenu": Scenario(
        ["qs ipc call installMenu open"], ["qs ipc call installMenu close"],
        "Install chooser.",
    ),
    "notifications": Scenario(
        ['notify-send -a "Aequalyn plugin check" "Plugin rendering check" '
         '"This popup should appear in the corner."'],
        ["qs ipc call notifications dismiss_all"],
        "Sends a test notification, then dismisses it.",
    ),
    "atelier": Scenario(
        ["qs ipc call atelier open themes"], ["qs ipc call atelier close"],
        "Theme picker.",
    ),
    "osd": Scenario(
        ["@volume-bump"], ["@volume-restore"],
        "Changes the default sink volume slightly so the OSD appears, then restores it.",
    ),
    "snap": Scenario(
        ["qs ipc call snap show"], ["qs ipc call snap hide"],
        "Snap-layout overlay.",
    ),
    "monitorManager": Scenario(
        ["qs ipc call monitors toggle"], ["qs ipc call monitors toggle"],
        "Monitor arrangement panel.",
    ),
    "idleInhibitor": Scenario(
        ["qs ipc call aequalyn pluginPage idleInhibitor"],
        ["qs ipc call aequalyn closeSettings"],
        "Idle inhibitor has no window; its settings card is shown.",
    ),
    "clipscape": Scenario(
        ["qs ipc call clipscape picker"], ["@escape"],
        "Clipboard history picker; press Escape to close if synthesis fails.",
    ),
    "showcase": Scenario(
        ["qs ipc call showcase show"], ["qs ipc call showcase hide"],
        "Desktop widgets behind the windows.",
    ),
    "powerMenu": Scenario(
        ["qs ipc call power open"], ["qs ipc call power close"],
        "Power menu (do not choose an action).",
    ),
    "docks": Scenario(
        ["qs ipc call dock show"], ["qs ipc call dock hide"],
        "Docks at the screen edges.",
    ),
    "plume": Scenario(
        ["qs ipc call plume settings"], ["qs ipc call aequalyn closeSettings"],
        "Cursor and pointer-effects settings.",
    ),
    "altscape": Scenario(
        ["qs ipc call altscape open"], ["@escape"],
        "Window switcher; press Escape to close if synthesis fails.",
    ),
    "media": Scenario(
        ["qs ipc call aequalyn pluginPage media"],
        ["qs ipc call aequalyn closeSettings"],
        "Media widget is on the bar; its settings card is shown here.",
    ),
    "fm": Scenario(
        [f"qs ipc call aequalyn-fm open {HOME}"],
        ["qs ipc call aequalyn-fm closeAll"],
        "Aequalyn FM window.",
    ),
    "keybinds": Scenario(
        ["qs ipc call aequalyn pluginPage keybinds"],
        ["qs ipc call aequalyn closeSettings"],
        "Keyboard shortcut editor.",
    ),
    "calculator": Scenario(
        ["qs ipc call calculator toggle"], ["qs ipc call calculator toggle"],
        "Calculator panel; type a sum if you like.",
    ),
    "colorPicker": Scenario(
        ["qs ipc call colorPicker pick"], ["@escape"],
        "Click a pixel to copy its colour, or press Escape to cancel.",
    ),
    "emoji": Scenario(
        ["qs ipc call emoji toggle"], ["qs ipc call emoji toggle"],
        "Emoji picker.",
    ),
    "notes": Scenario(
        ["qs ipc call notes toggle"], ["qs ipc call notes toggle"],
        "Quick notes page.",
    ),
    "keyHints": Scenario(
        ["qs ipc call keyHints toggle"], ["qs ipc call keyHints toggle"],
        "Searchable keybinding list.",
    ),
    "manual": Scenario(
        ["qs ipc call manual open keybindings"], ["@escape"],
        "Manual, opened on the keybindings section.",
    ),
    "fonts": Scenario(
        ["qs ipc call fonts open ui"], ["@escape"],
        "UI font picker.",
    ),
    "quickLooks": Scenario(
        ["qs ipc call quickLooks all"], ["qs ipc call quickLooks close"],
        "Quick-look panel for a whole look.",
    ),
    "palette": Scenario(
        ["qs ipc call palette toggle"], ["qs ipc call palette toggle"],
        "Command palette.",
    ),
    "sysmon": Scenario(
        ["qs ipc call sysmon toggle"], ["qs ipc call sysmon toggle"],
        "System monitor.",
    ),
    "screenText": Scenario(
        ["qs ipc call screenText capture"], ["@escape"],
        "Drag a box around some text; press Escape to cancel.",
    ),
    "timer": Scenario(
        ["qs ipc call timer toggle"], ["qs ipc call timer toggle"],
        "Timer panel.",
    ),
    "focus": Scenario(
        ["qs ipc call focus toggle"], ["qs ipc call focus toggle"],
        "Focus timer panel.",
    ),
    "weather": Scenario(
        ["qs ipc call aequalyn pluginPage weather"],
        ["qs ipc call aequalyn closeSettings"],
        "Weather has no window; its settings card is shown.",
    ),
    "netSpeed": Scenario(
        ["qs ipc call aequalyn pluginPage netSpeed"],
        ["qs ipc call aequalyn closeSettings"],
        "Network speed has no window; its settings card is shown.",
    ),
    "nightLight": Scenario(
        ["qs ipc call aequalyn pluginPage nightLight"],
        ["qs ipc call aequalyn closeSettings"],
        "Night light has no window; its settings card is shown.",
    ),
    "batteryGuard": Scenario(
        ["qs ipc call aequalyn pluginPage batteryGuard"],
        ["qs ipc call aequalyn closeSettings"],
        "Battery guard has no window; its settings card is shown.",
    ),
    "breaks": Scenario(
        ["qs ipc call aequalyn pluginPage breaks"],
        ["qs ipc call aequalyn closeSettings"],
        "Break reminder has no window; its settings card is shown.",
    ),
    "diskWatch": Scenario(
        ["qs ipc call aequalyn pluginPage diskWatch"],
        ["qs ipc call aequalyn closeSettings"],
        "Disk watch has no window; its settings card is shown.",
    ),
    "watchdogTest": Scenario(
        [], [],
        "Sandbox self-test: enabling it deliberately crashes three times.",
        dangerous=True,
    ),
    "rootTest": Scenario(
        [], [],
        "Root-gate self-test: enabling it opens the sudo approval window.",
        dangerous=True,
    ),
    "lock": Scenario(
        ["qs ipc call quickLooks lock"], ["qs ipc call quickLooks close"],
        "Safe preview of lock-screen designs. Use --real-lock for the real session lock.",
    ),
    "store": Scenario(
        ["qs ipc call store open"], ["qs ipc call store close"],
        "Plugin/theme store.",
    ),
    "settings": Scenario(
        ["qs ipc call aequalyn settings"],
        ["qs ipc call aequalyn closeSettings"],
        "Control center.",
    ),
}

LOCK_REAL = Scenario(
    ["qs ipc call lock lock"], [],
    "The real session lock. Unlock manually before confirming that it closed.",
    dangerous=True,
    requires_interaction=True,
)

HELP = "Enter=ok  s=screenshot  r=retry  e=Escape  n=fail  k=skip  q=quit  ?=help"


# --------------------------------------------------------------------------- #
# process helpers                                                              #
# --------------------------------------------------------------------------- #

def sh(args: list[Any], timeout: int = 15) -> tuple[int, str, str]:
    try:
        p = subprocess.run([str(a) for a in args], capture_output=True, text=True,
                           timeout=timeout)
    except (OSError, subprocess.TimeoutExpired) as e:
        return 127, "", str(e)
    return p.returncode, p.stdout.strip(), p.stderr.strip()


def q(*args: Any) -> tuple[int, str, str]:
    return sh(["qs", "ipc", "call", *args])


# --------------------------------------------------------------------------- #
# Hyprland monitor/window helpers (Hyprland 0.57 Lua dispatch API)              #
# --------------------------------------------------------------------------- #

def lua_str(value: Any) -> str:
    text = str(value).replace("\\", "\\\\").replace('"', '\\"')
    return f'"{text}"'


def hypr_repl(code: str) -> tuple[bool, str]:
    rc, out, err = sh(["hyprctl", "repl", code])
    text = (out or err).strip()
    return rc == 0 and not text.lower().startswith("error"), text


def hypr_monitors() -> list[dict[str, Any]]:
    rc, out, _ = sh(["hyprctl", "monitors", "-j"])
    if rc == 0:
        try:
            data = json.loads(out)
            if isinstance(data, list):
                return data
        except ValueError:
            pass
    return []


def choose_monitors(script_pref: str | None, plugin_pref: str | None,
                    monitors: list[dict[str, Any]]) -> tuple[str | None, str | None]:
    names = [str(m.get("name", "")) for m in monitors if m.get("name")]
    if not names:
        return None, None
    internal = next((n for n in names if re.match(r"^(eDP|LVDS|DSI)", n, re.I)), None)
    external = next((n for n in names if n != internal), None)

    script = script_pref or external or internal or names[0]
    plugin = plugin_pref or internal
    if not plugin:
        plugin = next((n for n in names if n != script), names[0])
    if plugin == script and len(names) > 1:
        plugin = next((n for n in names if n != script), script)
    return script, plugin


def focus_monitor(name: str | None) -> bool:
    if not name:
        return False
    ok, text = hypr_repl(f"hl.dsp.focus({{monitor={lua_str(name)}}})")
    if not ok:
        print(f"warning: could not focus monitor {name}: {text}", file=sys.stderr)
    return ok


def move_active_to_monitor(name: str | None) -> bool:
    if not name:
        return False
    ok, text = hypr_repl(f"hl.dsp.window.move({{monitor={lua_str(name)}}})")
    if not ok:
        print(f"warning: could not move the script window to {name}: {text}",
              file=sys.stderr)
    return ok


def screenshot(path: Path, monitor: str | None = None) -> bool:
    args = ["grim"]
    if monitor:
        args += ["-o", monitor]
    args.append(str(path))
    rc, out, err = sh(args)
    if rc != 0:
        print(f"warning: screenshot failed: {err or out}", file=sys.stderr)
        return False
    return True


def load_plugin_data() -> tuple[list[dict[str, Any]], dict[str, Any]]:
    js = r'''
const load = require(process.argv[1]);
const root = process.argv[2];
process.stdout.write(JSON.stringify({
  registry: load(root + "/Plugins.js").list || [],
  info: load(root + "/PluginInfo.js").info || {}
}));
'''
    rc, out, err = sh(["node", "-e", js, str(TEST_DIR / "jsload.js"), str(SHELL_DIR)])
    if rc == 0:
        try:
            data = json.loads(out)
            return data["registry"], data["info"]
        except (ValueError, KeyError):
            pass
    print(f"warning: could not load PluginInfo.js ({err or out}); using ids only",
          file=sys.stderr)
    ids: list[dict[str, Any]] = []
    for p in plugin_state().values():
        ids.append({"id": p.get("id", ""), "label": p.get("id", ""), "source": ""})
    return ids, {}


def plugin_state() -> dict[str, dict[str, Any]]:
    rc, out, _ = q("plugins", "list")
    if rc != 0:
        return {}
    try:
        return {p["id"]: p for p in json.loads(out)}
    except (ValueError, KeyError, TypeError):
        return {}


def wait_state(plugin_id: str, active: bool, timeout: float = 5.0) -> bool:
    """Wait for a plugin to reach `active`.

    Windowed plugins are only "ready" once `loaded` matches too; no-window
    plugins can stay `loaded=false` forever, so `active` alone is accepted
    once the timeout elapses without `loaded` ever matching.
    """
    end = time.monotonic() + timeout
    active_match = False
    while time.monotonic() < end:
        s = plugin_state().get(plugin_id)
        if s and bool(s.get("active")) == active:
            if not active:
                return True
            if bool(s.get("loaded")) == active:
                return True
            active_match = True
        time.sleep(0.1)
    return active_match


def set_plugin(plugin_id: str, active: bool) -> bool:
    if plugin_id == "settings":
        return True
    state = "on" if active else "off"
    rc, out, err = q("aequalyn", "plugin", plugin_id, state)
    if rc != 0:
        raise RuntimeError(err or out or f"could not turn {plugin_id} {state}")
    return wait_state(plugin_id, active)


def ipc_functions() -> dict[str, set[str]]:
    rc, out, _ = sh(["qs", "ipc", "show"])
    result: dict[str, set[str]] = {}
    target = ""
    for line in out.splitlines():
        m = re.match(r"^target\s+(\S+)", line)
        if m:
            target = m.group(1)
            result.setdefault(target, set())
            continue
        m = re.match(r"^\s+function\s+(\w+)", line)
        if m and target:
            result[target].add(m.group(1))
    return result


def send_escape() -> str:
    down = 'hl.dispatch(hl.dsp.send_key_state({key="ESCAPE",mods="",state="down"}))'
    up = ('hl.timer(function() '
          'hl.dispatch(hl.dsp.send_key_state({key="ESCAPE",mods="",state="up"})) '
          'end, {timeout=50,type="oneshot"})')
    sh(["hyprctl", "repl", down])
    sh(["hyprctl", "repl", up])
    return "sent Escape to the focused client"


def volume_get() -> float | None:
    rc, out, _ = sh(["wpctl", "get-volume", VOLUME_SINK])
    if rc == 0:
        m = re.search(r"Volume:\s*([0-9.]+)", out)
        if m:
            return float(m.group(1))
    return None


def volume_set(value: float) -> str:
    rc, out, err = sh(["wpctl", "set-volume", VOLUME_SINK, f"{value:.4f}"])
    if rc != 0:
        raise RuntimeError(err or out or "wpctl set-volume failed")
    return f"volume set to {value:.2f}"


def run_step(step: str, saved_volume: dict[str, float | None]) -> str:
    if step == "@escape":
        return send_escape()
    if step == "@volume-bump":
        old = volume_get()
        saved_volume["value"] = old
        if old is None:
            rc, out, err = sh(["wpctl", "set-volume", VOLUME_SINK, "2%+"])
            if rc != 0:
                raise RuntimeError(err or out)
            return "volume raised by 2% (OSD)"
        return volume_set(min(1.0, old + 0.02))
    if step == "@volume-restore":
        old = saved_volume.get("value")
        if old is None:
            rc, out, err = sh(["wpctl", "set-volume", VOLUME_SINK, "2%-"])
            if rc != 0:
                raise RuntimeError(err or out)
            return "volume lowered by 2%"
        return volume_set(old)
    if step == "@noop":
        return "(no close command; restore happens automatically)"

    args = shlex.split(step)
    if not args:
        return "(nothing)"
    rc, out, err = sh(args)
    text = out or err or "ok"
    if rc != 0:
        raise RuntimeError(text)
    if args[:3] == ["qs", "ipc", "call"] and re.match(
            r"^(no plugin|unknown|error|say |not )", text, re.I):
        raise RuntimeError(text)
    return text


def validate(sc: Scenario, funcs: dict[str, set[str]]) -> list[str]:
    problems: list[str] = []
    for step in sc.open + sc.close:
        if step.startswith("@"):
            if step.startswith("@volume") and shutil.which("wpctl") is None:
                problems.append("wpctl is not installed")
            continue
        try:
            args = shlex.split(step)
        except ValueError as e:
            problems.append(f"bad command {step!r}: {e}")
            continue
        if args[:3] == ["qs", "ipc", "call"]:
            i = 3
            if i < len(args) and args[i] == "--":
                i += 1
            if i + 1 >= len(args):
                problems.append(f"incomplete IPC call: {step}")
            else:
                target, func = args[i], args[i + 1]
                if target not in funcs:
                    problems.append(f"IPC target {target!r} is not registered")
                elif func not in funcs[target]:
                    problems.append(f"IPC function {target}.{func} does not exist")
    return problems


# --------------------------------------------------------------------------- #
# interactive flow                                                             #
# --------------------------------------------------------------------------- #

def ask(prompt: str) -> str:
    try:
        return input(prompt).strip().lower()
    except EOFError:
        return "q"


def confirm(phase: str, plugin_id: str, command: str, output: str,
            session_dir: Path, index: int, monitor: str | None = None) -> str:
    print(f"    {command}")
    if output and len(output) < 300:
        print(f"    -> {output}")
    expected = "opened and rendered" if phase == "open" else "closed cleanly"
    print(f"    Check that the plugin {expected}. {HELP}")
    while True:
        choice = ask(f"    [{plugin_id}/{phase}] ")
        if choice in ("", "y", "ok", "good"):
            return "ok"
        if choice in ("s", "shot", "screenshot"):
            path = session_dir / f"{index:02d}-{plugin_id}-{phase}.png"
            if screenshot(path, monitor):
                print(f"    saved {path}")
            continue
        if choice in ("e", "esc", "escape"):
            print(f"    {send_escape()}")
            continue
        if choice in ("r", "retry", "again"):
            return "retry"
        if choice in ("n", "f", "fail", "bad"):
            return "fail"
        if choice in ("k", "skip"):
            return "skip"
        if choice in ("q", "quit", "exit"):
            raise QuitWalkthrough
        print(f"    {HELP}")


def check_plugin(index: int, plugin_id: str, label: str, meta: dict[str, Any],
                  sc: Scenario, session_dir: Path, settle: float,
                  include_dangerous: bool, auto: bool = False,
                  wait: float = 1.5, plugin_monitor: str | None = None,
                  auto_shots: bool = True) -> dict[str, Any]:
    result: dict[str, Any] = {
        "id": plugin_id, "label": label, "status": "", "notes": [], "screenshots": [],
    }
    if meta.get("keys"):
        result["notes"].append(f"advertised shortcut: {meta['keys']}")

    print(f"\n[{index:02d}] {plugin_id} — {label}")
    if sc.dangerous and not include_dangerous:
        print(f"    skipped (potentially disruptive: {sc.note})")
        result["status"] = "SKIP"
        return result
    if auto and sc.requires_interaction:
        print("    skipped: this check needs interactive confirmation")
        result["status"] = "SKIP"
        result["notes"].append("requires interactive confirmation")
        return result

    print(f"    {sc.note}")
    if sc.dangerous:
        print("    WARNING: this one is intentionally disruptive.")
    if auto:
        print(f"    auto mode: {wait:g}s per phase"
              f"{', screenshots on ' + plugin_monitor if auto_shots and plugin_monitor else ''}")

    state = plugin_state()
    before = state.get(plugin_id)
    was_active = bool(before and before.get("active"))
    enabled_here = False

    try:
        if not was_active and plugin_id != "settings":
            print("    enabling plugin temporarily...")
            ok = set_plugin(plugin_id, True)
            enabled_here = True
            if not ok and not sc.dangerous:
                result["status"] = "ERROR"
                result["notes"].append("plugin did not become active/loaded")
                return result
            if not ok:
                result["notes"].append("plugin did not stay loaded (expected for self-test)")

        funcs = ipc_functions()
        problems = validate(sc, funcs)
        if problems:
            result["status"] = "ERROR"
            result["notes"].extend(problems)
            return result

        saved_volume: dict[str, float | None] = {"value": None}
        phase = "open"
        while True:
            focus_monitor(plugin_monitor)
            steps = sc.open if phase == "open" else sc.close
            command = " ; ".join(steps) if steps else "(enabled; watch the result)"
            try:
                outputs = [run_step(s, saved_volume) for s in steps]
                output = " | ".join(o for o in outputs if o)
            except Exception as e:
                result["status"] = "ERROR"
                result["notes"].append(f"{phase} failed: {e}")
                break

            print(f"    {command}")
            if output and len(output) < 300:
                print(f"    -> {output}")

            if auto:
                time.sleep(wait)
                if auto_shots:
                    shot = session_dir / f"{index:02d}-{plugin_id}-{phase}.png"
                    if screenshot(shot, plugin_monitor):
                        print(f"    saved {shot}")
                answer = "ok"
            else:
                time.sleep(settle)
                try:
                    answer = confirm(phase, plugin_id, command, output,
                                     session_dir, index, plugin_monitor)
                except QuitWalkthrough:
                    result["status"] = "SKIP"
                    result["notes"].append("quit during check")
                    raise

            if answer == "retry":
                if phase == "open":
                    try:
                        for s in sc.close:
                            run_step(s, saved_volume)
                    except Exception as e:
                        result["notes"].append(f"retry close failed: {e}")
                else:
                    phase = "open"
                continue

            if answer == "skip":
                result["status"] = "SKIP"
                result["notes"].append(f"skipped during {phase} check")
                break

            if answer == "fail":
                result["status"] = "FAIL"
                result["notes"].append(f"{phase} check failed")
                break

            if phase == "open":
                phase = "closed"
                continue
            break

        if not result["status"]:
            result["status"] = "PASS"
            if auto:
                result["notes"].append(
                    "open/render/close commands succeeded; see screenshot/video")
            else:
                result["notes"].append("opened, rendered and closed as expected")
    except QuitWalkthrough:
        raise
    except Exception as e:
        result["status"] = "ERROR"
        result["notes"].append(str(e))
    finally:
        if enabled_here:
            try:
                set_plugin(plugin_id, False)
                print("    restored: plugin disabled again")
            except Exception as e:
                result["notes"].append(f"could not restore state: {e}")
        for p in session_dir.glob(f"{index:02d}-{plugin_id}-*.png"):
            result["screenshots"].append(str(p))
    return result


def start_recording(monitor: str | None = None) -> tuple[bool, str | None]:
    rc, out, _ = sh(["aequalyn-record", "status"])
    if rc == 0 and out.strip() == "recording":
        path_file = REC_STATE / "output"
        path = path_file.read_text().strip() if path_file.exists() else None
        print(f"Using the recording already in progress: {path}")
        return False, path
    args = ["aequalyn-record", "start"]
    if monitor:
        args += ["-w", monitor, "-f", "60"]
    rc, out, err = sh(args)
    if rc != 0:
        raise RuntimeError(err or out or "aequalyn-record start failed")
    time.sleep(1.0)
    path_file = REC_STATE / "output"
    path = path_file.read_text().strip() if path_file.exists() else None
    print(f"Recording: {path}")
    return True, path


def stop_recording(started: bool) -> str | None:
    if not started:
        return None
    rc, out, err = sh(["aequalyn-record", "stop"])
    if rc != 0:
        print(f"warning: could not stop recording: {err or out}", file=sys.stderr)
        return None
    return f"recording stopped: {out}" if out else "recording stopped"


def write_log(session_dir: Path, results: list[dict[str, Any]],
              plugin_list: list[dict[str, Any]], video: Path | None,
              video_note: str, meta: dict[str, Any] | None = None) -> None:
    payload: dict[str, Any] = {
        "created": datetime.now().isoformat(timespec="seconds"),
        "video": str(video) if video else None,
        "video_note": video_note,
    }
    if meta:
        payload.update(meta)
    payload["results"] = results
    payload["plugin_list"] = plugin_list
    (session_dir / "results.json").write_text(json.dumps(payload, indent=2),
                                              encoding="utf-8")

    lines = [
        "# Aequalyn plugin walkthrough",
        "",
        f"Created: {datetime.now().isoformat(timespec='seconds')}",
        f"Video: {video or 'none'}",
    ]
    if meta:
        lines += [f"{key}: {value}" for key, value in meta.items()]
    lines += [
        "",
        "| Plugin | Label | Result | Notes |",
        "| --- | --- | --- | --- |",
    ]
    by_id = {r["id"]: r for r in results}
    for p in plugin_list:
        r = by_id.get(p.get("id", ""), {})
        notes = "; ".join(r.get("notes", [])).replace("|", "\\|")
        lines.append(f"| `{p.get('id', '')}` | {p.get('label', '')} | "
                     f"{r.get('status', 'MISSING')} | {notes} |")
    (session_dir / "results.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main(argv: list[str] | None = None, session_dir: Path | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    mode = ap.add_mutually_exclusive_group()
    mode.add_argument("--record", action="store_true", help="start a screen recording")
    mode.add_argument("--no-record", action="store_true", help="do not record")
    ap.add_argument("--auto", "--non-interactive", action="store_true",
                    help="run without prompts; wait a fixed time per phase")
    ap.add_argument("--only", help="comma-separated plugin ids to check")
    ap.add_argument("--dangerous", action="store_true",
                    help="include the watchdog/root self-tests")
    ap.add_argument("--real-lock", action="store_true",
                    help="really lock the session instead of previewing lock looks")
    ap.add_argument("--settle", type=float, default=0.7,
                    help="interactive: seconds to wait after each phase (default: 0.7)")
    ap.add_argument("--wait", type=float, default=1.5,
                    help="auto: seconds to wait after each phase (default: 1.5)")
    ap.add_argument("--no-shots", action="store_true",
                    help="auto: do not save screenshots of the plugin monitor")
    ap.add_argument("--script-monitor", help="monitor for this script's terminal window")
    ap.add_argument("--plugin-monitor", help="monitor where plugin UIs should appear")
    ap.add_argument("--dry-run", "--list", action="store_true",
                    help="print the plan without changing anything")
    args = ap.parse_args(argv)

    registry, info = load_plugin_data()
    original = plugin_state()
    if not registry:
        print("FATAL: no plugins registered", file=sys.stderr)
        return 2
    if not original:
        print("FATAL: `qs ipc call plugins list` did not return plugin state",
              file=sys.stderr)
        return 2

    if args.real_lock:
        SCENARIOS["lock"] = LOCK_REAL

    monitors = hypr_monitors()
    script_monitor, plugin_monitor = choose_monitors(
        args.script_monitor, args.plugin_monitor, monitors)
    if args.script_monitor and args.script_monitor not in [m.get("name") for m in monitors]:
        print(f"FATAL: unknown --script-monitor {args.script_monitor!r}", file=sys.stderr)
        return 2
    if args.plugin_monitor and args.plugin_monitor not in [m.get("name") for m in monitors]:
        print(f"FATAL: unknown --plugin-monitor {args.plugin_monitor!r}", file=sys.stderr)
        return 2

    if args.only:
        wanted = [x.strip() for x in args.only.split(",") if x.strip()]
        unknown = [x for x in wanted if x not in {p.get("id") for p in registry}]
        if unknown:
            print(f"FATAL: unknown plugin id(s): {', '.join(unknown)}", file=sys.stderr)
            return 2
        registry = [p for p in registry if p.get("id") in wanted]

    if args.dry_run:
        print(f"Plan: {len(registry)} plugins")
        print(f"Mode: {'auto' if args.auto else 'interactive'}")
        print(f"Script monitor: {script_monitor or 'default'}")
        print(f"Plugin monitor: {plugin_monitor or 'default'}")
        for i, p in enumerate(registry, 1):
            pid = p.get("id", "")
            sc = SCENARIOS.get(pid)
            if not sc:
                print(f"{i:02d} {pid:18} NO SCENARIO", file=sys.stderr)
                continue
            print(f"{i:02d} {pid:18} {p.get('label', '')}")
            print(f"    open:  {' ; '.join(sc.open) or '(no call)'}")
            print(f"    close: {' ; '.join(sc.close) or '(no call)'}")
            if sc.dangerous:
                print("    (requires --dangerous)")
        return 0

    if session_dir is None:
        stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        session_dir = VIDEOS / f"Aequalyn-plugin-check-{stamp}"
    session_dir = Path(session_dir)
    session_dir.mkdir(parents=True, exist_ok=True)
    print(f"Artifacts: {session_dir}")

    setup_monitors = args.auto or bool(args.script_monitor) or bool(args.plugin_monitor)
    if setup_monitors:
        print(f"Script window -> {script_monitor or 'current monitor'}")
        if script_monitor:
            move_active_to_monitor(script_monitor)
        print(f"Plugins -> {plugin_monitor or 'current monitor'}")
        if plugin_monitor:
            focus_monitor(plugin_monitor)

    recording_started = False
    recording_path: str | None = None
    video_file: Path | None = None
    video_note = "no recording"

    want_record = args.record or not args.no_record and (args.auto or sys.stdin.isatty())
    if want_record:
        try:
            recording_started, recording_path = start_recording(plugin_monitor)
            video_note = f"recording source: {recording_path}"
        except Exception as e:
            print(f"warning: recording not started: {e}", file=sys.stderr)

    results: list[dict[str, Any]] = []
    aborted = False
    try:
        for i, p in enumerate(registry, 1):
            pid = p.get("id", "")
            sc = SCENARIOS.get(pid)
            if not sc:
                # A plugin added after this harness was written is not a failure
                # of the shell: report it as skipped, with a snapshot taken later.
                results.append({"id": pid, "label": p.get("label", pid),
                                "status": "SKIP", "notes": ["no scenario defined for this plugin"]})
                continue
            result = check_plugin(
                i, pid, p.get("label", pid), info.get(pid, {}),
                sc, session_dir,
                args.settle if not args.auto else args.wait,
                args.dangerous,
                auto=args.auto,
                wait=args.wait,
                plugin_monitor=plugin_monitor,
                auto_shots=not args.no_shots,
            )
            results.append(result)
    except QuitWalkthrough:
        aborted = True
        print("\nQuit requested; restoring state.")
    except KeyboardInterrupt:
        aborted = True
        print("\nInterrupted; restoring state.")
    finally:
        # Restore the exact enabled state we saw at startup.
        for pid, before in original.items():
            if pid == "settings":
                continue
            now = plugin_state().get(pid)
            if not now:
                continue
            if bool(now.get("active")) != bool(before.get("active")):
                try:
                    set_plugin(pid, bool(before.get("active")))
                except Exception as e:
                    print(f"warning: could not restore {pid}: {e}", file=sys.stderr)
        note = stop_recording(recording_started)
        if note:
            video_note += f"; {note}"
        if recording_started and recording_path:
            source = Path(recording_path)
            for _ in range(20):
                if source.exists() and source.stat().st_size > 0:
                    break
                time.sleep(0.1)
            if source.exists() and source.stat().st_size > 0:
                video_file = session_dir / "walkthrough.mp4"
                try:
                    shutil.copy2(source, video_file)
                    video_note += f"; copied to {video_file}"
                except OSError as e:
                    print(f"warning: could not copy video: {e}", file=sys.stderr)
                    video_file = None

    if setup_monitors and script_monitor:
        focus_monitor(script_monitor)
        print(f"Focused script monitor again: {script_monitor}")

    if aborted:
        done = {r["id"] for r in results}
        for p in registry:
            if p.get("id") not in done:
                results.append({"id": p.get("id", ""), "label": p.get("label", ""),
                                "status": "SKIP", "notes": ["not checked (walkthrough ended)"]})

    meta = {
        "mode": "auto" if args.auto else "interactive",
        "script_monitor": script_monitor,
        "plugin_monitor": plugin_monitor,
    }
    write_log(session_dir, results, registry, video_file, video_note, meta)

    counts = {s: sum(1 for r in results if r["status"] == s)
              for s in ("PASS", "FAIL", "ERROR", "SKIP")}
    print("\nSummary: " + ", ".join(f"{v} {k.lower()}" for k, v in counts.items() if v))
    print(f"Log: {session_dir / 'results.md'}")
    if video_file:
        print(f"Video: {video_file}")
    elif recording_path:
        print(f"Video: {recording_path}")
    return 1 if counts["FAIL"] or counts["ERROR"] else 0


if __name__ == "__main__":
    sys.exit(main())
