# Writing an Aequalyn plugin

Every part of the Aequalyn desktop is a plugin: the bar, the docks, the launcher, the
pickers, the window switcher, Media. Yours can sit next to them, or replace one of
them, and look and work like they do. This page is the standard the built-in plugins
follow. Nothing here is enforced; following it is what makes a plugin feel built in.

## The shape of a plugin

```
plugins/<id>/
├── <Name>.qml          the entry: what Plugins.js loads (a service, a panel, both)
├── <Name>Host.qml      a singleton: the link to the running plugin (see below)
├── qmldir              lists the singleton and the types others import
├── core/ js/ panel/    its own parts, each folder with a qmldir if imported by root:/
└── bin/ helper/        programs it runs, if any
```

- `<id>` is short, lowercase or camelCase, and never changes: it names the folder, the
  IPC target, the settings folder and the entry in `Plugins.js`.
- Import across folders with `root:/` (`import "root:/plugins/<id>"`). A folder imported
  that way needs a `qmldir` listing its types: the shell only knows the types of folders
  it can find.
- Load a part of your plugin as a component, not by a file path, so the shell sees it:
  `Loader { sourceComponent: Component { Overlay { } } }`.

## Registering it

Two lines, and it shows everywhere:

1. `Plugins.js`: `{ id: "<id>", label: "Short name", source: "plugins/<id>/<Name>.qml" }`.
   The plugin manager loads it, and the control center's Plugins page shows it.
2. `PluginInfo.js`: `<id>: { icon, group, keys, page, about }`.
   - `icon`: a Nerd Font glyph.
   - `group`: `"screen"` (always on the desktop), `"key"` (called up by a key or a
     click) or `"background"` (works out of sight).
   - `keys`: the shortcut that calls it up, as people read it: `"Super + Shift + C"`.
   - `page`: its control center page (`Pages.js`), `""` for none.
   - `about`: one plain sentence: what it does for you.

To turn a new built-in plugin on for people who already have a settings file, add its
id to `newPlugins` in `settings/AequalynSettings.qml`.

## Its life

- The plugin manager loads it when it is turned on and drops it when it is turned off,
  at once, without a restart. Clean up in `Component.onDestruction`: stop the
  processes you started, give back what you changed (a cursor, a key binding), and
  clear your host's `svc`.
- If your entry has a `theme` property, it receives the shell's palette (`bgBase`,
  `bgSurface`, `textPrimary`, `textMuted`, `accentPrimary`, ...). Take every colour from
  it: when the theme changes, so does your plugin.

## The sandbox

A plugin with no windows of its own in the shell can run in its own process instead:
add `sandbox: true` to its line in `Plugins.js` (a Store plugin gets it automatically
when its manifest says `"group": "background"`). The watchdog (`tools/watchdog/`,
`aequalyn-watchdog`) then runs it as its own QuickShell instance, and a crash, a hang
or a leak can only take that one process down: the watchdog restarts it, and turns it
off (with a notification) if it keeps failing. Notifications (`KitHost.notify`),
file-based settings (`KitStore`) and per-pid IPC keep working out of process; what
does not: the shared `theme`, being found through `KitHost` by the shell's own UI, and
being summoned by a bare `qs ipc call <id>` (only the main shell's targets answer
that). Plugins people summon with a key, or that draw inside the shell's windows
(bar widgets, docks, embedded panels), stay in-process and are not sandboxable.

To see all of it happen on purpose, turn on **Watchdog self-test** in Settings →
Plugins: it crashes, leaks and crashes again in its own process -- with a message
narrating each step -- while the shell stays up, until the watchdog turns it off.

## Root: one gate, declared up front

Your plugin runs as the user, and it may never reach for root on its own -- not
`sudo`, not `pkexec`, not `su`. The watchdog watches every plugin's process tree
for exactly that, stops the attempt, and turns the plugin off after three. The
only door is the gate, and the command is never yours to pass in: you declare
each action in your manifest, command included, and ask for it by name.

In `plugin.json` (a Store plugin):

```json
"needsRoot": [
  {
    "id": "fix-service",
    "label": "Restart the disk monitor",
    "about": "After swapping a disk, so it sees the new one",
    "command": ["/usr/bin/systemctl", "restart", "smartd"]
  }
]
```

- `command` is a fixed argv, run through `sudo -S` by the watchdog itself: no
  shell, no arguments you make up at run time, no `sudo` inside it (the gate
  adds sudo). At most 8 actions, 64 words, and 512 characters a word.
- The Store says all of this out loud while it checks your plugin, before
  anything is installed; the Plugins page badges the card with
  `runs as root`.
- A built-in declares the same shape on its line in `Plugins.js`, as plain
  JSON (quoted keys) so the supervisor can read it straight out of the file:

  ```js
  { id: "rootTest", label: "Root gate self-test", source: "plugins/rootTest/RootTest.qml",
    sandbox: true, needsRoot: [{ "id": "who-am-i", "label": "Show the user id it runs as",
    "command": ["/usr/bin/id", "-u"] }] }
  ```

  That one is real: **Root gate self-test** (Settings → Plugins) is the gate's
  own demo, the worked example. Turned on, it asks for its one action at
  once -- the window names it, you answer, and a notification narrates what
  became of the request: allowed and it really ran as root, denied or timed
  out and the command never ran. Either answer is the demo. An update's
  restart-all starts it quietly instead (AEQUALYN_PLUGIN_PLANNED): it asks
  only when a person turns it on.

Calling it (sandboxed or not, from a `Process`):

```qml
Process {
    command: ["aequalyn-watchdog", "exec-root", "fix-service"]
    // stdout: {"ok": true, "code": 0, "out": "...", "err": "..."}
}
```

What the user sees, every time: a window naming your plugin, the action and
the exact command, with the password field that feeds sudo. No answer in two
minutes is a denial. "Always allow this" only remembers consent -- the
password is asked again on the next run. The exit code is the command's own;
a denial answers `{"ok": false, "error": "denied by the user"}` with exit
126.

## The host singleton

Other parts of the shell (a bar button, the control center) reach your plugin through
one singleton, never by searching for it:

```qml
pragma Singleton
import QtQuick
import Quickshell
import "root:/settings/center"

Singleton {
    property var svc: null                        // set by the plugin while it runs
    function openSettings() { Cc.go("<page>") }   // its control center page
}
```

The plugin sets `<Name>Host.svc = root` in `Component.onCompleted` and clears it on
destruction. Everything that uses it checks for `null`: the plugin may be off.

## Settings

- A plugin with few settings keeps them in `settings/AequalynSettings.qml`, saved in
  `~/.config/aequalyn/settings.json`.
- A plugin with many keeps its own file in `~/.local/state/aequalyn/<id>/` and saves as
  you change things. If it once had another name, copy its files over once, never over
  newer ones.

## Commands and keys

- An `IpcHandler { target: "<id>" }` gives it commands:
  `qs ipc call <id> toggle`. Name them as verbs: `toggle`, `open`, `next`, `status`.
- Key bindings call those commands from the Hyprland config:
  `hl.bind(M .. " + X", hl.dsp.exec_cmd("qs ipc call <id> toggle"))`.
- Put the key in `PluginInfo.js` too, so its card and page show it.

## On the bar

A bar widget is a file in `plugins/bar/widgets/` with `required property var bar` (the
bar's theme, font and size), registered in `Widgets.js`. Say
`readonly property bool wanted: false` when there is nothing to show: the bar hides the
whole slot. A left click does the plugin's main thing; another click opens its quick
panel.

If the widget belongs to your plugin, say so in `Widgets.js` (`plugins`): while the
plugin is off, the widget is not loaded and takes no room on the bar.

### Its quick panel

What its widget opens, under it, on the click people choose for it on the Bar page: the same look as the gear's quick
panel, from the parts in `plugins/bar/quick/` (`QuickPopup`, `QuickCard`, `QuickTile`,
`QuickWide`, `QuickRound`, `QuickLevel`, `QuickLabel`). They take the bar's colours by
themselves.

```qml
// plugins/bar/widgets/<Name>Quick.qml
QuickPopup {
    id: q
    required property var bar
    glyph: "\u{F051B}"; title: "Name"; sub: "A line of its state"
    settingsLabel: "Name settings"                    // always the last button
    onSettingsClicked: { q.dismissed(); KitHost.openSettings("<id>") }
    actions: [ QuickRound { small: true; glyph: "..."; tip: "..." } ]   // in its header
    QuickCard { ... }                                 // then its body, top to bottom
}
```

Add it to `quick` in `Widgets.js` with the click that opens it unless people choose
another (`"right"`, or `"left"` when the widget has nothing else to do). The widget asks
the bar what a click means, `bar.clickRole("<widget id>", mouse.button)`: `"quick"`
(open the panel), `"main"` (its own thing), `"right"` (its own right click) or
`"middle"`. When the panel takes the left click, its own thing moves to the right one.

The widget hosts its panel, and the bar keeps one open at a time (`bar.widgetPopup`):

```qml
function toggleQuick() {
    const w = root.QsWindow.window;
    root.bar.toggleWidgetPopup("<id>", w ? w.screen : null);
}
NameQuick {
    id: quick
    bar: root.bar
    anchorItem: root
    open: root.bar.widgetPopup === "<id>" && !!root.QsWindow.window
          && root.QsWindow.window.screen === root.bar.popupScreen
    onDismissed: root.bar.widgetPopup = ""
}
```

Show what it is doing now first, then what you can do, then a new start; keep it to
one screen. `qs ipc call bar popup <id>` opens it from a key.

## Its page in the control center

`settings/center/pages/<Name>.qml`, listed in `settings/center/Pages.js` (its label,
icon, the words people may search for, and the category it sits in: Look, Desktop,
Windows, Connect, Apps or System). Then run `python3 tools/cc-index.py`: it reads every
titled control on the pages into the search, so people find your settings by name,
and can change the ones bound to a `setting` right from the search.

```qml
CcPage {
    id: page
    title: "Name"
    plugin: "<id>"          // the plugin's strip: what it does, its key, its switch
    sub: "One sentence: what this page sets."
    tabs: ["General", "Look"]
    readonly property var svc: NameHost.svc

    CcSection {
        visible: page.tab === 0
        title: "A group of settings"
        hint: "What they change."
        CcToggle { title: "Something on or off"; sub: "What it does when on." }
        CcChoice { options: [...]; current: ...; onChosen: key => ... }
        CcSlider { title: "An amount"; ... }
    }
}
```

- `plugin: "<id>"` opens the page with the plugin's own strip, the same on every
  plugin's page. When the plugin is off, say so on the page, and wait: the settings
  apply once it is back on.
- Build the settings from the control center's own parts (`CcSection`, `CcToggle`,
  `CcChoice`, `CcSlider`, `CcRow`, `CcField`, `CcButton`, `CcNote`, `CcMore`). A plugin
  that brings its own rows puts them in `CcPluginRows`, which shows them at the size
  every plugin's settings have.
- A page with many settings splits them into tabs, a few groups each. Things people
  rarely change go in a `CcMore`. A reset goes last, in a `CcMore` named "Start over",
  and asks twice.

## How it reads and feels

- Keyboard first. Everything a mouse can do, keys can: arrows move, Enter applies, Esc
  closes or goes back, typing searches.
- Plain words. Say what a setting does for the person, in a sentence: "Keeps the
  screen awake while it is on", not "Inhibit idle". No jargon, no exclamation marks.
- One look. Colours from the theme, `Cc.sans` for words and `Cc.mono` for keys and
  numbers, the control center's radii and spacing. A full-screen panel uses the
  shell's backdrop (`style/backdrop`), so it opens and closes like the others.
- Quiet when idle. Draw nothing and run nothing that isn't needed: timers and
  processes only while they matter.

## Checklist

- [ ] A folder under `plugins/`, a `qmldir` in each folder imported by `root:/`
- [ ] A line in `Plugins.js` and one in `PluginInfo.js`
- [ ] Background only? `sandbox: true`, so a failure costs just your plugin
- [ ] Loads and unloads cleanly while the shell runs
- [ ] Colours from the theme; nothing hard-coded but fallbacks
- [ ] An `IpcHandler` named after its id
- [ ] Its page: `plugin: "<id>"`, the control center's parts, a note while it is off
- [ ] Every action reachable by keyboard
