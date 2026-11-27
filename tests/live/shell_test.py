#!/usr/bin/env python3
"""
Aequalyn shell test — one app for keybinds + plugins.

A single runnable app that checks a live Aequalyn/Hyprland shell in two phases:

1. KEYBINDS — every Hyprland keybind registered in the running compositor is
   verified against the expected-behaviour manifest in keybind_test.py
   (effect, flags, no duplicates, no unexpected binds, and executable / IPC
   target smoke checks). Read-only: nothing is launched and no keybind is
   fired. (keybind tests/tests/keybind_test.py)

2. PLUGINS — every registered plugin is temporarily enabled if needed, opened
   (called / rendered) and then closed again to prove it works, and its
   original enabled state is restored. (plugin_walkthrough.py, auto mode)

3. WATCHDOG — the supervisor's disabled list and Settings' enabled list are
   snapshotted before the run. Anything the watchdog kills during the tests is
   accounted for and re-enabled at the end, even when a phase aborts. The
   result is reported separately; a failure to restore it fails the run.

A screenshot is saved for each plugin. Plugins are captured open and closed,
and any plugin left without a screenshot is retried once; a plugin that still
has no screenshot is reported as failed.

Everything lands in one output directory (default
~/Videos/Aequalyn-test-<timestamp>/):

    keybinds.json          keybind test results (machine readable)
    keybinds.txt           keybind test results (human readable)
    plugins/NN-<id>-open.png      screenshot with the plugin open
    plugins/NN-<id>-closed.png    screenshot after it closed
    plugins/results.json / results.md   per-plugin walkthrough log
    watchdog.json          plugins killed during the run and restoration result
    results.json           combined machine-readable report
    results.md             combined human-readable report

Usage:
    python3 shell_test.py
    python3 shell_test.py --out ~/Videos/my-run --wait 2
    python3 shell_test.py --only calculator,emoji,store
    python3 shell_test.py --keybinds-only
    python3 shell_test.py --plugins-only
    python3 shell_test.py --no-smoke          # keybinds: skip existence checks
    python3 shell_test.py --record            # also record video (aequalyn-record)
    python3 shell_test.py --dangerous         # include disruptive self-tests
    python3 shell_test.py --script-monitor <terminal-monitor> --plugin-monitor <ui-monitor>

Exit status: 0 = everything checked passed and every screenshot was saved,
1 = at least one keybind or plugin failed / a screenshot is missing,
2 = the app itself could not run (e.g. Hyprland or the shell is not up).
"""

from __future__ import annotations

import argparse
import contextlib
import importlib.util
import io
import json
import sys
import time
from datetime import datetime
from pathlib import Path
from types import ModuleType
from typing import Any

REPO = Path(__file__).resolve().parent
HOME = Path.home()
VIDEOS = HOME / "Videos"

KEYBIND_TEST_PY = REPO / "keybind_test.py"
WALKTHROUGH_PY = REPO / "plugin_walkthrough.py"

FAIL_STATUSES = {"FAIL", "ERROR"}


# --------------------------------------------------------------------------- #
# module loading                                                              #
# --------------------------------------------------------------------------- #

def load_module(name: str, path: Path) -> ModuleType:
    """Import a test module by file path (the keybinds dir name has a space)."""
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise ImportError(f"cannot load module {name} from {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


# --------------------------------------------------------------------------- #
# watchdog accounting                                                          #
# --------------------------------------------------------------------------- #

WATCHDOG = "aequalyn-watchdog"
SETTINGS = HOME / ".config" / "aequalyn" / "settings.json"


def watchdog_output(args: list[str], timeout: float = 20) -> str:
    try:
        import subprocess
        r = subprocess.run([WATCHDOG, *args], capture_output=True, text=True, timeout=timeout)
        return (r.stdout or "") + (r.stderr or "")
    except Exception as e:
        return f"error: {type(e).__name__}: {e}"


def watchdog_disabled() -> dict[str, str]:
    """Plugins the watchdog has turned off, with the reason it gave."""
    text = watchdog_output(["status"])
    out: dict[str, str] = {}
    in_section = False
    for line in text.splitlines():
        if line.strip() == "turned off by the watchdog:":
            in_section = True
            continue
        if not in_section or not line.startswith("  "):
            continue
        body = line.strip()
        if ":" in body:
            pid, reason = body.split(":", 1)
            out[pid.strip()] = reason.strip()
    return out


def settings_enabled() -> list[str]:
    """The Settings -> Plugins source of truth, read straight from settings.json."""
    try:
        d = json.loads(SETTINGS.read_text(encoding="utf-8"))
        plugins = d.get("plugins", [])
        return [p for p in plugins if isinstance(p, str)]
    except Exception:
        return []


def watchdog_snapshot() -> dict[str, Any]:
    return {"disabled": watchdog_disabled(), "enabled": settings_enabled()}


def restore_watchdog(before: dict[str, Any], out_dir: Path) -> dict[str, Any]:
    """Re-enable whatever the watchdog killed during the run; report it."""
    after = watchdog_snapshot()
    before_off = set(before.get("disabled", {}))
    after_off = set(after.get("disabled", {}))
    before_on = set(before.get("enabled", []))
    after_on = set(after.get("enabled", []))

    killed = sorted((after_off - before_off) | (before_on - after_on))
    reenabled: list[str] = []
    failed: dict[str, str] = {}
    for pid in killed:
        out = watchdog_output(["enable", pid])
        if "error" in out.lower() or "not supervised" in out.lower():
            failed[pid] = out.strip()[:300]
        else:
            reenabled.append(pid)

    # give the supervisor a moment to start each host, then verify
    deadline = time.time() + 15
    still_off: dict[str, str] = {}
    while killed:
        current = watchdog_disabled()
        still_off = {p: current.get(p, "not listed as up") for p in killed if p in current
                     or p not in settings_enabled()}
        if not still_off or time.time() > deadline:
            break
        time.sleep(0.5)
    final = watchdog_snapshot()
    ok = not failed and not still_off

    report = {
        "ok": ok,
        "before": before,
        "after": after,
        "killed_during_test": killed,
        "reenabled": reenabled,
        "failed_to_reenable": failed,
        "still_off": still_off,
        "final_disabled": final.get("disabled", {}),
    }
    (out_dir / "watchdog.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    if killed:
        print(f"watchdog: {len(killed)} plugin(s) disabled during the test: "
              + ", ".join(killed))
        print(f"watchdog: re-enabled {len(reenabled)}"
              + (f"; FAILED: {', '.join(failed)}" if failed else ""))
        if still_off:
            print(f"watchdog: still off after restore: {', '.join(still_off)}")
    return report


# --------------------------------------------------------------------------- #
# phase 1: keybinds                                                           #
# --------------------------------------------------------------------------- #

def run_keybinds(keybind_test: ModuleType, no_smoke: bool, out_dir: Path) -> dict[str, Any]:
    """Run keybind_test.main() capturing its JSON; save raw + text forms."""
    argv = ["keybind_test.py", "--json"]
    if no_smoke:
        argv.append("--no-smoke")

    saved_argv = sys.argv
    stdout, stderr = io.StringIO(), io.StringIO()
    code = 2
    try:
        sys.argv = argv
        with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            code = int(keybind_test.main())
    except SystemExit as e:  # argparse or explicit exit inside the test
        code = int(e.code or 0)
    except Exception as e:  # never let a keybind-test bug kill the plugin phase
        stderr.write(f"{type(e).__name__}: {e}")
    finally:
        sys.argv = saved_argv

    raw_out = stdout.getvalue().strip()
    fatal = stderr.getvalue().strip()

    payload: dict[str, Any]
    try:
        payload = json.loads(raw_out) if raw_out else {}
    except ValueError:
        payload = {"results": []}
    results = payload.get("results") or []
    counts = payload.get("counts") or {
        s: sum(1 for r in results if r.get("status") == s)
        for s in ("PASS", "FAIL", "SKIP")
    }

    payload.update({
        "counts": counts,
        "exit_code": code,
        "fatal": fatal or None,
    })
    (out_dir / "keybinds.json").write_text(json.dumps(payload, indent=2), encoding="utf-8")

    # human-readable rendering, same shape as keybind_test.py's text mode
    lines = []
    width = max((len(str(r.get("key", ""))) for r in results), default=10)
    lines.append(f"Hyprland keybind test — {len(results)} results")
    for r in results:
        lines.append(f"[{str(r.get('status', '?')):4}] {str(r.get('key', '')):<{width}}  {r.get('label', '')}")
        if r.get("status") != "PASS" or r.get("detail"):
            lines.append(f"         {'':<{width}}  {r.get('detail', '')}")
    lines.append("")
    lines.append(f"Summary: {counts.get('PASS', 0)} passed, {counts.get('SKIP', 0)} skipped, "
                 f"{counts.get('FAIL', 0)} failed")
    if fatal:
        lines.append(f"FATAL: {fatal}")
    text = "\n".join(lines) + "\n"
    (out_dir / "keybinds.txt").write_text(text, encoding="utf-8")

    return payload


# --------------------------------------------------------------------------- #
# phase 2: plugins                                                            #
# --------------------------------------------------------------------------- #

def existing_shots(result: dict[str, Any]) -> list[str]:
    """Screenshots recorded for a plugin that actually exist on disk."""
    shots = []
    for s in result.get("screenshots", []):
        p = Path(s)
        if p.is_file() and p.stat().st_size > 0:
            shots.append(str(p))
    return shots


def scan_shots(session_dir: Path, plugin_id: str) -> list[str]:
    """Find screenshots belonging to a plugin inside the plugins directory."""
    out = []
    for p in sorted(session_dir.glob(f"*-{plugin_id}-*.png")) + \
             sorted(session_dir.glob(f"*-{plugin_id}.png")):
        if p.is_file() and p.stat().st_size > 0:
            out.append(str(p))
    return sorted(set(out))


def run_plugins(walkthrough: ModuleType, argv: list[str], session_dir: Path) -> list[dict[str, Any]]:
    """Run the plugin walkthrough in auto mode; return per-plugin results."""
    session_dir.mkdir(parents=True, exist_ok=True)
    walkthrough.main(argv, session_dir=session_dir)
    results_path = session_dir / "results.json"
    if not results_path.is_file():
        raise RuntimeError(f"plugin walkthrough did not write {results_path}")
    data = json.loads(results_path.read_text(encoding="utf-8"))
    return data.get("results", [])


def retake_missing_screenshots(walkthrough: ModuleType, results: list[dict[str, Any]],
                               session_dir: Path, plugin_monitor: str | None,
                               wait: float, dangerous: bool,
                               registry_index: dict[str, int],
                               info: dict[str, Any]) -> None:
    """Second attempt for every plugin that ended up without a screenshot."""
    scenarios = walkthrough.SCENARIOS
    for r in results:
        if existing_shots(r):
            continue
        pid = r.get("id", "")
        sc = scenarios.get(pid)
        notes = r.setdefault("notes", [])
        # skipped / dangerous plugins are never opened; no second attempt,
        # but still grab a plain snapshot so every plugin has a screenshot
        skipped = (sc is None or r.get("status") == "SKIP"
                   or (sc.dangerous and not dangerous))
        if not skipped:
            print(f"    screenshot missing for {pid}; retrying open/close once...")
            try:
                retry = walkthrough.check_plugin(
                    registry_index.get(pid, len(registry_index)),
                    pid, r.get("label", pid), info.get(pid, {}), sc,
                    session_dir, wait, dangerous,
                    auto=True, wait=wait, plugin_monitor=plugin_monitor,
                    auto_shots=True,
                )
                notes.append("screenshot retaken after first attempt produced none")
                if retry.get("status") in FAIL_STATUSES and r.get("status") not in FAIL_STATUSES:
                    r["status"] = retry["status"]
                    notes.extend(retry.get("notes", []))
            except Exception as e:
                notes.append(f"screenshot retry failed: {e}")
        r["screenshots"] = scan_shots(session_dir, pid)
        # last resort: capture whatever is on screen right now as evidence
        if not r["screenshots"]:
            try:
                walkthrough.focus_monitor(plugin_monitor)
                kind = "skipped" if skipped else "fallback"
                target = session_dir / f"{registry_index.get(pid, 0):02d}-{pid}-{kind}.png"
                if walkthrough.screenshot(target, plugin_monitor):
                    r["screenshots"] = [str(target)]
                    if skipped:
                        notes.append("snapshot only; plugin was not opened (disruptive or unavailable)")
                    else:
                        notes.append("fallback screenshot of current screen (plugin may not be visible)")
            except Exception as e:
                notes.append(f"fallback screenshot failed: {e}")


def finalize_screenshots(results: list[dict[str, Any]], session_dir: Path) -> None:
    """Make sure every plugin has at least one verified screenshot on disk."""
    for r in results:
        pid = r.get("id", "")
        shots = sorted(set(existing_shots(r)) | set(scan_shots(session_dir, pid)))
        r["screenshots"] = shots
        r["has_screenshot"] = bool(shots)
        r["screenshot_count"] = len(shots)
        rendered = [s for s in shots if not s.endswith(("-fallback.png", "-skipped.png"))]
        r["screenshot_of_plugin"] = bool(rendered)
        r["screenshot_source"] = "plugin" if rendered else ("snapshot" if shots else "none")


def rewrite_plugin_log(walkthrough: ModuleType, session_dir: Path,
                       results: list[dict[str, Any]]) -> None:
    """Keep plugins/results.json + results.md in sync after screenshot retries."""
    results_path = session_dir / "results.json"
    old: dict[str, Any] = {}
    if results_path.is_file():
        try:
            old = json.loads(results_path.read_text(encoding="utf-8"))
        except ValueError:
            old = {}
    # registry order/labels were preserved by the walkthrough; rebuild if not
    plugin_list = old.get("plugin_list") or [
        {"id": r.get("id", ""), "label": r.get("label", "")} for r in results
    ]
    video = old.get("video")
    video_note = old.get("video_note", "no recording")
    meta = {k: v for k, v in old.items()
            if k not in ("created", "video", "video_note", "results", "plugin_list")}
    walkthrough.write_log(session_dir, results, plugin_list,
                          Path(video) if video else None, video_note, meta)


# --------------------------------------------------------------------------- #
# combined report                                                             #
# --------------------------------------------------------------------------- #

def write_combined(out_dir: Path, keybinds: dict[str, Any] | None,
                   plugins: list[dict[str, Any]] | None,
                   plugins_dir: Path, created: str,
                   keybinds_enabled: bool, plugins_enabled: bool,
                   watchdog: dict[str, Any] | None = None) -> dict[str, Any]:
    kb_counts = (keybinds or {}).get("counts", {})
    kb_failed = [r for r in (keybinds or {}).get("results", []) if r.get("status") == "FAIL"]
    kb_fatal = (keybinds or {}).get("fatal")

    plugin_failed = [r for r in (plugins or []) if r.get("status") in FAIL_STATUSES]
    plugin_skipped = [r for r in (plugins or []) if r.get("status") == "SKIP"]
    no_shot = [r for r in (plugins or [])
               if r.get("status") not in ("SKIP",) and not r.get("has_screenshot", bool(existing_shots(r)))]

    all_shots = sorted(p for r in (plugins or []) for p in r.get("screenshots", []))

    ok = True
    if keybinds_enabled:
        ok = ok and not kb_failed and not kb_fatal and (keybinds or {}).get("exit_code", 2) == 0
    if plugins_enabled:
        ok = ok and not plugin_failed and not no_shot
    if watchdog is not None:
        ok = ok and watchdog.get("ok", False)

    combined: dict[str, Any] = {
        "created": created,
        "ok": ok,
        "out_dir": str(out_dir),
        "keybinds": {
            "enabled": keybinds_enabled,
            "counts": kb_counts,
            "exit_code": (keybinds or {}).get("exit_code"),
            "fatal": kb_fatal,
            "failed": kb_failed,
            "results_file": str(out_dir / "keybinds.json") if keybinds_enabled else None,
            "results": (keybinds or {}).get("results", []),
        },
        "plugins": {
            "enabled": plugins_enabled,
            "plugins_dir": str(plugins_dir),
            "counts": {s: sum(1 for r in (plugins or []) if r.get("status") == s)
                       for s in ("PASS", "FAIL", "ERROR", "SKIP")},
            "failed": plugin_failed,
            "skipped": plugin_skipped,
            "missing_screenshots": no_shot,
            "screenshot_count": len(all_shots),
            "results": plugins or [],
        },
        "watchdog": watchdog or {
            "enabled": False,
            "ok": True,
            "killed_during_test": [],
            "reenabled": [],
            "results_file": None,
        },
    }
    watch = combined["watchdog"]
    if watchdog is not None:
        watch["results_file"] = str(out_dir / "watchdog.json")
    (out_dir / "results.json").write_text(json.dumps(combined, indent=2), encoding="utf-8")

    # ------------------------- markdown report ------------------------- #
    md: list[str] = [
        "# Aequalyn shell test",
        "",
        f"Created: {created}",
        f"Result: **{'PASS' if ok else 'FAIL'}**",
        f"Output: `{out_dir}`",
        "",
    ]

    md += ["## Keybinds", ""]
    if not keybinds_enabled:
        md += ["Keybind phase disabled.", ""]
    else:
        md += [
            f"- passed: {kb_counts.get('PASS', 0)}",
            f"- skipped: {kb_counts.get('SKIP', 0)}",
            f"- failed: {kb_counts.get('FAIL', 0)}",
            f"- raw: `keybinds.json`, `keybinds.txt`",
            "",
        ]
        if kb_fatal:
            md += [f"FATAL: {kb_fatal}", ""]
        if kb_failed:
            md += ["| Key | Label | Detail |", "| --- | --- | --- |"]
            for r in kb_failed:
                detail = str(r.get("detail", "")).replace("|", "\\|")
                md.append(f"| `{r.get('key', '')}` | {r.get('label', '')} | {detail} |")
            md.append("")

    md += ["## Plugins", ""]
    if not plugins_enabled:
        md += ["Plugin phase disabled.", ""]
    else:
        counts = combined["plugins"]["counts"]
        total = len(plugins or [])
        md += [
            f"{total} plugins checked; {combined['plugins']['screenshot_count']} screenshots saved "
            f"in `{plugins_dir}`",
            "",
            f"- passed: {counts['PASS']}",
            f"- failed: {counts['FAIL'] + counts['ERROR']}",
            f"- skipped: {counts['SKIP']}",
            f"- missing screenshots: {len(no_shot)}",
            "",
            "| Plugin | Label | Result | Screenshots | Notes |",
            "| --- | --- | --- | --- | --- |",
        ]
        for r in plugins or []:
            notes = "; ".join(str(n) for n in r.get("notes", [])).replace("|", "\\|")
            shots = r.get("screenshots", [])
            shot_cell = (f"{len(shots)} — " + ", ".join(f"`{Path(s).name}`" for s in shots)) if shots else "**none**"
            md.append(f"| `{r.get('id', '')}` | {r.get('label', '')} | {r.get('status', '')} "
                      f"| {shot_cell} | {notes} |")
        md.append("")

    md += ["## Watchdog", ""]
    if watchdog is None:
        md += ["Watchdog accounting was not run.", ""]
    else:
        killed = watchdog.get("killed_during_test", [])
        md += [
            f"- plugins disabled during the test: {len(killed)}"
            + (f" ({', '.join(killed)})" if killed else ""),
            f"- re-enabled: {len(watchdog.get('reenabled', []))}",
            f"- failed to re-enable: {len(watchdog.get('failed_to_reenable', {}))}",
            "- raw: `watchdog.json`",
            "",
        ]
        if watchdog.get("failed_to_reenable"):
            md += [f"FAILED: {watchdog['failed_to_reenable']}", ""]

    md += ["## Screenshots", ""]
    if all_shots:
        for s in all_shots:
            md.append(f"- `{s}`")
    else:
        md.append("(none)")
    md.append("")

    (out_dir / "results.md").write_text("\n".join(md), encoding="utf-8")
    return combined


# --------------------------------------------------------------------------- #
# main                                                                        #
# --------------------------------------------------------------------------- #

def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(
        description="Single app: test Hyprland keybinds + open/close every "
                    "Aequalyn plugin with a screenshot for each.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__)
    ap.add_argument("--out", type=Path, default=None,
                    help="output directory (default ~/Videos/Aequalyn-test-<timestamp>)")
    which = ap.add_mutually_exclusive_group()
    which.add_argument("--keybinds-only", action="store_true", help="only test keybinds")
    which.add_argument("--plugins-only", action="store_true", help="only test plugins")
    ap.add_argument("--only", help="comma-separated plugin ids to check (plugins phase)")
    ap.add_argument("--wait", type=float, default=1.5,
                    help="seconds to wait after each plugin phase (default 1.5)")
    ap.add_argument("--no-smoke", action="store_true",
                    help="keybinds: skip executable / IPC target existence checks")
    ap.add_argument("--record", action="store_true",
                    help="also record video of the plugin phase (aequalyn-record)")
    ap.add_argument("--dangerous", action="store_true",
                    help="include disruptive self-tests (watchdogTest, rootTest)")
    ap.add_argument("--script-monitor", help="monitor for this script's terminal window")
    ap.add_argument("--plugin-monitor", help="monitor where plugin UIs should appear")
    args = ap.parse_args(argv)

    created = datetime.now().isoformat(timespec="seconds")
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    out_dir = (args.out or (VIDEOS / f"Aequalyn-test-{stamp}")).expanduser().resolve()
    plugins_dir = out_dir / "plugins"
    out_dir.mkdir(parents=True, exist_ok=True)
    plugins_dir.mkdir(parents=True, exist_ok=True)

    keybinds_enabled = not args.plugins_only
    plugins_enabled = not args.keybinds_only

    print("=" * 72)
    print("Aequalyn shell test")
    print(f"Output: {out_dir}")
    print(f"Phases: {'keybinds' if keybinds_enabled else ''}"
          f"{' + ' if keybinds_enabled and plugins_enabled else ''}"
          f"{'plugins' if plugins_enabled else ''}")
    print("=" * 72)

    # ---------------- sanity: is the shell up? ---------------- #
    keybind_test = None
    walkthrough = None
    try:
        if keybinds_enabled:
            keybind_test = load_module("aequalyn_keybind_test", KEYBIND_TEST_PY)
        if plugins_enabled:
            walkthrough = load_module("aequalyn_plugin_walkthrough", WALKTHROUGH_PY)
    except Exception as e:
        print(f"FATAL: cannot load test modules: {e}", file=sys.stderr)
        return 2

    # what the watchdog had disabled before we started: anything it disables
    # by the end of the run was killed by the tests and must be brought back
    wd: dict[str, Any] = {"before": watchdog_snapshot()}

    # ---------------- phase 1: keybinds ---------------- #
    keybinds: dict[str, Any] | None = None
    if keybinds_enabled and keybind_test is not None:
        print("\n--- PHASE 1: keybinds ---")
        try:
            keybinds = run_keybinds(keybind_test, args.no_smoke, out_dir)
        except Exception as e:
            keybinds = {"counts": {"PASS": 0, "FAIL": 0, "SKIP": 0}, "results": [],
                        "exit_code": 2, "fatal": f"{type(e).__name__}: {e}"}
            (out_dir / "keybinds.json").write_text(json.dumps(keybinds, indent=2), encoding="utf-8")
            (out_dir / "keybinds.txt").write_text(f"FATAL: {keybinds['fatal']}\n", encoding="utf-8")
        kb = keybinds["counts"]
        print(f"keybinds: {kb.get('PASS', 0)} passed, {kb.get('SKIP', 0)} skipped, "
              f"{kb.get('FAIL', 0)} failed"
              + (f" (FATAL: {keybinds['fatal']})" if keybinds.get("fatal") else ""))
        print(f"keybinds report: {out_dir / 'keybinds.txt'}")

    # ---------------- phase 2: plugins ---------------- #
    plugins: list[dict[str, Any]] | None = None
    if plugins_enabled and walkthrough is not None:
        print("\n--- PHASE 2: plugins (open + close each, screenshot each) ---")
        wargv = [
            "--auto", "--wait", str(args.wait),
            "--no-record" if not args.record else "--record",
        ]
        if args.only:
            wargv += ["--only", args.only]
        if args.dangerous:
            wargv += ["--dangerous"]
        if args.script_monitor:
            wargv += ["--script-monitor", args.script_monitor]
        if args.plugin_monitor:
            wargv += ["--plugin-monitor", args.plugin_monitor]

        try:
            plugins = run_plugins(walkthrough, wargv, plugins_dir)
        except Exception as e:
            print(f"FATAL: plugin phase failed: {e}", file=sys.stderr)
            # produce an empty-but-valid combined report before bailing out
            wd.update(restore_watchdog(wd["before"], out_dir))
            write_combined(out_dir, keybinds, [], plugins_dir, created,
                           keybinds_enabled, plugins_enabled, wd)
            return 2

        # plugin monitor chosen by the walkthrough, for screenshot retries
        plugin_monitor = None
        try:
            monitors = walkthrough.hypr_monitors()
            script_m, plugin_monitor = walkthrough.choose_monitors(
                args.script_monitor, args.plugin_monitor, monitors)
        except Exception:
            pass
        if args.plugin_monitor:
            plugin_monitor = args.plugin_monitor

        # screenshot guarantee: retake once for anything missing, then verify
        registry_index: dict[str, int] = {}
        info: dict[str, Any] = {}
        try:
            registry, info = walkthrough.load_plugin_data()
            registry_index = {p.get("id", ""): i for i, p in enumerate(registry, 1)}
        except Exception:
            pass

        # restore the walkthrough's own log first; it reads screenshots from disk
        retake_missing_screenshots(walkthrough, plugins, plugins_dir, plugin_monitor,
                                   args.wait, args.dangerous, registry_index, info)
        finalize_screenshots(plugins, plugins_dir)
        rewrite_plugin_log(walkthrough, plugins_dir, plugins)

        pc = {s: sum(1 for r in plugins if r.get("status") == s)
              for s in ("PASS", "FAIL", "ERROR", "SKIP")}
        missing = sum(1 for r in plugins
                      if r.get("status") != "SKIP" and not r.get("has_screenshot"))
        print(f"plugins: {pc['PASS']} passed, {pc['FAIL'] + pc['ERROR']} failed, "
              f"{pc['SKIP']} skipped; screenshots: "
              f"{sum(r.get('screenshot_count', 0) for r in plugins)} saved, {missing} missing")
        print(f"plugins report: {plugins_dir / 'results.md'}")

    # ---------------- watchdog restore + combined report ---------------- #
    wd.update(restore_watchdog(wd["before"], out_dir))
    combined = write_combined(out_dir, keybinds, plugins, plugins_dir, created,
                              keybinds_enabled, plugins_enabled, wd)

    print("\n" + "=" * 72)
    print(f"RESULT: {'PASS' if combined['ok'] else 'FAIL'}")
    print(f"Report: {out_dir / 'results.md'}")
    print(f"JSON:   {out_dir / 'results.json'}")
    print(f"Screenshots: {out_dir / 'plugins'}")
    print("=" * 72)
    return 0 if combined["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
