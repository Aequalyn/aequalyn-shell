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

  onThemeChanged: LockService.theme = root.theme

  Component.onCompleted: LockService.theme = root.theme
}
