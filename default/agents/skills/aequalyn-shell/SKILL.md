---
name: aequalyn-shell
description: Develop the Aequalyn QuickShell desktop under shell/ (QML, Hyprland integration, plugins, bar, docks, settings).
---

# Aequalyn Shell Development

Read this before editing the QuickShell desktop under `shell/` (or the installed copy at `/usr/share/aequalyn/shell/` and `~/.config/quickshell/`).

The QuickShell desktop runs as a single long-running process. Hyprland autostart launches it via `qs`; do not start additional standalone Quickshell instances for individual components. Run `aequalyn-restart-shell` (or restart `qs`) after editing QML.

## Layout

- First-party plugins live under `shell/plugins/` (bar widgets, docks, atelier, settings, app launcher).
- Bar widgets: `shell/plugins/bar/widgets/`. The bar is per-screen (`Variants` over `Quickshell.screens`); widgets receive `bar` (the shared root Scope) and, where needed, `screen`.
- Settings pages: `shell/settings/center/pages/`. Persistent state: `~/.config/aequalyn/settings.json` via `AequalynSettings`.
- Web apps: managed by `aequalyn-webapp` (in the `aequalyn` repo, `bin/aequalyn-webapp`); state in `~/.config/aequalyn/webapps.json`.

## Conventions

- Use `root:/` imports for cross-directory QML (e.g. `import "root:/settings"`, `import "root:/plugins/docks"`).
- Bar widgets must declare `required property var bar`; pass `screen` explicitly when per-monitor behavior is needed (see `BarSlot.qml`).
- Keep plugin entry points as `Item`s, not `ShellRoot`.
- Restart the shell after changes: `pkill -x qs && qs &`.

## Hyprland integration

- Config is Lua (`config/hypr/hyprland.lua` in the `aequalyn` repo, installed to `~/.config/hypr/hyprland.lua`).
- Workspace numbers are per-monitor via `r~N` selectors so empty numbered workspaces can be opened; the bar filters workspaces by monitor name.
- Reload with `hyprctl reload`.

## Testing

- Quickshell config load check: `timeout 8 quickshell -p /home/mihai/Projects/aequalyn-shell/shell.qml`.
- Dry-run webapp commands: `AEQUALYN_WEBAPP_DRY_RUN=1 aequalyn-webapp ...`.

## References

- Aequalyn: https://github.com/Aequalyn/aequalyn
- Aequalyn shell: https://github.com/Aequalyn/aequalyn-shell
- Aequalyn installer: https://github.com/Aequalyn/aequalyn-installer
- Aequalyn packages: https://github.com/Aequalyn/aequalyn-pkgs
- Hyprland wiki: https://wiki.hypr.land
- Hyprland Lua API: https://alejandrominaya.github.io/hyprland-lua-docs/
- Qt QML reference: https://doc.qt.io/qt-6/qmlreference.html
- Quickshell docs: https://quickshell.org/
