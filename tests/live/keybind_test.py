#!/usr/bin/env python3
"""
Hyprland keybind test.

This tests the keybinds that are *actually registered in the running Hyprland*
(not just the text in the config files). For every bind it resolves the real
effect -- the exec command, the Hyprland dispatcher and its arguments, or, for
Lua callbacks, the dispatchers the callback issues -- then compares that with
the expected behaviour manifest below.

It is read-only: Lua callbacks are executed once with hl.dispatch, hl.exec_cmd
and hl.timer stubbed out, so nothing is launched, no window is moved and no
layout is changed. Executables and `qs ipc call` targets are checked for
existence, but not invoked.

Usage:
    tests/live/keybind_test.py
    tests/live/keybind_test.py --no-smoke
    tests/live/keybind_test.py --json > /tmp/keybinds.json

Exit status: 0 = all tested binds OK, 1 = at least one failure.
"""

from __future__ import annotations

import argparse
import ast
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
from dataclasses import dataclass, field
from typing import Any

HOME = os.path.expanduser("~")
HYPR_DIR = os.path.join(HOME, ".config", "hypr")


# --------------------------------------------------------------------------- #
# small helpers                                                                #
# --------------------------------------------------------------------------- #

def run(cmd: list[str], timeout: float = 25) -> tuple[int, str]:
    try:
        p = subprocess.run(cmd, capture_output=True, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired) as e:
        return 127, str(e)
    return p.returncode, p.stdout.decode("utf-8", "replace")


def hyprctl(*args: str) -> str:
    rc, out = run(["hyprctl", *args])
    if rc != 0:
        raise RuntimeError(f"hyprctl {' '.join(args)} failed ({rc}): {out.strip()}")
    return out


def repl(code: str) -> str:
    rc, out = run(["hyprctl", "repl", code])
    if rc != 0 or out.startswith("error:"):
        raise RuntimeError(f"hyprctl repl failed ({rc}): {out.strip()}")
    return out


MOD_BITS = [
    (1, "SHIFT"), (2, "CAPS"), (4, "CTRL"), (8, "ALT"),
    (16, "MOD2"), (32, "MOD3"), (64, "SUPER"), (128, "MOD5"),
]
MOD_NAMES = {name for _, name in MOD_BITS}
KEYCODE_NAMES = {20: "minus", 21: "equal"}


def combo(*parts: str) -> str:
    """Build a canonical combo key, e.g. combo('SHIFT', 'SUPER', '1')."""
    mods = [p for p in parts if p in MOD_NAMES]
    keys = [p for p in parts if p not in MOD_NAMES]
    ordered = [name for _, name in MOD_BITS if name in mods] + keys
    return "+".join(ordered)


def normalize_live_combo(b: dict[str, Any]) -> str:
    mods = [name for bit, name in MOD_BITS if int(b["modmask"]) & bit]
    key = b.get("key") or ""
    if not key and b.get("keycode"):
        key = KEYCODE_NAMES.get(int(b["keycode"]), f"code:{b['keycode']}")
    if len(key) == 1 and key.isalpha():
        key = key.upper()
    parts = mods + ([key] if key else [])
    name = "+".join(parts)
    if b.get("release"):
        name += " (release)"
    if b.get("submap"):
        name = f"{b['submap']}:{name}"
    if b.get("mouse"):
        name = "MOUSE:" + name
    return name


def unquote(value: str) -> str:
    if len(value) >= 2 and value[0] == '"' and value[-1] == '"':
        try:
            return str(ast.literal_eval(value))
        except (SyntaxError, ValueError):
            return value[1:-1]
    return value


# --------------------------------------------------------------------------- #
# introspection of the running compositor                                      #
# --------------------------------------------------------------------------- #

LUA_SCALAR = r'''
local function val(v, depth)
  local t = type(v)
  if t == "string" then return string.format("%q", v) end
  if t == "number" or t == "boolean" or t == "nil" then return tostring(v) end
  if t == "table" and depth < 2 then
    local parts, n = {}, 0
    for k, x in pairs(v) do
      n = n + 1
      if n > 12 then break end
      local kt, xt = type(k), type(x)
      if (kt == "string" or kt == "number") and
         (xt == "string" or xt == "number" or xt == "boolean") then
        parts[#parts + 1] = tostring(k) .. "=" .. val(x, depth + 1)
      end
    end
    table.sort(parts)
    return "{" .. table.concat(parts, ",") .. "}"
  end
  return t
end
'''


def dump_upvalues(refs: list[int]) -> dict[int, list[str]]:
    """Read the captured arguments of dispatcher closures in Hyprland's Lua registry."""
    template = LUA_SCALAR + r'''
local r = debug.getregistry()
local out = {}
for _, id in ipairs(IDS) do
  local f = r[id]
  local parts = {}
  if type(f) == "function" then
    for i = 1, 8 do
      local n, v = debug.getupvalue(f, i)
      if not n then break end
      parts[#parts + 1] = val(v, 0)
    end
  end
  out[#out + 1] = id .. "\t" .. table.concat(parts, "|")
end
return table.concat(out, "\n")
'''
    result: dict[int, list[str]] = {}
    for start in range(0, len(refs), 25):
        chunk = refs[start:start + 25]
        code = template.replace("IDS", "{" + ",".join(map(str, chunk)) + "}")
        for line in repl(code).splitlines():
            if "\t" not in line:
                continue
            ref, _, rest = line.partition("\t")
            result[int(ref)] = rest.split("|") if rest else []
    return result


LUA_SANDBOX = LUA_SCALAR + r'''
local ref = REF
local f = debug.getregistry()[ref]
if type(f) ~= "function" then return ref .. "\tERR\tnot a Lua function" end

local names = setmetatable({}, {__mode = "k"})
local saved = {}
local function wrap(tbl, path)
  for n, v in pairs(tbl) do
    local p = path .. "." .. tostring(n)
    saved[p] = {tbl, n, v}
    if type(v) == "function" then
      tbl[n] = function(...)
        local d = v(...)
        names[d] = {p, {...}}
        return d
      end
    elseif type(v) == "table" then
      wrap(v, p)
    end
  end
end

local calls = {}
local function describe(d)
  local info = names[d]
  if not info then return tostring(d) end
  local name = info[1]:gsub("^dsp%.", "")
  local args = {}
  for i, a in ipairs(info[2]) do args[#args + 1] = val(a, 0) end
  return name .. "(" .. table.concat(args, ",") .. ")"
end

local ok, err = pcall(function()
  wrap(hl.dsp, "dsp")
  hl.dispatch = function(d, ...) calls[#calls + 1] = "dispatch:" .. describe(d) end
  hl.exec_cmd  = function(cmd, ...) calls[#calls + 1] = "exec:" .. tostring(cmd) end
  hl.timer     = function(...) calls[#calls + 1] = "timer" end

  local fok, ferr = pcall(f)
  if not fok then
    calls[#calls + 1] = "ERROR:" .. tostring(ferr)
  end
end)

-- Always restore the real dispatchers, even if the callback threw.
hl.dispatch, hl.exec_cmd, hl.timer = realDispatch, realExec, realTimer
for _, entry in pairs(saved) do entry[1][entry[2]] = entry[3] end

if not ok then return ref .. "\tERR\t" .. tostring(err) end
return ref .. "\tOK\t" .. table.concat(calls, ";")
'''


def sandbox_functions(refs: list[int]) -> dict[int, tuple[bool, str]]:
    """Run each Lua keybind callback with all side-effecting APIs stubbed."""
    prefix = (
        "local realDispatch, realExec, realTimer = hl.dispatch, hl.exec_cmd, hl.timer\n"
    )
    result: dict[int, tuple[bool, str]] = {}
    for start in range(0, len(refs), 8):
        chunk = refs[start:start + 8]
        for ref in chunk:
            code = prefix + LUA_SANDBOX.replace("REF", str(ref))
            out = repl(code).strip()
            _, _, rest = out.partition("\t")
            status, _, effects = rest.partition("\t")
            result[ref] = (status == "OK", effects)
    return result


def normalize_effect(text: str) -> str:
    text = re.sub(r"address:0x[0-9a-fA-F]+", "address:<ADDR>", text)
    return text


def resolve_effects(binds: list[dict[str, Any]]) -> tuple[dict[str, list[str]], dict[str, int]]:
    refs = sorted({int(b["arg"]) for b in binds if str(b["arg"]).isdigit()})
    upvals = dump_upvalues(refs)
    lua_refs = sorted(
        {int(b["arg"]) for b in binds
         if not str(b["dispatcher"]).startswith("HL.Dispatcher(")}
    )
    sandbox = sandbox_functions(lua_refs)

    observed: dict[str, list[str]] = {}
    counts: dict[str, int] = {}
    for b in binds:
        name = normalize_live_combo(b)
        ref = int(b["arg"])
        dispatcher = str(b["dispatcher"])
        if dispatcher.startswith("HL.Dispatcher("):
            dname = dispatcher[len("HL.Dispatcher("):-1]
            args = upvals.get(ref, [])
            while args and args[-1] == "nil":
                args.pop()
            if dname == "exec_cmd" and args:
                effect = "exec:" + unquote(args[0])
            else:
                effect = f"dispatch:{dname}({','.join(args)})"
            observed[name] = [normalize_effect(effect)]
        else:
            ok, effects = sandbox.get(ref, (False, "ERROR:sandbox failed"))
            observed[name] = [normalize_effect(e) for e in effects.split(";") if e] or (
                ["ERROR:" + effects] if not ok else []
            )
        counts[name] = counts.get(name, 0) + 1
    return observed, counts


# --------------------------------------------------------------------------- #
# expected behaviour manifest                                                  #
# --------------------------------------------------------------------------- #

@dataclass
class Expect:
    combo: str
    label: str
    pattern: str
    flags: dict[str, Any] = field(default_factory=dict)
    smoke: bool = True


EXPECTED: dict[str, Expect] = {}
CONFLICTS: list[tuple[str, str]] = []


def E(combo_name: str, label: str, pattern: str, **kw: Any) -> None:
    if combo_name in EXPECTED:
        raise RuntimeError(f"duplicate expectation for {combo_name}")
    EXPECTED[combo_name] = Expect(combo_name, label, pattern,
                                  flags=kw.pop("flags", {}), **kw)


def exact_exec(command: str, label: str, key: str, **kw: Any) -> None:
    E(key, label, "^exec:" + re.escape(command) + "$", **kw)


def xdg_default(mime: str, fallback: str) -> str:
    rc, out = run(["xdg-mime", "query", "default", mime])
    ident = out.strip().splitlines()[0].strip() if rc == 0 and out.strip() else ""
    if not ident:
        return fallback
    return "gtk-launch " + re.sub(r"\.desktop$", "", ident)


def terminal_default(fallback: str = "kitty") -> str:
    path = os.path.join(HOME, ".config", "xdg-terminals.list")
    try:
        with open(path, encoding="utf-8") as f:
            ident = f.readline().strip()
    except OSError:
        ident = ""
    if not ident:
        return fallback
    return "gtk-launch " + re.sub(r"\.desktop$", "", ident)


def build_expectations() -> None:
    term = terminal_default()
    files = xdg_default("inode/directory", "nautilus")
    browser = xdg_default("text/html", "chromium")

    # Universal clipboard (~/.config/hypr/aequalyn/clipboard.lua)
    E(combo("SUPER", "A"), "Select all (Ctrl+A)",
      r'^dispatch:send_key_state\(\{key="A",mods="CTRL",state="down"\}\);timer$')
    E(combo("SUPER", "C"), "Copy (Ctrl+C, Ctrl+Shift+C in terminals)",
      r'^dispatch:send_key_state\(\{key="C",mods="CTRL( SHIFT)?",state="down"\}\);timer$')
    E(combo("SUPER", "V"), "Paste (Ctrl+V, Ctrl+Shift+V in terminals)",
      r'^dispatch:send_key_state\(\{key="V",mods="CTRL( SHIFT)?",state="down"\}\);timer$')
    E(combo("SUPER", "X"), "Cut (Ctrl+X)",
      r'^dispatch:send_key_state\(\{key="X",mods="CTRL",state="down"\}\);timer$')
    exact_exec("qs ipc call clipscape toggle", "Clipboard history",
               combo("CTRL", "SUPER", "V"))

    # Applications and Aequalyn shell (keybinds.lua)
    exact_exec(term, "Open terminal", combo("SUPER", "RETURN"))
    exact_exec(files, "Open file manager", combo("SUPER", "E"))
    exact_exec("qs ipc call -- aequalyn-fm open " + HOME, "Open Aequalyn FM",
               combo("ALT", "SUPER", "F"))
    exact_exec(browser, "Open browser", combo("SUPER", "B"))
    exact_exec("qs ipc call programs toggle", "Programs menu", combo("SUPER", "SPACE"))
    exact_exec("qs ipc call launcher toggle", "App launcher", combo("SUPER", "D"))
    exact_exec("qs ipc call snap toggle", "Snap layouts", combo("SUPER", "G"))
    exact_exec("qs ipc call defaults toggle", "Default apps", combo("ALT", "SUPER", "A"))
    exact_exec("qs ipc call store toggle", "Store", combo("ALT", "SUPER", "S"))
    exact_exec("qs ipc call aequalyn settings", "Settings", combo("SUPER", "COMMA"))
    exact_exec("qs ipc call fonts toggle", "Fonts", combo("CTRL", "SUPER", "PERIOD"))
    for key, target in [("B", "bar"), ("D", "dock"), ("K", "lock"),
                        ("G", "login"), ("C", "cursor"), ("W", "showcase"),
                        ("M", "all")]:
        exact_exec(f"qs ipc call quickLooks {target}", f"Quick look: {target}",
                   combo("CTRL", "SUPER", key))

    # Layouts
    exact_exec("aequalyn-layout next", "Next layout", combo("SUPER", "L"))
    exact_exec("aequalyn-layout prev", "Previous layout", combo("SHIFT", "SUPER", "L"))
    exact_exec("qs ipc call aequalyn page arrange", "Arrange page",
               combo("ALT", "SUPER", "L"))
    E(combo("CTRL", "SUPER", "left"), "Swap with previous layout slot",
      r'^dispatch:layout\("swapprev"\)$')
    E(combo("CTRL", "SUPER", "right"), "Swap with next layout slot",
      r'^dispatch:layout\("swapnext"\)$')

    # Look, wallpaper, monitors, system
    exact_exec("qs ipc call atelier toggle themes", "Theme picker", combo("SUPER", "T"))
    exact_exec("qs ipc call atelier toggle wallpapers", "Wallpaper picker",
               combo("SUPER", "W"))
    exact_exec("qs ipc call aequalyn page rotation", "Rotation page",
               combo("SHIFT", "SUPER", "W"))
    exact_exec("qs ipc call atelier toggle themes", "Theme picker (alternate)",
               combo("SHIFT", "CTRL", "SUPER", "SPACE"))
    exact_exec("aequalyn-wallpaper next", "Next wallpaper",
               combo("CTRL", "SUPER", "SPACE"))
    exact_exec("qs ipc call monitors toggle", "Monitor settings", combo("SUPER", "O"))
    exact_exec("qs ipc call monitors refresh", "Refresh monitors",
               combo("SHIFT", "SUPER", "O"))
    exact_exec("qs ipc call idle toggle", "Idle settings", combo("SHIFT", "SUPER", "C"))
    exact_exec("aequalyn-lock lock", "Lock screen", combo("SHIFT", "CTRL", "SUPER", "L"),
               flags={"description": "Lock screen"})
    exact_exec("qs ipc call installMenu toggle", "Install chooser", combo("SUPER", "I"))
    exact_exec("qs ipc call removeMenu toggle", "Remove chooser", combo("SUPER", "R"))
    exact_exec("qs ipc call notifications dismiss_all", "Dismiss notifications",
               combo("SUPER", "N"))
    exact_exec("qs ipc call notifications dnd_toggle", "Do not disturb",
               combo("SHIFT", "SUPER", "N"))
    exact_exec("qs ipc call notifications history", "Notification history",
               combo("CTRL", "SUPER", "N"))
    exact_exec("aequalyn-record toggle", "Record screen", combo("SHIFT", "SUPER", "R"))

    # Window operations
    E(combo("SUPER", "Q"), "Close window", r'^dispatch:close\(\)$')
    E(combo("SHIFT", "SUPER", "V"), "Toggle floating", r'^dispatch:float\(0\.0\)$')
    E(combo("SUPER", "P"), "Toggle pseudo-tile", r'^dispatch:pseudo\(0\.0\)$')
    E(combo("SUPER", "F"), "Toggle fullscreen", r'^dispatch:fullscreen\(2\.0,true\)$')
    E(combo("SUPER", "J"), "Toggle split", r'^dispatch:layout\("togglesplit"\)$')
    exact_exec("qs ipc call power toggle", "Power menu", combo("SHIFT", "SUPER", "M"))
    E(combo("SUPER", "M"), "Minimize / restore focused window",
      r'^(?:dispatch:window\.move\(\{window="address:<ADDR>"\}\);)?timer$',
      flags={"description": "Minimize / restore the focused window"}, smoke=False)

    # Built-in shell plugins (the IPC target only exists while the plugin is on)
    plugin_binds = [
        (combo("SUPER", "SLASH"), "Key hints", "keyHints toggle"),
        (combo("SHIFT", "SUPER", "SPACE"), "Command palette", "palette toggle"),
        (combo("ALT", "SUPER", "C"), "Calculator", "calculator toggle"),
        (combo("SUPER", "PERIOD"), "Emoji picker", "emoji toggle"),
        (combo("SHIFT", "SUPER", "P"), "Screen colour picker", "colorPicker pick"),
        (combo("ALT", "SUPER", "N"), "Quick notes", "notes toggle"),
        (combo("SHIFT", "SUPER", "ESCAPE"), "System monitor", "sysmon toggle"),
        (combo("ALT", "SUPER", "X"), "Text from screen", "screenText capture"),
        (combo("ALT", "SUPER", "T"), "Timer", "timer toggle"),
    ]
    for key, label, call in plugin_binds:
        exact_exec("qs ipc call " + call, label, key)

    # Workspaces: N is the Nth workspace on the current monitor
    for i in range(1, 11):
        key = str(i % 10)
        E(combo("SUPER", key), f"Focus workspace {i} on this monitor",
          '^dispatch:focus\\("r~' + str(i) + '"\\)$')
        E(combo("SHIFT", "SUPER", key), f"Move window to workspace {i} on this monitor",
          '^dispatch:move\\("r~' + str(i) + '",false\\)$')
    E(combo("SUPER", "S"), "Toggle magic workspace",
      r'^dispatch:toggle_special\("magic"\)$')
    E(combo("SHIFT", "SUPER", "S"), "Move window to magic workspace",
      r'^dispatch:move\("special:magic",false\)$')
    E(combo("SUPER", "mouse_down"), "Next workspace", r'^dispatch:focus\("e\+1"\)$')
    E(combo("SUPER", "mouse_up"), "Previous workspace", r'^dispatch:focus\("e-1"\)$')

    # Mouse window manipulation
    E("MOUSE:" + combo("SUPER", "mouse:272"), "Drag window", r'^dispatch:drag\(\)$',
      flags={"mouse": True})
    E("MOUSE:" + combo("SUPER", "mouse:273"), "Resize window",
      r'^dispatch:resize\(0\.0\)$', flags={"mouse": True})

    # Screenshots and recording
    exact_exec("aequalyn-screenshot region-clip", "Region screenshot, saved + copied",
               "PRINT")
    exact_exec("aequalyn-screenshot full-clip", "Full screenshot, saved + copied",
               combo("SHIFT", "PRINT"))
    exact_exec("aequalyn-screenshot region-file", "Region screenshot, saved only",
               combo("SUPER", "PRINT"))
    exact_exec("aequalyn-screenshot region-clip", "Region screenshot (Ctrl+S)",
               combo("CTRL", "SUPER", "S"))
    exact_exec("aequalyn-screenshot full-clip", "Full screenshot (Ctrl+Shift+S)",
               combo("SHIFT", "CTRL", "SUPER", "S"))
    exact_exec("aequalyn-record toggle", "Record screen (Ctrl+R)",
               combo("CTRL", "SUPER", "R"))
    exact_exec("aequalyn-screenshot region-clip", "Selective screenshot key",
               "XF86SelectiveScreenshot")

    # Media and brightness: locked and repeating by design
    media = [
        ("XF86AudioRaiseVolume", "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+", "Volume up"),
        ("XF86AudioLowerVolume", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-", "Volume down"),
        ("XF86AudioMute", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle", "Mute"),
        ("XF86AudioMicMute", "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle", "Mic mute"),
        ("XF86MonBrightnessUp", "brightnessctl -e4 -n2 set 5%+", "Brightness up"),
        ("XF86MonBrightnessDown", "brightnessctl -e4 -n2 set 5%-", "Brightness down"),
        ("XF86AudioPlay", "playerctl play-pause", "Play/pause"),
        ("XF86AudioPause", "playerctl play-pause", "Pause"),
        ("XF86AudioNext", "playerctl next", "Next track"),
        ("XF86AudioPrev", "playerctl previous", "Previous track"),
    ]
    for key, command, label in media:
        exact_exec(command, label, key,
                   flags={"repeat": True, "locked": True})

    # Optional floating titlebar loader
    exact_exec("aequalyn-hyprbars load --again", "Load floating titlebars",
               combo("SHIFT", "SUPER", "T"),
               flags={"description": "Load floating titlebar"})

    # Layout-aware focus / swap / promote / resize (aequalyn/keys.lua)
    for direction in ("left", "right", "up", "down"):
        E(combo("SUPER", direction), f"Focus window {direction}",
          r'^dispatch:focus\((\{direction="' + direction +
          r'"\}|\{window="address:<ADDR>"\})\)$')
        E(combo("SHIFT", "SUPER", direction), f"Swap window {direction}",
          r'^dispatch:(window\.swap\(\{direction="' + direction +
          r'"\}\)|layout\("swap \d+"\))$')
    E(combo("SUPER", "Z"), "Promote focused window",
      r'^dispatch:layout\("promote"\)$')
    resize_keys = [
        (("SUPER", "minus"), "SUPER + -", -100, "0.0100"),
        (("SUPER", "equal"), "SUPER + =", 100, "0.0100"),
        (("ALT", "SUPER", "minus"), "Alt + SUPER + -", -25, "0.0025"),
        (("ALT", "SUPER", "equal"), "Alt + SUPER + =", 25, "0.0025"),
        (("CTRL", "SUPER", "minus"), "Ctrl + SUPER + -", -300, "0.0400"),
        (("CTRL", "SUPER", "equal"), "Ctrl + SUPER + =", 300, "0.0400"),
    ]
    for parts, label, px, aq_step in resize_keys:
        x = str(px)
        E(combo(*parts), f"Resize main pane ({label})",
          r'^dispatch:(window\.resize\(\{relative=true,x=' + re.escape(x) +
          r',y=0\}\)|layout\("resize -?' + re.escape(aq_step) +
          r'"\))$')

    E(combo("CTRL", "SUPER", "L"), "Open layout picker",
      r'^dispatch:submap\("aq-layout-picker"\)$')
    for key, layout in [
        ("1", "dwindle"), ("2", "scrolling"), ("3", "master"),
        ("4", "portrait"), ("5", "landscape"), ("6", "centerpiece"),
        ("7", "diptych_left"), ("8", "diptych_right"), ("9", "mosaic"),
        ("F", "floating"),
    ]:
        E(f"aq-layout-picker:{key}", f"Set {layout} layout",
          r'^dispatch:submap\("reset"\);dispatch:exec_cmd\("aequalyn-layout set ' +
          re.escape(layout) + r'"\)$')
    E("aq-layout-picker:0", "Open more layouts",
      r'^dispatch:submap\("aq-layout-picker-more"\)$')
    for key, layout in [
        ("1", "strip"), ("2", "column"), ("3", "spiral"),
        ("4", "gallery_right"), ("5", "gallery_bottom"), ("6", "gallery_left"),
        ("7", "gallery_top"), ("8", "spread"), ("9", "diptych_top"),
        ("0", "diptych_bottom"), ("minus", "triptych"), ("equal", "bento"),
    ]:
        E(f"aq-layout-picker-more:{key}", f"Set {layout} layout",
          r'^dispatch:submap\("reset"\);dispatch:exec_cmd\("aequalyn-layout set ' +
          re.escape(layout) + r'"\)$')
    for submap in ("aq-layout-picker", "aq-layout-picker-more"):
        E(f"{submap}:Escape", f"Cancel {submap}",
          r'^dispatch:submap\("reset"\)$')

    # Click on a small window in a Focus layout promotes it
    for button in ("272", "273", "274"):
        E(f"mouse:{button}", "Promote clicked Focus-layout window",
          r'^timer$', flags={"non_consuming": True,
                             "submap_universal": "true"}, smoke=False)

    # Altscape window switcher (managed in hyprland.lua)
    E(combo("ALT", "TAB"), "Next window (Altscape)",
      r'^dispatch:global\("io\.github\.qempexe\.altscape:next"\)$',
      flags={"description": "Window switcher: next window"})
    E(combo("SHIFT", "ALT", "TAB"), "Previous window (Altscape)",
      r'^dispatch:global\("io\.github\.qempexe\.altscape:prev"\)$',
      flags={"description": "Window switcher: previous window"})
    for side in ("L", "R"):
        E(combo("ALT", f"ALT_{side}") + " (release)", "Switch on Alt release",
          r'^dispatch:global\("io\.github\.qempexe\.altscape:release"\)$',
          flags={"release": True, "non_consuming": True,
                 "description": "Window switcher: switch on release"})
    exact_exec("qs ipc call altscape settings", "Window switcher settings",
               combo("SHIFT", "ALT", "SUPER", "S"),
               flags={"description": "Window switcher settings"})

    # Generated web app binds (~/.config/aequalyn/webapps.json)
    path = os.path.join(HOME, ".config", "aequalyn", "webapps.json")
    try:
        with open(path, encoding="utf-8") as f:
            apps = json.load(f).get("apps", [])
    except (OSError, ValueError):
        apps = []
    for app in apps:
        slug, key = app.get("slug"), str(app.get("key", "")).upper()
        if not slug or not key:
            continue
        web_combo = combo("SHIFT", "SUPER", key)
        if web_combo in EXPECTED:
            CONFLICTS.append((web_combo,
                              f"web app {app.get('name', slug)} ({slug}) is "
                              f"shadowed by {EXPECTED[web_combo].label}"))
            continue
        exact_exec(f"aequalyn-webapp launch {slug}",
                   f"Launch web app: {app.get('name', slug)}",
                   web_combo)


# --------------------------------------------------------------------------- #
# smoke checks: does the command point at something that exists?               #
# --------------------------------------------------------------------------- #

OPTIONAL_IPC_TARGETS = {
    "keyHints", "palette", "calculator", "emoji", "colorPicker", "notes",
    "sysmon", "screenText", "timer", "snap", "showcase", "dock",
}


def ipc_targets() -> dict[str, set[str]]:
    rc, out = run(["qs", "ipc", "show"])
    targets: dict[str, set[str]] = {}
    current = None
    for line in out.splitlines() if rc == 0 else []:
        m = re.match(r"^target\s+(\S+)", line)
        if m:
            current = m.group(1)
            targets[current] = set()
            continue
        m = re.match(r"^\s+function\s+(\w+)", line)
        if m and current:
            targets[current].add(m.group(1))
    return targets


def desktop_file_exists(ident: str) -> bool:
    dirs = [os.path.join(HOME, ".local", "share")]
    dirs += [p for p in os.getenv("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":") if p]
    return any(os.path.isfile(os.path.join(d, "applications", ident + ".desktop"))
               for d in dirs)


def smoke_check(command: str, targets: dict[str, set[str]], webapp_slugs: set[str]) -> tuple[str, str]:
    """Return (PASS|FAIL|SKIP, detail)."""
    try:
        tokens = shlex.split(command)
    except ValueError as e:
        return "FAIL", f"cannot parse command: {e}"
    if not tokens:
        return "FAIL", "empty command"

    if tokens[:2] == ["qs", "ipc"] and "call" in tokens:
        i = tokens.index("call") + 1
        if i < len(tokens) and tokens[i] == "--":
            i += 1
        if i + 1 >= len(tokens):
            return "FAIL", "incomplete qs ipc call"
        target, func = tokens[i], tokens[i + 1]
        if target not in targets:
            if target in OPTIONAL_IPC_TARGETS:
                return "SKIP", f"IPC target '{target}' is not loaded (plugin off?)"
            return "FAIL", f"IPC target '{target}' is not registered"
        if func not in targets[target]:
            return "FAIL", f"IPC function '{target}.{func}' does not exist"
        return "PASS", f"IPC {target}.{func} available"

    if tokens[0] == "gtk-launch":
        if len(tokens) < 2:
            return "FAIL", "gtk-launch without an app id"
        if desktop_file_exists(tokens[1]):
            return "PASS", f"desktop file {tokens[1]}.desktop found"
        return "FAIL", f"no desktop file for {tokens[1]}"

    if not shutil.which(tokens[0]):
        return "FAIL", f"{tokens[0]} is not in PATH"
    if tokens[:2] == ["aequalyn-webapp", "launch"]:
        if len(tokens) < 3:
            return "FAIL", "webapp launch without a slug"
        if tokens[2] not in webapp_slugs:
            return "FAIL", f"web app slug '{tokens[2]}' is not in webapps.json"
        return "PASS", f"web app '{tokens[2]}' exists"
    return "PASS", f"{tokens[0]} found in PATH"


# --------------------------------------------------------------------------- #
# main                                                                         #
# --------------------------------------------------------------------------- #

def main() -> int:
    ap = argparse.ArgumentParser(description="Test every registered Hyprland keybind")
    ap.add_argument("--no-smoke", action="store_true",
                    help="skip executable / IPC target existence checks")
    ap.add_argument("--json", action="store_true", help="emit JSON instead of text")
    args = ap.parse_args()

    results: list[dict[str, Any]] = []

    def add(combo_name: str, status: str, label: str, detail: str = "") -> None:
        results.append({"key": combo_name, "status": status,
                        "label": label, "detail": detail})

    try:
        if "Hyprland" not in hyprctl("version"):
            raise RuntimeError("Hyprland does not appear to be running")
        raw_binds = hyprctl("binds", "-j")
        binds = json.loads(raw_binds)
    except (RuntimeError, ValueError) as e:
        print(f"FATAL: {e}", file=sys.stderr)
        return 2

    # Config parse errors are a failure in their own right.
    try:
        errors = json.loads(hyprctl("configerrors", "-j"))
    except (RuntimeError, ValueError):
        errors = []
    errors = [str(e) for e in errors if str(e).strip()]
    if errors:
        add("<config>", "FAIL", "Hyprland config errors", "; ".join(errors))

    build_expectations()
    observed, bind_counts = resolve_effects(binds)

    for combo_name, detail in CONFLICTS:
        add(combo_name, "FAIL", "Shadowed keybind", detail)

    webapp_slugs: set[str] = set()
    try:
        with open(os.path.join(HOME, ".config", "aequalyn", "webapps.json"),
                  encoding="utf-8") as f:
            webapp_slugs = {a.get("slug") for a in json.load(f).get("apps", [])}
    except (OSError, ValueError):
        pass
    targets = {} if args.no_smoke else ipc_targets()

    for exp in EXPECTED.values():
        if exp.combo not in observed:
            add(exp.combo, "FAIL", exp.label, "keybind is not registered in Hyprland")
            continue
        effects = observed[exp.combo]
        joined = ";".join(effects)
        status = "PASS" if re.search(exp.pattern, joined) else "FAIL"
        detail = joined
        if status == "FAIL":
            detail = f"expected /{exp.pattern}/ but got {joined!r}"
        else:
            matching = [b for b in binds if normalize_live_combo(b) == exp.combo]
            actual = matching[-1] if matching else {}
            for flag, value in exp.flags.items():
                if actual.get(flag) != value:
                    status, detail = "FAIL", f"flag {flag}={actual.get(flag)!r}, expected {value!r}"
                    break
        if status == "PASS" and exp.smoke and not args.no_smoke and joined.startswith("exec:"):
            sstatus, sdetail = smoke_check(joined[5:], targets, webapp_slugs)
            if sstatus != "PASS":
                status = sstatus
                detail = sdetail
        add(exp.combo, status, exp.label, detail)

    conflicted = {k for k, _ in CONFLICTS}
    for key, count in sorted(bind_counts.items()):
        if count > 1 and key not in conflicted:
            add(key, "FAIL", "Duplicate keybind",
                f"{count} binds registered for the same combo; the last one wins")

    expected_keys = set(EXPECTED)
    for key in sorted(set(observed) - expected_keys):
        add(key, "FAIL", "Unexpected keybind",
            f"registered but not covered by the test: {';'.join(observed[key])}")

    counts = {s: sum(1 for r in results if r["status"] == s)
              for s in ("PASS", "FAIL", "SKIP")}

    if args.json:
        print(json.dumps({"counts": counts, "results": results}, indent=2))
    else:
        width = max((len(r["key"]) for r in results), default=10)
        print(f"Hyprland keybind test — {len(binds)} live binds, "
              f"{len(EXPECTED)} expectations\n")
        for r in results:
            print(f"[{r['status']:4}] {r['key']:<{width}}  {r['label']}")
            if r["status"] != "PASS" or r["detail"]:
                print(f"         {'':<{width}}  {r['detail']}")
        print(f"\nSummary: {counts['PASS']} passed, {counts['SKIP']} skipped, "
              f"{counts['FAIL']} failed")
    return 1 if counts["FAIL"] else 0


if __name__ == "__main__":
    sys.exit(main())
