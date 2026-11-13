// Aequalyn -- a QuickShell desktop shell for Hyprland.
//
// Entry point. Modules are kept independent (each has its own DefaultTheme
// fallback) so any one of them can be swapped out or disabled. `ts.theme` is
// the shared palette: a folder theme, one of the curated palettes or the
// matugen palette generated from the current wallpaper.
//@ pragma UseQApplication
//@ pragma DefaultEnv QT_QPA_PLATFORMTHEME=gtk3
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QSG_RENDER_LOOP=threaded
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import Quickshell
import Quickshell.Io
import QtQuick
import "plugins/bar"
import "plugins/appLauncher"
import "plugins/notifications"
import "theme-switcher"
import "plugins/atelier"
import "plugins/osd"
import "plugins/monitorManager"
import "plugins/idleInhibitor"
import "settings"
import "plugins/clipboard"
import "plugins/powerMenu"
import "plugins/docks"
import "root:/settings"

// Root scope: instantiates every UI module once and shares a single active
// theme object (`ts.theme`) from ThemeSwitcher. Modules are otherwise
// independent (services/panels/overlays each own their Wayland surfaces,
// IPC handlers, and state). Load order here defines what exists in the shell;
// disabling a feature is as simple as removing its component instance.
Scope {
  // Central theme provider: manages curated themes and matugen/wallpaper
  // palette generation. Exposes the active palette as `ts.theme`.
  ThemeSwitcher {
    id: ts
  }

  // All shell elements are loaded as plugins (see PluginManager.qml), so each
  // can be enabled/disabled independently from Settings -> Plugins.
  PluginManager {
    theme: ts.theme
    themeSwitcher: ts
  }
}
