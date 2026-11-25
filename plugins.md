# Plugins

Aequalyn's shell elements are loaded as independent plugins by `PluginManager.qml`.
Each plugin lives in its own directory under `plugins/` (or, for core pieces such
as `theme-switcher` and `settings`, at the shell root) and exposes a single entry
QML file.

## Plugin list

| id | entry | |
| --- | --- | --- |
| `bar` | `plugins/bar/Bar.qml` | Top bar |
| `appLauncher` | `plugins/appLauncher/AppLauncher.qml` | App launcher |
| `defaultApps` | `plugins/defaultApps/DefaultApps.qml` | Default apps launcher |
| `programsMenu` | `plugins/programsMenu/ProgramsMenu.qml` | Programs menu |
| `installMenu` | `plugins/installMenu/InstallMenu.qml` | Install chooser |
| `notifications` | `plugins/notifications/NotificationPopup.qml` | Notifications |
| `atelier` | `plugins/atelier/Atelier.qml` | Themes and wallpapers |
| `osd` | `plugins/osd/OSD.qml` | On-screen display |
| `snap` | `plugins/snap/Snap.qml` | Snap layouts |
| `monitorManager` | `plugins/monitorManager/MonitorManager.qml` | Monitor manager |
| `idleInhibitor` | `plugins/idleInhibitor/CaffeineToggle.qml` | Idle inhibitor |
| `clipscape` | `plugins/clipscape/Clipscape.qml` | Clipscape clipboard |
| `showcase` | `plugins/showcase/Showcase.qml` | Showcase desktop widgets |
| `powerMenu` | `plugins/powerMenu/PowerMenu.qml` | Power menu |
| `docks` | `plugins/docks/DocksService.qml` | Docks |
| `plume` | `plugins/plume/Service.qml` | Cursor and pointer effects |
| `altscape` | `plugins/altscape/Altscape.qml` | Window switcher |
| `media` | `plugins/media/qml/Service.qml` | Media |
| `fm` | `plugins/aequalynfm/Fm.qml` | Aequalyn FM (file manager) |
| `keybinds` | `plugins/keybinds/Keybinds.qml` | Keyboard shortcuts |
| `calculator` | `plugins/calculator/Calculator.qml` | Calculator |
| `colorPicker` | `plugins/colorPicker/ColorPicker.qml` | Color picker |
| `emoji` | `plugins/emoji/Emoji.qml` | Emoji |
| `notes` | `plugins/notes/Notes.qml` | Quick notes |
| `keyHints` | `plugins/keyHints/KeyHints.qml` | Key hints |
| `manual` | `plugins/manual/Manual.qml` | Manual |
| `fonts` | `plugins/fonts/Fonts.qml` | Fonts |
| `quickLooks` | `plugins/quickLooks/QuickLooks.qml` | Quick looks |
| `palette` | `plugins/palette/Palette.qml` | Command palette |
| `sysmon` | `plugins/sysmon/SystemMonitor.qml` | System monitor |
| `screenText` | `plugins/screenText/ScreenText.qml` | Screen text |
| `timer` | `plugins/timer/Timer.qml` | Timer |
| `focus` | `plugins/focus/Focus.qml` | Focus |
| `weather` | `plugins/weather/Weather.qml` | Weather |
| `netSpeed` | `plugins/netSpeed/NetSpeed.qml` | Network speed |
| `nightLight` | `plugins/nightLight/NightLight.qml` | Night light |
| `batteryGuard` | `plugins/batteryGuard/BatteryGuard.qml` | Battery guard |
| `breaks` | `plugins/breaks/Breaks.qml` | Break reminder |
| `diskWatch` | `plugins/diskWatch/DiskWatch.qml` | Disk watch |
| `watchdogTest` | `plugins/watchdogTest/WatchdogTest.qml` | Watchdog self-test |
| `rootTest` | `plugins/rootTest/RootTest.qml` | Root gate self-test |
| `lock` | `plugins/lock/Lock.qml` | Lock screen |
| `store` | `plugins/store/Store.qml` | Store |
| `settings` | `settings/ControlCenter.qml` | Control center |

What each does, its key and its group: `PluginInfo.js`.

`theme-switcher` (ThemeSwitcher) stays a core component because every plugin binds
to its palette.

## Enabling / disabling

Enabled plugins are stored in `AequalynSettings.enabledPlugins` (persisted to
`~/.config/aequalyn/settings.json` under `plugins`). The control center's Plugins page
toggles them, at once and without a restart.

A dock is treated as a plugin too: `AequalynSettings.dockEnabled` is derived from
whether `"docks"` is in `enabledPlugins`.

## Adding a plugin

1. Create `plugins/<id>/` with an entry QML file and a `DefaultTheme.qml` fallback.
2. Add its line to `Plugins.js` (`id`, `label`, `source`, and `sandbox` or `needsRoot` where
   it applies) and its card to `PluginInfo.js`.
3. Add the id to the default `enabledPlugins` list in `AequalynSettings.qml` and
   to the shipped `config/aequalyn/settings.json`.
4. If the plugin needs the shared theme, accept a `theme` property; `PluginManager`
   binds it to `ts.theme` after load.

The whole standard is in `PLUGINS.md`. A plugin for the Store lives in a repository of its
own with a `plugin.json` (and `widget`, when it has a place on the bar): see
[aequalyn-market](https://github.com/Aequalyn/aequalyn-market/blob/main/docs/guidelines/plugin.md).

## Notes

- Plugins are independent: each owns its Wayland surfaces, IPC handlers and state.
- Disabling a plugin removes its surfaces and IPC from the running shell.
- Cross-plugin wiring (e.g. docks following the bar's visibility) is handled in
  `PluginManager.onLoaded`.
