---
name: aequalyn-shell
description: Develop the Aequalyn QuickShell desktop (QML, Hyprland integration, plugins, bar, docks, settings, themes, store, security).
---

# Aequalyn Shell — development skill

Read this before editing the QuickShell desktop under `shell/` (or the installed copy at
`/usr/share/aequalyn/shell/` and `~/.config/quickshell/`).

The QuickShell desktop runs as a single long-running process. Hyprland autostart launches
it via `qs`; do not start additional standalone Quickshell instances for individual
components. Run `aequalyn-restart-shell` (or restart `qs`) after editing QML.

## Layout

- First-party plugins live under `plugins/` (bar widgets, docks, themes-and-wallpapers picker, settings, app launcher, store, etc.).
- Bar widgets: `plugins/bar/widgets/`. The bar is per-screen (`Variants` over `Quickshell.screens`); widgets receive `bar` (the shared root Scope) and, where needed, `screen`.
- Settings pages: `settings/center/pages/`. Persistent state: `~/.config/aequalyn/settings.json` via `AequalynSettings`.
- Web apps: managed by `aequalyn-webapp` (in the `aequalyn` repo, `bin/aequalyn-webapp`); state in `~/.config/aequalyn/webapps.json`.
- Plugin registry: `Plugins.js` + metadata `PluginInfo.js`; manager `PluginManager.qml`.
- Theme provider: `theme-switcher/ThemeSwitcher.qml` exposes `ts.theme` and IPC `theme`.
- Sandbox supervisor: `tools/watchdog/aequalyn-watchdog` (Python) + `plugins/watchdog/` + `EscalationWindow.qml`.

## Conventions

- Use `root:/` imports for cross-directory QML (e.g. `import "root:/settings"`).
- Bar widgets must declare `required property var bar`; pass `screen` explicitly when per-monitor behavior is needed (see `BarSlot.qml`).
- Keep plugin entry points as `Item`s, never `ShellRoot`.
- Restart the shell after changes: `pkill -x qs && qs &`.
- Sandbox: trusted first-party plugins run in-process; Store/background plugins run under `tools/watchdog/aequalyn-watchdog`. See `SECURITY.md`.

## Hyprland integration

- Config is Lua (`config/hypr/hyprland.lua` in the `aequalyn` repo, installed to `~/.config/hypr/hyprland.lua`).
- Workspace numbers are per-monitor via `r~N` selectors. Hyprland destroys empty workspaces, which shifts positions; reserve a stable persistent id block of 10 per monitor.
- Reload with `hyprctl reload`.

## Themes and wallpapers

- Provider: `theme-switcher/ThemeSwitcher.qml` instantiates `Theme` and exposes `ts.theme` plus IPC target `theme` (`wallpaper`, `follow`, `set`, `reapply`, `reload`, `current`, `toggle`).
- `theme-switcher/Theme.qml` (Singleton): curated fallback `themes` plus folder themes from `aequalyn-themes list --json`; `wallpaperMode` (matugen) reads `~/.config/quickshell/theme-switcher/wallpaper-theme.json` via FileView; `currentFolderId`; preview palette.
- `applyTheme(t)` propagates to kitty, lock screen, terminal palette, system colour scheme, Hyprland borders (`colors.lua`), KDE (if integration), Nautilus palette, browser policy.
- Folder themes activated via `setFolderTheme(id)` → writes `~/.config/quickshell/theme.conf` (`theme:<id>` or `wallpaper`), calls `aequalyn-themes set`, applies palette, updates `~/.config/aequalyn/current/theme` symlink.
- Themes-and-wallpapers picker (`plugins/atelier/`) is the picker UI; settings page `settings/center/pages/Theme.qml` (and `Picker.qml`).

## Plugin system

- Registry: `Plugins.js` — single source of truth `{ id, label, source, sandbox?, needsRoot? }`. Built-ins + pack plugins.
- Metadata: `PluginInfo.js` — `{ icon, group (screen|key|background), keys, page, pack, settings, about }` for control-center cards.
- Manager: `PluginManager.qml` — one `Loader` per plugin; binds `theme` (and `shellTheme` for docks); handles enable/disable at runtime without restart; grace-period load-failure handling (10 s, forced retry, then turn off + notify); cross-plugin wiring (docks follow bar visibility); `IpcHandler target: "plugins"` (rescan/reload/list); sandbox detection (`isSandboxed`: `sandbox:true` or Store plugin group `background`, minus `noSandboxIds`).
- Store plugins: `settings/UserPlugins.qml` scans `~/.local/share/aequalyn/plugins/*/plugin.json`; validates id regex, entry file, group, needsRoot; refuses built-in id collisions.
- Settings: `settings/AequalynSettings.qml` stores `enabledPlugins`, `pluginsKnown` (new-plugin migration via `newPlugins`), `noSandboxPlugins`, `rootAllowed`. `togglePlugin(id,on)` updates + saves + places bar widget.
- IPC: `plugins rescan`, `plugins reload <id>`, `plugins list --json`.

## Security

- Supervisor/sandbox: `tools/watchdog/aequalyn-watchdog` (Python) runs shell + sandboxed plugins as separate QuickShell instances; RAM budgets, heartbeat, failure turn-off; refuses to run as root. Docs: `tools/watchdog/README.md`. In-shell side: `plugins/watchdog/Watchdog.qml` + `EscalationWindow.qml`.
- Sandbox set: built-ins with `sandbox:true` (`batteryGuard`, `breaks`, `diskWatch`, `nightLight`, `watchdogTest`, `rootTest`); Store plugins with group `background`; `forceSandbox`/`noSandbox` from `~/.config/aequalyn/watchdog.json`.
- Root gate: only door to root. Plugins declare `needsRoot` actions with pinned argv in manifest/`Plugins.js`; `aequalyn-watchdog exec-root <actionId>`; caller pinned via `SO_PEERCRED` + `/proc` ancestors; escalation window names plugin + exact command; password fed to `sudo -S` on a pipe (never argv/log); 2-min timeout = denial; "always allow" remembers consent only. Tripwire scans process trees for `sudo/pkexec/su/doas` (direct, shell args, env/timeout pass-throughs) and kills + counts as failure. First-party flows (browser theme, SDDM, store packages, installer) use same gate.
- Honest limits: 3 s `/proc` sampling can miss short runs; static QML check bans words but not string construction; same-user code can do anything user can. Gate = consent/audit, not hard wall.
- Risk hotspots: QML uses `Quickshell.execDetached(["sh","-c", ...])` with string interpolation in places (`CaptureQuick.shot` mode; `watchdogTest.persist` paths; theme/kitty color injection; app launcher runs desktop `Exec` via `sh -c`); Store plugins are arbitrary code; key/screen group plugins run in-process; IPC targets unauthenticated locally.
- Mitigations: atomic settings write (tmp + mv); Store id/entry validation; built-in id collision refusal; watchdog config validation (`clean_root_actions` argv limits); escalation password not in argv/log.
- See `SECURITY.md` and `aequalyn/Security.md` for inherited system-level concerns.

## IPC / commands

- IPC targets: `aequalyn`, `theme`, `wallpaper`, `atelier` (internal id for themes-and-wallpapers picker), `bar`, `dock`, `plugins`, `watchdog`, `sandbox`, plus per-plugin ids (`appLauncher`, `notifications`, etc.) and `aequalyn-fm`.
- Documented: `qs ipc call atelier toggle/open ...` (internal); `wallpaper next|prev|random|set|mode`; `theme set|follow`; `dock add|toggle|show|hide|settings`.
- `aequalyn` target (ControlCenter): `settings`, `pluginPage`, `plugin`, `openSettings`, `closeSettings`, `page`, `search`, `appearance`, `displays`, `bluetooth`, `wifi`, `hyprland`, `bar`, `dock`, `updates`, `power`, `install`, `reveal`.
- `theme` target: `wallpaper`, `follow`, `set`, `reapply`, `reload`, `current`, `toggle`.
- `plugins` target: `rescan`, `reload`, `list`.
- `watchdog` target: `ping`, `health`, `disablePlugin`, `enablePlugin`, `restartPlugin`, `setNoSandbox`, `escalationRequest`.
- `bar` target includes `popup <id>`.

## Testing

- Quickshell config load check: `timeout 8 quickshell -p /home/mihai/Projects/aequalyn-shell/shell.qml`.
- Layout tests in `aequalyn` repo (`tests/`).
- Watchdog tests: `tools/watchdog/tests/`.

## References

- Aequalyn core: https://github.com/Aequalyn/aequalyn
- Aequalyn shell: https://github.com/Aequalyn/aequalyn-shell
- Aequalyn installer: https://github.com/Aequalyn/aequalyn-installer
- Aequalyn packages: https://github.com/Aequalyn/aequalyn-pkgs
- Aequalyn store: https://github.com/Aequalyn/aequalyn-store
- Aequalyn themes: https://github.com/Aequalyn/aequalyn-themes
- Hyprland wiki: https://wiki.hypr.land
- Quickshell docs: https://quickshell.org/
- Full plugin standard: `PLUGINS.md`.
- Theme handling: `THEMES.md`.
- Security model: `SECURITY.md`.
