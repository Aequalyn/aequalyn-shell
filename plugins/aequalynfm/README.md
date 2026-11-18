# Aequalyn FM

Aequalyn FM — rebuilt as an Aequalyn shell plugin. It runs in
the existing shell process (no second Quickshell), uses default system and
Material icons, and follows Aequalyn's live theme palette.

## What is in here

- `*.qml` — the file-manager windows, tabs, sidebar, preview pane, path bar,
  dialogs and menus.
- `compat/` — the shims: an Aequalyn-backed `Theme` singleton, the stock
  Material symbol set, and the small UI primitives the ported QML expects.
  File and app icons come from the system icon theme via `Quickshell.iconPath`.
- `daemon/` — `fmd.py`, the JSON-lines file daemon (also the
  `org.freedesktop.impl.portal.FileChooser` backend), and its shared Gio
  helpers from the shared gio module.
- `bin/aequalyn-fm` — the launcher/installer.

## Install

```sh
bin/aequalyn-fm --install   # desktop entry: Aequalyn FM in the app launcher
bin/aequalyn-fm --default   # also open folders with it (Super+E follows the default)
bin/aequalyn-fm --portal    # also serve every app's Open/Save dialog
```

`--portal` registers `org.freedesktop.impl.portal.desktop.aequalyn` with
xdg-desktop-portal, points the Hyprland FileChooser preference at it, and asks
Qt apps to use the portal. The shell config sets `GTK_USE_PORTAL=1` and floats
dialog windows by their ` — Aequalyn FM` title suffix.

Register the plugin in `Plugins.js` and restart the shell; it can be toggled
under Settings → Plugins.

## Use

- `SUPER+E` — open Aequalyn FM (uses the XDG default, set with `--default`).
- `aequalyn-fm ~/Pictures` — open that folder; more paths open as tabs.
- `aequalyn-fm --windows` — close all file-manager windows.
- Every app's *Open*/*Save* dialog is an Aequalyn FM window when `--portal` is
  installed.

MIT, matching the sources it is derived from.
