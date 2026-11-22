// The visible lock surface: blurred wallpaper, clock, password field and the
// fingerprint glyph. All colours come from the shell's injected theme.
import Quickshell
import QtQuick
import QtQuick.Effects

Item {
  id: root

  property var theme: null
  property string wallpaperPath: ""
  property string userName: ""
  property string failureMessage: ""
  property int failedAttempts: 0
  property bool authenticating: false
  property bool glanceScanning: false
  property bool fingerprintConfigured: false
  property bool fingerprintClaimed: false
  property bool sessionSecure: false

  signal submitPassword(string value)
  signal clearFailure()
  signal triggerGlance()

  readonly property color bg: theme && theme.bgBase ? theme.bgBase : "#141414"
  readonly property color surface: theme && theme.bgSurface ? theme.bgSurface : "#1e1e1e"
  readonly property color border: theme && theme.bgBorder ? theme.bgBorder : "#45475a"
  readonly property color fg: theme && theme.textPrimary ? theme.textPrimary : "#e0e0e0"
  readonly property color muted: theme && theme.textMuted ? theme.textMuted : "#8a8a8a"
  readonly property color accent: theme && theme.accentPrimary ? theme.accentPrimary : "#7aa2f7"
  readonly property color error: theme && theme.accentRed ? theme.accentRed : "#f7768e"
  readonly property string font: "JetBrainsMono Nerd Font"

  Image {
    id: wallpaper
    anchors.fill: parent
    source: root.wallpaperPath ? "file://" + root.wallpaperPath : ""
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    cache: false
    visible: false
    layer.enabled: true
  }

  MultiEffect {
    source: wallpaper
    anchors.fill: parent
    visible: wallpaper.status === Image.Ready
    autoPaddingEnabled: false
    blurEnabled: true
    blurMax: 48
    blur: 0.45
    blurMultiplier: 1.0
    brightness: -0.08
    saturation: 0.0
  }

  Rectangle {
    anchors.fill: parent
    color: "#000000"
    opacity: wallpaper.status === Image.Ready ? 0.18 : 1
  }

  Timer {
    id: clockTimer
    interval: 1000
    repeat: true
    running: true
    onTriggered: clockText.text = Qt.formatTime(new Date(), "HH:mm")
  }

  Text {
    id: clockText
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    anchors.topMargin: Math.max(48, parent.height * 0.12)
    text: Qt.formatTime(new Date(), "HH:mm")
    color: root.fg
    font.family: root.font
    font.pixelSize: 64
    font.bold: true
  }

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: clockText.bottom
    anchors.topMargin: 8
    text: Qt.formatDate(new Date(), "dddd, d MMMM")
    color: root.muted
    font.family: root.font
    font.pixelSize: 14
  }

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: field.top
    anchors.bottomMargin: 14
    text: root.userName
    color: root.fg
    font.family: root.font
    font.pixelSize: 18
    font.bold: true
    visible: root.userName !== ""
  }

  Rectangle {
    id: field
    width: Math.min(420, parent.width - 64)
    height: 56
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: 48
    radius: 12
    color: root.surface
    opacity: 0.94
    border.color: root.failureMessage ? root.error : (input.activeFocus ? root.accent : root.border)
    border.width: input.activeFocus || root.failureMessage ? 2 : 1

    TextInput {
      id: input
      anchors {
        left: parent.left
        right: parent.right
        top: parent.top
        bottom: parent.bottom
        leftMargin: 18
        rightMargin: 56
      }
      verticalAlignment: TextInput.AlignVCenter
      echoMode: TextInput.Password
      passwordCharacter: "•"
      maximumLength: 512
      focus: true
      color: root.fg
      font.family: root.font
      font.pixelSize: 18
      selectByMouse: true
      onAccepted: {
        const value = text
        text = ""
        if (value) root.submitPassword(value)
      }
      onTextEdited: root.clearFailure()
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Space && text === "") {
          root.triggerGlance()
          event.accepted = true
        }
      }
    }

    Text {
      anchors {
        right: parent.right
        rightMargin: 18
        verticalCenter: parent.verticalCenter
      }
      text: root.fingerprintConfigured ? "󰏖" : "󰌾"
      color: root.fingerprintConfigured
        ? (root.fingerprintClaimed ? root.accent : root.muted) : root.muted
      font.family: root.font
      font.pixelSize: 20
      opacity: root.authenticating ? 0.5 : 1
    }
  }

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: field.bottom
    anchors.topMargin: 14
    text: root.failureMessage
      ? root.failureMessage + (root.failedAttempts > 1 ? " (" + root.failedAttempts + ")" : "")
      : (root.glanceScanning ? "Scanning face…" : (root.authenticating ? "Checking…" : "Password, then Enter · Space for face unlock"))
    color: root.failureMessage ? root.error : root.muted
    font.family: root.font
    font.pixelSize: 13
  }

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 28
    text: "Aequalyn"
    color: root.muted
    font.family: root.font
    font.pixelSize: 12
    opacity: 0.7
  }

  Connections {
    target: LockService
    function onSessionSecureChanged() {
      if (root.sessionSecure) input.forceActiveFocus()
    }
  }

  Component.onCompleted: input.forceActiveFocus()
}
