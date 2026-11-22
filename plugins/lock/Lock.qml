// Aequalyn session lock entry point. The state machine and Wayland client live
// in the LockService singleton so IPC and other plugins share one instance.
// Deliberately in-process and not sandboxed: the lock needs the Wayland
// session-lock protocol and the shell's live theme.
import Quickshell
import QtQuick
import "root:/settings"

Item {
  id: root
  property var theme: AequalynDefaultTheme {}

  function syncSettings() {
    LockService.theme = root.theme
    LockService.use24h = AequalynSettings.use24h
    LockService.lockStyle = AequalynSettings.lockStyle
  }

  onThemeChanged: syncSettings()

  Connections {
    target: AequalynSettings
    function onUse24hChanged() { root.syncSettings() }
    function onLockStyleChanged() { root.syncSettings() }
  }

  Component.onCompleted: syncSettings()
}
