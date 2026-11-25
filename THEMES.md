# Aequalyn Shell — themes

How the shell consumes, applies and switches themes. For the theme *format* and the
Store's install pipeline, see the `aequalyn` core repo and `aequalyn-themes`.

## Providers

- `theme-switcher/ThemeSwitcher.qml` instantiates `Theme` and exposes `ts.theme` plus
  the IPC target `theme` (`wallpaper`, `follow`, `set`, `reapply`, `reload`,
  `current`, `toggle`).
- `theme-switcher/Theme.qml` (Singleton): curated fallback `themes` plus folder themes
  from `aequalyn-themes list --json`; `wallpaperMode` (matugen) reads
  `~/.config/quickshell/theme-switcher/wallpaper-theme.json` via FileView;
  `currentFolderId`; preview palette.
- `applyTheme(t)` propagates to kitty, lock screen, terminal palette, system colour
  scheme, Hyprland borders (`colors.lua`), KDE (if integration), Nautilus palette,
  browser policy.

## Folder themes

- Activated via `setFolderTheme(id)` → writes `~/.config/quickshell/theme.conf`
  (`theme:<id>` or `wallpaper`), calls `aequalyn-themes set`, applies palette, updates
  `~/.config/aequalyn/current/theme` symlink.
- `plugins/atelier/` is the picker (Themes and wallpapers); settings page
  `settings/center/pages/Theme.qml` (and `Picker.qml`).

## Sources of colour

1. **A theme** — folder with palette + backgrounds. Picking one puts its colours
   everywhere at once, and its first wallpaper on (unless one of its own is already on).
2. **The wallpaper** — colours generated from whatever background is showing, via
   matugen, following every change. A theme must live beside this mode, not fight it.

## Security

- Themes are data: no scripts, executables or symlinks; no config writes; no absolute
  paths or remote URLs.
- Every image sniffed by magic bytes and size-capped; filenames sanitized; folder
  walked.
- See `SECURITY.md` and `aequalyn/Security.md` (arbitrary Git theme install supply
  chain, path traversal in theme removal, QML palette injection).
