# aequalyn-shell

The Aequalyn desktop, written in QML for [Quickshell](https://quickshell.org) on Hyprland:
the bar, up to 16 docks, the control center, the Store, the lock screen, launchers,
notifications, Aequalyn FM, Showcase desktop widgets and more than forty plugins, each on or
off at once.

![The desktop](docs/screenshots/desktop.jpg)

Installed to `~/.config/quickshell` by [aequalyn](https://github.com/Aequalyn/aequalyn)'s
`install.sh`, which also provides the `aequalyn-*` commands the shell calls.

## Control center

`Super + ,` — every setting, and a search over all of them (`Ctrl + K`).

| | |
| --- | --- |
| **Look** | Wallpaper (pick one, or change it over time), theme and colours, the theme picker, text, cursor, login screen |
| **Desktop** | Bar, dock, media, clipboard, showcase |
| **Windows** | 38 layouts for any workspace, window look, window switcher |
| **Devices** | Screens, sound, keyboard and mouse, keyboard shortcuts, Bluetooth, Wi-Fi |
| **System** | Lock and sleep, clock, plugins, updates, backup, about |

| Home | Bar | Dock |
| --- | --- | --- |
| ![](docs/screenshots/control-center.jpg) | ![](docs/screenshots/control-center-bar.jpg) | ![](docs/screenshots/control-center-dock.jpg) |
| **Theme** | **Arranging windows** | **Window look** |
| ![](docs/screenshots/control-center-theme.jpg) | ![](docs/screenshots/control-center-layouts.jpg) | ![](docs/screenshots/control-center-windows.jpg) |
| **Plugins** | **Login screen** | |
| ![](docs/screenshots/control-center-plugins.jpg) | ![](docs/screenshots/control-center-login.jpg) | |

## Themes and wallpapers

`Super + T` and `Super + W` open the picker. The whole shell previews the theme
under the cursor; each collection remembers its layout, of eight: slices, showcase, carousel,
grid, filmstrip, radial, list and spotlight.

| Grid | List | Radial |
| --- | --- | --- |
| ![](docs/screenshots/picker-themes-grid.jpg) | ![](docs/screenshots/picker-themes-list.jpg) | ![](docs/screenshots/picker-themes-radial.jpg) |
| **Showcase** | **Slices** | **Filmstrip** |
| ![](docs/screenshots/picker-wallpapers-showcase.jpg) | ![](docs/screenshots/picker-wallpapers-slices.jpg) | ![](docs/screenshots/picker-wallpapers-filmstrip.jpg) |

![Spotlight, over the whole screen](docs/screenshots/picker-wallpapers.jpg)

## Bar and docks

The bar is painted behind its widgets and the docks are painted by the same engine
(`style/`), so they can wear one look or each their own. The bar has 58 looks and a dock 32,
in five families (Calm, Isles, Pebbles, Glow, Crafted); 8 ensembles dress the bar and every
dock in one click. Most widgets open a quick panel under them, on the click you choose.
Right-click any dock for its settings.

| Battery | Clipboard |
| --- | --- |
| ![](docs/screenshots/quick-panel-battery.jpg) | ![](docs/screenshots/quick-panel-clipscape.jpg) |

**Quick looks** change the bar, the docks, the lock screen, the login screen, the cursor
(`Super + Ctrl + C`), Showcase's widgets (`Super + Ctrl + W`) and one look for all of them
(`Super + Ctrl + M`) from a list, without opening the control center:

| Bar · `Super + Ctrl + B` | Docks · `Super + Ctrl + D` |
| --- | --- |
| ![](docs/screenshots/quick-looks-bar.jpg) | ![](docs/screenshots/quick-looks-dock.jpg) |
| **Lock screen · `Super + Ctrl + K`** | **Login screen · `Super + Ctrl + G`** |
| ![](docs/screenshots/quick-looks-lock.jpg) | ![](docs/screenshots/quick-looks-login.jpg) |

Settings: `settings.json` → `barStyle` (checked by `style/BarLooks.js`), and
`~/.config/aequalyn/docks.json`.

## Store

`Super + Alt + S` — plugins, themes, cursors, wallpapers, looks, apps (Arch, AUR, Flathub,
Snap), web apps, AI tools and AppImages. What others made comes from the
[Market](https://github.com/Aequalyn/aequalyn-market), reviewed, and is installed and updated
only to the exact commit that was. A plugin may bring a bar widget of its own (`widget` in
its `plugin.json`). `Super + I` and `Super + R` choose what to install and remove.

| Plugins | Market |
| --- | --- |
| ![](docs/screenshots/store-plugins.jpg) | ![](docs/screenshots/store-market.jpg) |

## Lock screen

Thirty designs, set on the Lock and sleep page or with `Super + Ctrl + K`; `Super + Ctrl +
Shift + L` locks.

![](docs/screenshots/lock-screen.jpg)

## Aequalyn FM

`Super + Alt + F` — the file manager, and the open and save dialogs of every app.

![](docs/screenshots/files.jpg)

### Keys

Everything is in **Keyboard shortcuts** in the control center, and `Super + /` shows it. In
the picker:

| Key | |
| --- | --- |
| Arrows | Move |
| `Enter` / `Shift + Enter` | Apply and close / apply and keep browsing |
| Typing | Search |
| `Tab` | Themes or wallpapers |
| `Ctrl + 1…8` | Pick a layout |
| `Ctrl + F` | Favorite |
| `Ctrl + ,` | Its settings |
| `Esc` | Close |

### IPC

```sh
qs ipc show                              # everything there is
qs ipc call aequalyn page bar            # a page of the control center
qs ipc call aequalyn plugin docks off    # on | off | toggle
qs ipc call atelier toggle themes        # themes | wallpapers (the rest opens its control center page)
qs ipc call atelier layout radial        # slices | showcase | carousel | grid | filmstrip | radial | list | spotlight
qs ipc call wallpaper next               # prev | random | set <file> | mode <mode>
qs ipc call theme set tidal              # a theme's id
qs ipc call theme follow                 # colours follow the wallpaper again
qs ipc call dock add                     # toggle | show | hide | add | settings <n>
qs ipc call store section plugin         # a page of the Store
qs ipc call quickLooks bar               # bar | dock | lock | login | cursor | showcase | all
```

### Adding a layout

A layout of the picker is one file in `plugins/atelier/layouts/` taking `theme`, `font`, `items`
and `currentIndex`, exposing `columns` (for Up / Down) and emitting
`hovered(index)` and `picked(index)`. Add it to `layouts/qmldir`, to `layoutKeys` in
`Atelier.qml` and `PickerPreview.qml`, and to the switch in `Switcher.qml`.

## Watchdog and plugin sandbox

One broken plugin must never take the desktop down. `aequalyn-watchdog`
(`tools/watchdog/`, a Python supervisor) runs the shell and watches it, and
runs the risky plugins out of process so a failure costs only that one
plugin — never the shell, never the other plugins.

| | |
| --- | --- |
| **Sandboxed** | Plugins marked `sandbox: true` in `Plugins.js` (`batteryGuard`, `breaks`, `diskWatch`, `nightLight` and the two self-tests) and Store plugins whose manifest group is `background`: each runs as its own Quickshell instance with its own RAM budget, heartbeat and IPC. A crash, hang or leak restarts it; three failures in ten minutes turn it off, with a notification saying why. |
| **Watched, not sandboxed** | The bar, docks, panels and every visual plugin share the shell's process (their pixels are painted on its windows). A plugin that keeps failing to load -- after a moment's grace, so an update swapping the config tree never turns anything off by mistake -- is disabled with a notification; the shell itself is supervised: crash restart, freeze detection by heartbeat, a 2048 MiB memory ceiling. |

```sh
aequalyn-watchdog status                     # shell + sandboxed plugins: pid, RAM, failures
aequalyn-watchdog restart shell              # in place, what aequalyn-shell-restart now does
aequalyn-watchdog sandboxed                  # what would run out of process, and why
aequalyn-watchdog test <id> leak|hang|crash  # inject a fault and watch the policy work
```

**See it happen**: control center → Plugins → **Watchdog self-test**. Turned on, that
plugin crashes, leaks and crashes again on purpose -- three narrated failures
in its own process -- while the shell never goes down, until the watchdog
turns it off with a notification. Turn it on again to watch once more.

**Root goes through one gate, too.** A plugin that wants root declares its
actions in its manifest (command pinned, printed by the Store before
installing) and asks through `aequalyn-watchdog exec-root`; a window names
the plugin and the exact command, and the password feeds `sudo -S` on a
pipe. Anything that looks like sudo/pkexec outside the gate is stopped and
counts as a failure. The supervisor itself refuses to run as root: the
whole chain is the user's session. The full story is in
[`tools/watchdog/README.md`](tools/watchdog/README.md).

Started at login by `aequalyn-session-start` (and by the shell itself if it
finds no supervisor), it adopts an already-running shell instead of
replacing it. The full contract — failure classes, budgets
(`~/.config/aequalyn/watchdog.json`), the sandbox host, what a plugin can
expect out of process — is in [`tools/watchdog/README.md`](tools/watchdog/README.md);
`PLUGINS.md` says how to mark a plugin for the sandbox.

## Layout

```
shell.qml          entry point, shares the palette as ts.theme
Plugins.js         every plugin; PluginInfo.js what its card says; PluginManager.qml loads them
plugins/           one folder a plugin: bar/ (Bar.qml, BarSlot.qml, widgets/, quick/), docks/,
                   atelier/, store/, lock/, aequalynfm/, showcase/, media/, kit/ (shared parts) ...
settings/          AequalynSettings.qml (settings.json), UserPlugins.qml (the Store's plugins),
                   ControlCenter.qml and center/ (its parts Cc*.qml and pages/)
style/             the painter shared by bar and docks, AequalynLooks.js (looks, ensembles)
theme-switcher/    Theme.qml: the colours of the current theme
tools/             the watchdog, and generators
tests/             node tests
```

## Web apps

The Store's **Web apps** page turns a website into a window of its own: it appears in the
launcher, gets an icon, and has a `Super + Shift + <letter>` shortcut.

- The chosen browser opens them. Chromium-based browsers use `--app=URL`, so each
  one is a clean window with the site's own title bar. Firefox-based browsers use
  a separate profile per app with the navigation and tab bars hidden, so the
  window reads as an app too. Pick the browser in the same page; it can be
  changed at any time and the shortcuts keep working.
- Add or remove apps from the same page, or with the `aequalyn-webapp` command
  (`list`, `add`, `remove`, `set-browser`, `seed`). State lives in
  `~/.config/aequalyn/webapps.json`; launchers are written to
  `~/.local/share/applications/aequalyn-webapp-<slug>.desktop` and the shortcuts
  to `~/.config/hypr/webapps.lua`.
- The installer seeds Reddit, ChatGPT, YouTube, YouTube Music, WhatsApp, Gmail and GitHub
  (shortcuts D, G, T, Y, H and E) when the *Seed web apps* option is on, using the
  browser chosen at install time.

## Tests

```sh
for t in tests/*.test.js; do node "$t"; done
```

## Run from a checkout

```sh
qs -p .            # or: ln -s "$PWD" ~/.config/quickshell && qs -n -d
```

## Credits

[nightdevil00](https://github.com/nightdevil00) contributed to the code here.

## License

This project is licensed under the GNU General Public License v3.0 (GPL-3.0).
See [LICENSE](LICENSE) for the full text.

## Documentation

- `SECURITY.md` — security model and concerns.
- `SKILL.md` — development/install skill reference.
- `PLUGINS.md` — how a plugin is made; `plugins.md` — how they are loaded.
- `THEMES.md` — how the shell takes a theme.
- `tools/watchdog/README.md` — the supervisor and the sandbox.
