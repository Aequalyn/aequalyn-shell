pragma Singleton

// Aequalyn session lock. Owns the Wayland ext-session-lock client and both PAM
// conversations. Loaded in-process by Plugins.js: the lock must never be
// sandboxed, and the plugin itself never reaches for root.
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import QtQuick

Singleton {
  id: root

  property var theme: null
  property bool use24h: true
  property string lockStyle: "classic"
  property string lockWallpaperSource: "wallpaper"
  property string appliedWallpaperPath: ""
  property string lockFieldPosition: "center"
  property bool lockShowUser: true
  property bool lockShowClock: true
  property bool lockShowDate: true
  property bool lockShowMedia: true
  property bool lockShowBattery: false
  property real lockClockX: -1
  property real lockClockY: -1
  property real lockFieldX: -1
  property real lockFieldY: -1
  property string lockCustomLayout: ""
  readonly property string effectiveWallpaperPath: {
    if (root.lockWallpaperSource === "solid") return ""
    if (root.lockWallpaperSource === "theme") return root.appliedWallpaperPath || root.wallpaperPath
    return root.wallpaperPath || root.appliedWallpaperPath
  }

  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string userName: Quickshell.env("USER") || Quickshell.env("LOGNAME") || ""
  readonly property string passwordPamPath: "/etc/pam.d/aequalyn-lock-password"
  readonly property string fingerprintPamPath: "/etc/pam.d/aequalyn-lock-fingerprint"

  property bool passwordPamConfigured: false
  property bool fingerprintPamConfigured: false
  property bool fingerprintEnrolled: false

  property bool lockRequested: false
  property bool pendingSessionLock: false
  property bool authenticating: false
  property bool glanceScanning: false
  property bool blanked: false
  property bool sleepRequested: false
  property bool previewVisible: false
  property string failureMessage: ""
  property int failedAttempts: 0
  property string enteredPassword: ""
  property string pendingPassword: ""
  property string wallpaperPath: ""
  property string event: "idle"

  property bool fingerprintClaimed: false
  property int fingerprintAttempts: 0
  property bool strandedLock: false
  property bool strandedCheckResolved: false

  // Kept by the lock's own signals: a binding on sessionLock.locked and .secure is not
  // told when they go back to false, and went on saying "locked" after an unlock.
  property bool sessionHeld: false
  readonly property bool locked: root.lockRequested || root.sessionHeld
  function refreshHeld() { root.sessionHeld = sessionLock.locked || sessionLock.secure }
  readonly property bool sessionSecure: sessionLock.secure
  readonly property bool fingerprintAvailable: root.fingerprintPamConfigured && root.fingerprintEnrolled

  function logEvent(name: string) { root.event = name }

  function resetAuthenticationState() {
    root.failedAttempts = 0
    root.failureMessage = ""
    root.enteredPassword = ""
    root.pendingPassword = ""
    root.authenticating = false
    root.glanceScanning = false
    root.fingerprintClaimed = false
    if (passwordPam.active) passwordPam.abort()
    if (fingerprintPam.active) fingerprintPam.abort()
    glanceProc.running = false
  }

  function queueSessionLock() {
    if (!root.lockRequested) return
    root.pendingSessionLock = true
    stabilizeTimer.restart()
  }

  function beginLock(forSleep: bool): string {
    root.refreshHeld()
    if (!root.passwordPamConfigured) {
      root.logEvent("missing-pam")
      return "missing-pam"
    }
    if (root.locked) {
      if (!sessionLock.locked && !sessionLock.secure) {
        // The plugin reports a lock, but the compositor holds none (an
        // earlier request never engaged it, or an unlock aborted mid-way).
        // (Re)request the session lock so this call can engage it.
        root.lockRequested = true
        root.blanked = false
        root.queueSessionLock()
        root.logEvent("locking-retry")
        return "ok"
      }
      root.logEvent("already-locked")
      return "already-locked"
    }
    root.sleepRequested = !!forSleep
    root.resetAuthenticationState()
    root.lockRequested = true
    root.blanked = false
    layoutProc.running = true
    root.logEvent("locking")
    root.queueSessionLock()
    return "ok"
  }

  function finishUnlock() {
    root.lockRequested = false
    root.pendingSessionLock = false
    // Quickshell 0.3.2's WlSessionLock has no `unlock()` function exposed to
    // QML; setting `locked = false` already releases the compositor lock via
    // WlSessionLock::unlock(). The WlSessionLock.locked property is bound to
    // lockRequested, so clearing the request releases the lock without breaking
    // the binding.
    blankTimer.stop()
    root.blanked = false
    root.sleepRequested = false
    root.resetAuthenticationState()
    root.refreshHeld()
    Qt.callLater(root.refreshHeld)
    root.logEvent("unlocked")
    root.runWake()
  }

  function runBlank() {
    if (root.blanked) return
    root.blanked = true
    blankProc.running = false
    blankProc.command = [root.home + "/.local/bin/aequalyn-dpms", "off"]
    blankProc.running = true
    root.logEvent("blanked")
  }

  function runWake() {
    wakeProc.running = false
    wakeProc.command = [root.home + "/.local/bin/aequalyn-lock-wake"]
    wakeProc.running = true
    root.logEvent("wake")
  }

  function noteSleepRequested() { root.sleepRequested = true }

  // ---- password ------------------------------------------------------------
  function submitPassword(text: string) {
    if (!root.locked) return
    const value = String(text || "")
    if (!value) return
    root.failureMessage = ""
    root.enteredPassword = ""
    root.authenticating = true
    if (passwordPam.active) {
      if (passwordPam.responseRequired) passwordPam.respond(value)
      else root.pendingPassword = value
    } else {
      root.pendingPassword = value
      if (!passwordPam.start()) {
        root.pendingPassword = ""
        root.handlePasswordFailure("The password service could not be started")
      }
    }
  }

  function respondToPasswordPrompt() {
    if (!passwordPam.responseRequired || !root.pendingPassword) return
    const value = root.pendingPassword
    root.pendingPassword = ""
    passwordPam.respond(value)
  }

  function handlePasswordFailure(message: string) {
    root.authenticating = false
    root.pendingPassword = ""
    root.failedAttempts++
    const fallback = passwordPam.message && !passwordPam.messageIsError
      ? passwordPam.message : "Incorrect password"
    root.failureMessage = message || fallback
    root.logEvent("password-failed")
  }

  // ---- fingerprint ---------------------------------------------------------
  function startFingerprint() {
    if (!root.locked || !root.fingerprintAvailable || fingerprintPam.active) return
    if (!fingerprintPam.start()) root.settleFingerprintAttempt(true)
  }

  function settleFingerprintAttempt(failed: bool) {
    if (fingerprintPam.active) fingerprintPam.abort()
    root.fingerprintClaimed = false
    if (!failed) return
    root.fingerprintAttempts++
    const backoff = 1000 * Math.pow(2, Math.min(root.fingerprintAttempts, 6))
    fingerprintRetryTimer.interval = Math.min(backoff, 40000)
    fingerprintRetryTimer.restart()
  }

  function handleFingerprintFinished(result: int) {
    if (result === PamResult.Success && root.locked) root.finishUnlock()
    else root.settleFingerprintAttempt(result !== PamResult.Success)
  }

  function refreshFingerprintStatus() {
    fingerprintProbe.running = false
    fingerprintProbe.command = ["fprintd-list", root.userName]
    fingerprintProbe.running = true
  }

  function checkStrandedLock() {
    strandedProc.running = false
    strandedProc.running = true
  }

  function recoverStrandedLock() {
    if (root.strandedLock && !root.locked) root.beginLock(false)
    root.strandedLock = false
  }

  // ---- glance (face unlock) -----------------------------------------------
  function triggerGlanceScan() {
    if (!root.locked || root.glanceScanning) return
    root.failureMessage = ""
    root.glanceScanning = true
    root.logEvent("glance-scan")
    glanceProc.running = false
    // (a scan that never answers is given up, so Space can start another)
    glanceProc.command = ["timeout", "20", "glancectl", "authenticate", "--json"]
    glanceProc.running = true
  }

  function handleGlanceFinished(exitCode: int) {
    root.glanceScanning = false
    if (!root.locked) return
    if (exitCode === 0) {
      root.logEvent("glance-unlocked")
      root.finishUnlock()
      return
    }
    root.failureMessage = "Face not recognised · Space to try again"
    root.logEvent("glance-failed")
  }

  // ---- PAM -----------------------------------------------------------------
  FileView {
    path: root.passwordPamPath
    watchChanges: true
    onLoaded: root.passwordPamConfigured = true
    onLoadFailed: {
      root.passwordPamConfigured = false
      root.checkStrandedLock()
    }
  }

  FileView {
    path: root.fingerprintPamPath
    watchChanges: true
    onLoaded: {
      root.fingerprintPamConfigured = true
      root.refreshFingerprintStatus()
    }
    onLoadFailed: {
      root.fingerprintPamConfigured = false
      root.fingerprintEnrolled = false
    }
  }

  FileView {
    path: root.home + "/.cache/aequalyn/current-wallpaper"
    watchChanges: true
    function readWallpaper() {
      return String(typeof text === "function" ? text() : text).trim()
    }
    onLoaded: root.wallpaperPath = readWallpaper()
    onTextChanged: root.wallpaperPath = readWallpaper()
    onLoadFailed: root.wallpaperPath = ""
  }

  PamContext {
    id: passwordPam
    config: "aequalyn-lock-password"
    user: root.userName

    onResponseRequiredChanged: root.respondToPasswordPrompt()
    onPamMessage: root.respondToPasswordPrompt()

    onCompleted: function(result) {
      root.authenticating = false
      root.pendingPassword = ""
      if (!root.locked) return
      if (result === PamResult.Success) root.finishUnlock()
      else root.handlePasswordFailure("")
    }

    onError: function(error) { root.handlePasswordFailure("") }
  }

  PamContext {
    id: fingerprintPam
    config: "aequalyn-lock-fingerprint"
    user: root.userName

    onPamMessage: {
      if (!messageIsError) root.fingerprintClaimed = true
    }

    onCompleted: function(result) { root.handleFingerprintFinished(result) }
    onError: function(error) { root.settleFingerprintAttempt(true) }
  }

  // ---- Wayland lock --------------------------------------------------------
  WlSessionLock {
    id: sessionLock

    locked: root.lockRequested

    onSecureStateChanged: {
      root.refreshHeld()
      root.logEvent("secure=" + secure)
      if (secure) {
        root.pendingSessionLock = false
        stabilizeTimer.stop()
        root.startFingerprint()
      }
    }

    onLockStateChanged: {
      root.refreshHeld()
      root.logEvent("session-locked=" + locked)
      if (locked) {
        root.pendingSessionLock = false
        stabilizeTimer.stop()
      } else if (root.lockRequested) {
        root.lockRequested = false
        root.pendingSessionLock = false
        root.resetAuthenticationState()
        root.runWake()
      }
    }

    WlSessionLockSurface {
      id: lockSurface
      color: root.theme ? root.theme.bgBase : "#141414"

      LockView {
        anchors.fill: parent
        theme: root.theme
        wallpaperPath: root.effectiveWallpaperPath
        userName: root.userName
        use24h: root.use24h
        lockStyle: root.lockStyle
        fieldPosition: root.lockFieldPosition
        settingShowUser: root.lockShowUser
        settingShowClock: root.lockShowClock
        settingShowDate: root.lockShowDate
        settingShowMedia: root.lockShowMedia
        settingShowBattery: root.lockShowBattery
        customClockX: root.lockClockX
        customClockY: root.lockClockY
        customFieldX: root.lockFieldX
        customFieldY: root.lockFieldY
        customLayout: root.lockCustomLayout
        failureMessage: root.failureMessage
        failedAttempts: root.failedAttempts
        authenticating: root.authenticating
        glanceScanning: root.glanceScanning
        fingerprintConfigured: root.fingerprintAvailable
        fingerprintClaimed: root.fingerprintClaimed
        sessionSecure: root.sessionSecure
        onSubmitPassword: function(value) { root.submitPassword(value) }
        onClearFailure: root.failureMessage = ""
        onTriggerGlance: root.triggerGlanceScan()
      }
    }
  }

  // ---- helpers -------------------------------------------------------------
  Timer {
    id: stabilizeTimer
    interval: 400
    repeat: false
    onTriggered: {
      if (!root.lockRequested) return
      // Re-assert the declarative binding in case it was broken by an
      // imperative assignment elsewhere.
      sessionLock.locked = Qt.binding(function() { return root.lockRequested })
    }
  }

  Timer {
    id: blankTimer
    interval: 5000
    repeat: false
    onTriggered: root.runBlank()
  }

  Timer {
    id: fingerprintRetryTimer
    interval: 2000
    repeat: false
    onTriggered: root.startFingerprint()
  }

  Timer {
    id: strandedRetryTimer
    interval: 500
    repeat: true
    running: root.lockRequested === false && !root.strandedCheckResolved && root.passwordPamConfigured
    onTriggered: {
      if (root.strandedCheckResolved) stop()
      else root.checkStrandedLock()
    }
  }

  Timer {
    id: startupTimer
    interval: 1500
    repeat: false
    onTriggered: {
      root.refreshFingerprintStatus()
      root.checkStrandedLock()
    }
  }

  Component.onCompleted: startupTimer.start()

  Process {
    id: layoutProc
    command: ["hyprctl", "switchxkblayout", "all", "0"]
  }

  Process {
    id: blankProc
    command: []
  }

  Process {
    id: wakeProc
    command: []
  }

  Process {
    id: glanceProc
    command: []
    onExited: function(exitCode) { root.handleGlanceFinished(exitCode) }
  }

  Process {
    id: fingerprintProbe
    command: []
    stdout: StdioCollector {
      onStreamFinished: {
        root.fingerprintEnrolled = /\s-\s#\d+:/.test(text)
        root.logEvent(root.fingerprintEnrolled ? "fingerprints-found" : "no-fingerprints")
      }
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) root.fingerprintEnrolled = false
    }
  }

  Process {
    id: strandedProc
    // $PPID is the shell: a crash re-execs in place, so its pid is the one to skip.
    command: ["bash", "-c", root.home + "/.local/bin/aequalyn-lock-stranded \"$PPID\""]
    onExited: function(exitCode) {
      if (exitCode === 2) return
      root.strandedCheckResolved = true
      root.strandedLock = exitCode === 0 && !root.locked
      root.recoverStrandedLock()
    }
  }

  // ---- IPC: qs ipc call lock <function> ------------------------------------
  IpcHandler {
    target: "lock"

    function lock(): string { return root.beginLock(false) }
    function lockForSleep(): string { return root.beginLock(true) }
    function status(): string {
      root.refreshHeld()
      return JSON.stringify({
        locked: root.locked,
        requested: root.lockRequested,
        sessionLocked: sessionLock.locked,
        secure: sessionLock.secure,
        pam: root.passwordPamConfigured,
        fingerprint: root.fingerprintAvailable,
        authenticating: root.authenticating,
        failed: root.failedAttempts,
        event: root.event,
        lockStyle: root.lockStyle,
        customLayoutLen: (root.lockCustomLayout || "").length,
        wallpaperPath: root.wallpaperPath
      })
    }
    function isLocked(): string { root.refreshHeld(); return root.locked ? "locked" : "unlocked" }
    function check(): string {
      return root.passwordPamConfigured ? "ok" : "missing-pam"
    }
    function wake(): string { root.runWake(); return "ok" }
    function noteSleep(): string { root.noteSleepRequested(); return "ok" }
  }
}
