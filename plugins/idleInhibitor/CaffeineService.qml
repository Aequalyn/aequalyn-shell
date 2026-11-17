pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Shared caffeine (idle inhibitor) state/service.
// Owns the active/inhibited state, persists it across restarts, and exposes
// toggle methods and IPC (target "idle"). The actual Wayland IdleInhibitor is
// held by CaffeineToggle's always-mapped window, which binds to this state.
Singleton {
  id: root

  property bool active: false
  property bool restoring: true
  readonly property string statePath: Quickshell.env("HOME") + "/.local/state/aequalyn/caffeine"

  Component.onCompleted: loadProc.running = true

  function toggle() { active = !active }
  function enable() { active = true }
  function disable() { active = false }
  // on for a while, then off by itself (the Keep awake quick panel); 0: no end
  property double until: 0
  function enableFor(minutes) { active = true; until = Date.now() + minutes * 60000 }
  property int minutesLeft: 0
  Timer {
    interval: 15000; repeat: true; triggeredOnStart: true
    running: root.active && root.until > 0
    onTriggered: {
      root.minutesLeft = Math.max(0, Math.ceil((root.until - Date.now()) / 60000))
      if (Date.now() >= root.until) root.active = false
    }
  }

  onActiveChanged: {
    if (!active) until = 0
    if (restoring) return
    saveProc.command = ["sh", "-c",
      'mkdir -p "$HOME/.local/state/aequalyn" && printf %s "$1" > "$HOME/.local/state/aequalyn/caffeine"',
      "sh", root.active ? "1" : "0"]
    saveProc.running = true
  }

  Process {
    id: loadProc
    running: false
    command: ["sh", "-c", 'cat "$HOME/.local/state/aequalyn/caffeine" 2>/dev/null || true']
    stdout: StdioCollector {
      onStreamFinished: {
        root.restoring = true
        root.active = text.trim() === "1"
        root.restoring = false
      }
    }
  }

  Process { id: saveProc; running: false }

  IpcHandler {
    target: "idle"
    function toggle(): void { root.toggle() }
    function enable(): void { root.enable() }
    function disable(): void { root.disable() }
  }
}
