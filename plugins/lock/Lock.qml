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
    LockService.lockWallpaperSource = AequalynSettings.lockWallpaperSource
    LockService.appliedWallpaperPath = AequalynSettings.wallpaperPath
    LockService.lockFieldPosition = AequalynSettings.lockFieldPosition
    LockService.lockShowUser = AequalynSettings.lockShowUser
    LockService.lockShowClock = AequalynSettings.lockShowClock
    LockService.lockShowDate = AequalynSettings.lockShowDate
    LockService.lockShowMedia = AequalynSettings.lockShowMedia
    LockService.lockShowBattery = AequalynSettings.lockShowBattery
    LockService.lockClockX = AequalynSettings.lockClockX
    LockService.lockClockY = AequalynSettings.lockClockY
    LockService.lockFieldX = AequalynSettings.lockFieldX
    LockService.lockFieldY = AequalynSettings.lockFieldY
  }

  onThemeChanged: syncSettings()

  Connections {
    target: AequalynSettings
    function onUse24hChanged() { root.syncSettings() }
    function onLockStyleChanged() { root.syncSettings() }
    function onLockWallpaperSourceChanged() { root.syncSettings() }
    function onLockFieldPositionChanged() { root.syncSettings() }
    function onLockShowUserChanged() { root.syncSettings() }
    function onLockShowClockChanged() { root.syncSettings() }
    function onLockShowDateChanged() { root.syncSettings() }
    function onLockShowMediaChanged() { root.syncSettings() }
    function onLockShowBatteryChanged() { root.syncSettings() }
    function onWallpaperPathChanged() { root.syncSettings() }
    function onLockClockXChanged() { root.syncSettings() }
    function onLockClockYChanged() { root.syncSettings() }
    function onLockFieldXChanged() { root.syncSettings() }
    function onLockFieldYChanged() { root.syncSettings() }
  }

  Component.onCompleted: syncSettings()
}
