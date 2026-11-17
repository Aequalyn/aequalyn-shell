# Clipscape for Aequalyn

A port of [omarchy-clipscape](https://github.com/qempexe/omarchy-clipscape)
(MIT, qempexe) as a first-party Aequalyn shell plugin.

## Aequalyn-specific changes

- `qml/Service.qml` is a `ClipscapeService` singleton (see `qmldir`) that reads
  colours from the shell's `Theme` singleton instead of Omarchy's `qs.Commons`.
  The window-border colours are read from `~/.config/hypr/aequalyn/colors.lua`.
- IPC target is `clipscape`: `qs ipc call clipscape picker|toggle|panel|
  pause|resume|copy <n>|paste <n>|status`. `Super + Ctrl + V` is bound to
  `qs ipc call clipscape toggle` in `config/hypr/aequalyn/clipboard.lua`.
- The bar button is `plugins/bar/widgets/ClipscapeButton.qml`; the plugin entry
  `Clipscape.qml` hosts the picker overlay. Both are registered in `Plugins.js`
  and `plugins/bar/widgets/Widgets.js`.
- State lives in `~/.local/state/aequalyn-clipscape/` (history, images, settings).
  On first run the helper imports the old Aequalyn history from
  `~/.local/state/aequalyn/clipboard-history.json`.
- `aequalyn.clipscape` replaces the former `clipboard` plugin in the `plugins`
  list and in the default `barRight` widget order.

Everything else (search, pins, previews, transforms, privacy rules, helper) is
upstream Clipscape, with only strings and paths adjusted.
