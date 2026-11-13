# Plugins

Aequalyn's shell elements are loaded as independent plugins by `PluginManager.qml`.
Each plugin lives in its own directory under `plugins/` (or, for core pieces such
as `theme-switcher` and `settings`, at the shell root) and exposes a single entry
QML file.

## Plugin list

| id | entry | description |
| --- | --- | --- |
| `bar` | `plugins/bar/Bar.qml` | Top status bar: left, center and right regions; each widget is a file in `plugins/bar/widgets/` (see `Widgets.js`). |
| `appLauncher` | `plugins/appLauncher/AppLauncher.qml` | Application launcher overlay. |
| `notifications` | `plugins/notifications/NotificationPopup.qml` | Notification daemon popups. |
| `atelier` | `plugins/atelier/Atelier.qml` | Themes, wallpapers, layouts, bar and docks picker. |
| `osd` | `plugins/osd/OSD.qml` | Volume/brightness on-screen display. |
| `monitorManager` | `plugins/monitorManager/MonitorManager.qml` | Monitor layout manager. |
| `idleInhibitor` | `plugins/idleInhibitor/CaffeineToggle.qml` | Idle inhibitor toggle. |
| `clipboard` | `plugins/clipboard/ClipboardPanel.qml` | Clipboard history. |
| `powerMenu` | `plugins/powerMenu/PowerMenu.qml` | Power/session menu. |
| `docks` | `plugins/docks/DocksService.qml` | Up to 16 docks. |
| `settings` | `settings/Settings.qml` | Settings panel. |

`theme-switcher` (ThemeSwitcher) stays a core component because every plugin binds
to its palette.

## Enabling / disabling

Enabled plugins are stored in `AequalynSettings.enabledPlugins` (persisted to
`~/.config/aequalyn/settings.json` under `plugins`). The Settings panel
(Settings -> Plugins) toggles them; changes apply after restarting the shell.

A dock is treated as a plugin too: `AequalynSettings.dockEnabled` is derived from
whether `"docks"` is in `enabledPlugins`.

## Adding a plugin

1. Create `plugins/<id>/` with an entry QML file and a `DefaultTheme.qml` fallback.
2. Add an entry to `PluginManager.allPlugins`:
   ```qml
   { id: "<id>", source: "plugins/<id>/Entry.qml" }
   ```
3. Add the id to the default `enabledPlugins` list in `AequalynSettings.qml` and
   to the shipped `config/aequalyn/settings.json`.
4. Optionally add a toggle row in Settings -> Plugins.
5. If the plugin needs the shared theme, accept a `theme` property; `PluginManager`
   binds it to `ts.theme` after load.

## Notes

- Plugins are independent: each owns its Wayland surfaces, IPC handlers and state.
- Disabling a plugin removes its surfaces and IPC from the running shell.
- Cross-plugin wiring (e.g. docks following the bar's visibility) is handled in
  `PluginManager.onLoaded`.
