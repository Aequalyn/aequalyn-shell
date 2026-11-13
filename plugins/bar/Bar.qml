// Top bar shell component.
// Renders a per-screen Wayland bar split into left/center/right sections
// so plugins don't spread; apps-menu/settings are draggable bar items.
// Plugin placement/order/visibility are driven by AequalynSettings regions. Integrates system services
// (workspaces, media/MPRIS, audio, brightness, network, battery, tray,
// bluetooth, recording, power, etc.) and exposes IPC (target "bar").

// Aequalyn top bar. Plugins are placed in left/center/right regions
// (AequalynSettings.barLeft/barCenter/barRight) and can be reordered/moved
// between regions in Settings. Arch apps-menu and settings stay at the ends.
import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import "root:/settings"
import "root:/plugins/bluetooth"
import "root:/plugins/wifi"
import "root:/plugins/idleInhibitor"
import QtQuick.Controls
import "root:/plugins/atelier"
import  "../../style/Shapes.js" as Shapes
import  "../../style/BarLooks.js" as BarLooks

Scope {
  id: root
  property var theme: DefaultTheme {}
  property string font: "JetBrainsMono Nerd Font"
  property bool barVisible: true
  property bool wifiPopupVisible: false

  Shortcut {
    sequence: "Escape"
    enabled: root.wifiPopupVisible
    onActivated: root.wifiPopupVisible = false
  }

  // ---- the bar's look (Atelier -> Bar) ------------------------------------
  // Shapes painted behind the widgets (BarDecor): one band, a pill, an island
  // per group or a pill per widget, floating or stuck to the edge.
  readonly property var look: BarLooks.clean(AequalynSettings.barStyleCfg)
  readonly property bool styled: look.enabled
  readonly property int barSize: AequalynSettings.barHeight
  // widgets keep their own chips unless every widget already sits in a pill
  readonly property bool chips: !styled || (look.shape !== "widgets" && AequalynSettings.barStyleCfg.chips !== false)
  readonly property color chipColor: chips ? theme.bgSurface : "transparent"
  readonly property int floatGap: styled ? Shapes.floatGapFor(look) : 0
  readonly property int bandThickness: styled ? Shapes.thicknessFor(barSize, look) : barSize
  readonly property int windowThickness: bandThickness + floatGap
  readonly property int sectionMargin: styled ? Math.round(Shapes.sectionMargin(look, 8, barSize)) : 8
  readonly property int widgetSpacing: styled && look.shape === "widgets" ? Math.max(6, Shapes.pillSpacing(look, barSize)) : 8

  property var activePlayer: {
    const players = Mpris.players.values;
    if (!players || players.length === 0) return null;
    for (const p of players) {
      if (p.playbackState === MprisPlaybackState.Playing) return p;
    }
    return players[0];
  }

  IpcHandler {
    target: "bar"
    function toggle(): void { root.barVisible = !root.barVisible; }
  }

  // Track default audio sink for volume state in bar audio widgets.
  PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

  // ---- brightness state --------------------------------------------------
  property real brightnessValue: 0
  property real brightnessMax: 1

  FileView {
    id: brightnessFile
    path: ""
    watchChanges: true
    onFileChanged: brightnessReadProc.running = true
  }

  Process {
    id: brightnessReadProc
    command: ["brightnessctl", "get"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        const val = parseInt(text.trim());
        if (!isNaN(val) && root.brightnessMax > 0)
          root.brightnessValue = val / root.brightnessMax;
      }
    }
  }

  Process { id: brightnessSetProc; running: false }

  Process {
    id: backlightDiscovery
    command: ["sh", "-c", "p=$(ls -d /sys/class/backlight/*/brightness 2>/dev/null | head -1); [ -n \"$p\" ] && echo \"$p\" && cat \"${p%brightness}max_brightness\""]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.trim().split("\n");
        if (lines.length >= 2) {
          const max = parseInt(lines[1]);
          if (!isNaN(max) && max > 0) root.brightnessMax = max;
          brightnessFile.path = lines[0];
          brightnessReadProc.running = true;
        }
      }
    }
  }

  // ---- IPC helpers (other targets in this same shell) -------------------
  // Bar buttons trigger other shell modules by calling their IPC targets via
  // `qs ipc call ...` processes (launcher, settings, power, recorder, etc.).
  Process { id: launcherProc; running: false }
  Process { id: settingsProc; running: false }
  Process { id: powerProc; running: false }
  Process { id: recorderProc; running: false }
  property bool recordingActive: false
  function toggleRecording() {
    recorderToggleProc.command = ["aequalyn-record", "toggle"];
    recorderToggleProc.running = true;
  }
  function takeScreenshot() {
    Quickshell.execDetached(["aequalyn-screenshot", "region-clip"]);
  }
  Process {
    id: recorderToggleProc
    running: false
    stdout: StdioCollector {
      onStreamFinished: recorderStatusProc.running = true
    }
    onExited: recorderStatusProc.running = true
  }
  Process {
    id: recorderStatusProc
    running: true
    command: ["aequalyn-record", "status"]
    stdout: StdioCollector {
      onStreamFinished: root.recordingActive = text.trim() === "recording"
    }
  }
  Timer {
    interval: 3000
    repeat: true
    running: true
    onTriggered: if (!recorderStatusProc.running) recorderStatusProc.running = true
  }
  function openLauncher() {
    launcherProc.command = ["qs", "ipc", "call", "launcher", "toggle"];
    launcherProc.running = true;
  }
  function openSettings() {
    settingsProc.command = ["qs", "ipc", "call", "aequalyn", "settings"];
    settingsProc.running = true;
  }
  function openPowerMenu() {
    powerProc.command = ["qs", "ipc", "call", "power", "toggle"];
    powerProc.running = true;
  }

  // ---- plugin component lookup ------------------------------------------
  // Maps plugin IDs from AequalynSettings.pluginOrder to their visual components.
  // The bar renders plugins by iterating the configured order and loading
  // the matching component for each visible plugin slot.
  function componentFor(id) {
    switch (id) {
      case "appsmenu":    return cAppsMenu;
      case "settingsbutton": return cSettingsButton;
      case "clock":       return cClock;
      case "workspaces":  return cWorkspaces;
      case "media":       return cMedia;
      case "title":       return cTitle;
      case "volume":      return cVolume;
      case "brightness":  return cBrightness;
      case "cpu":         return cCpu;
      case "network":     return cNetwork;
      case "bluetooth":   return cBluetooth;
      case "battery":     return cBattery;
      case "temperature": return cTemperature;
      case "tray":        return cTray;
      case "power":       return cPower;
      case "screenrecorder": return cScreenRecorder;
      case "screenshot":  return cScreenshot;
      case "caffeine":    return cCaffeine;
      case "atelier":     return cAtelierButton;
      case "layouts":     return cLayoutsButton;
      default:            return cEmpty;
    }
  }


  // ---- Atelier and Layouts buttons ---------------------------------------
  // Left click opens Atelier on its tab: as a panel docked under the button,
  // a window, or full screen (Atelier -> Panel). Right / middle click do what
  // the Panel tab says. Every bar registers its button, so Super + T can dock
  // the panel under the button on the focused monitor.
  component AtelierBarButton: Rectangle {
    id: btn
    property string tab: "themes"
    property string icon: ""
    property string label: ""
    property bool showName: true
    property string rightAction: "none"
    property string middleAction: "none"
    readonly property bool active: AtelierHost.shown && AtelierHost.shownCollection === tab
    readonly property string screenName: {
      try { return btn.QsWindow.window && btn.QsWindow.window.screen ? btn.QsWindow.window.screen.name : ""; }
      catch (e) { return ""; }
    }
    onScreenNameChanged: if (screenName !== "") AtelierHost.register(screenName + ":" + tab, btn)
    Component.onDestruction: AtelierHost.unregister(screenName + ":" + tab, btn)

    height: 24
    width: row.implicitWidth + 16
    radius: 12
    color: active ? root.theme.bgSelected : (area.containsMouse ? root.theme.bgHover : root.chipColor)
    border.width: active ? 1 : 0
    border.color: root.theme.accentPrimary
    Behavior on color { ColorAnimation { duration: 120 } }

    Row {
      id: row
      anchors.centerIn: parent
      spacing: 6
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: btn.icon
        color: root.theme.accentPrimary
        font.pixelSize: 14
        font.family: root.font
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: btn.showName && btn.label !== ""
        text: btn.label
        color: root.theme.textPrimary
        font.pixelSize: 11
        font.family: root.font
      }
    }
    MouseArea {
      id: area
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      onClicked: mouse => {
        if (mouse.button === Qt.LeftButton) AtelierHost.toggle(btn.tab, btn, btn.screenName);
        else if (mouse.button === Qt.RightButton) AtelierHost.act(btn.rightAction);
        else AtelierHost.act(btn.middleAction);
      }
    }
  }

  Component {
    id: cAtelierButton
    AtelierBarButton {
      objectName: "aequalyn-atelier-button"
      tab: "themes"
      icon: "󰉦"
      label: root.theme && root.theme.wallpaperMode ? "Wallpaper" : (root.theme && root.theme.committed ? root.theme.committed.name : "")
      showName: AequalynSettings.atelierCfg.atelierShowName !== false
      rightAction: AequalynSettings.atelierCfg.atelierRightClick || "next-wallpaper"
      middleAction: AequalynSettings.atelierCfg.atelierMiddleClick || "random-wallpaper"
    }
  }

  Component {
    id: cLayoutsButton
    AtelierBarButton {
      objectName: "aequalyn-layouts-button"
      tab: "layouts"
      icon: "󰕰"
      label: {
        const l = LayoutService.find(LayoutService.layoutOf(LayoutService.focusedWorkspace));
        return l ? l.name : "";
      }
      showName: AequalynSettings.atelierCfg.layoutsShowName !== false
      rightAction: AequalynSettings.atelierCfg.layoutsRightClick || "next-layout"
      middleAction: AequalynSettings.atelierCfg.layoutsMiddleClick || "prev-layout"
    }
  }

  // Fixed left button: Arch logo that opens the app launcher (SUPER+D).
  // Kept outside the reorderable plugin list so it always anchors the left side.
  Component {
    id: cAppsMenu
    Rectangle {
      id: appsMenu
      objectName: "apps-menu"
      Accessible.role: Accessible.Button
      Accessible.name: "apps-menu"
      width: 28; height: 24
      radius: 8
      color: appsMenuHover.containsMouse ? root.theme.bgSelected : "transparent"
      Image {
        anchors.centerIn: parent
        source: "root:/assets/apps-menu.svg"
        sourceSize.width: 16; sourceSize.height: 16
        width: 16; height: 16
        fillMode: Image.PreserveAspectFit
        smooth: true
      }
      MouseArea {
        id: appsMenuHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.openLauncher()
      }
    }
  }

  // Fixed right button: opens Aequalyn settings (SUPER+,).
  Component {
    id: cSettingsButton
    Rectangle {
      id: settingsButton
      objectName: "aequalyn-settings-button"
      Accessible.role: Accessible.Button
      Accessible.name: "Aequalyn settings"
      width: 28; height: 24
      radius: 8
      color: settingsHover.containsMouse ? root.theme.bgSelected : root.chipColor
      Text {
        anchors.centerIn: parent
        text: "⚙"
        color: root.theme.accentPrimary
        font.pixelSize: 14
        font.family: root.font
      }
      MouseArea {
        id: settingsHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.openSettings()
      }
    }
  }

  Component {
    id: cScreenRecorder
    Rectangle {
      id: recButton
      objectName: "aequalyn-screenrecorder-button"
      Accessible.role: Accessible.Button
      Accessible.name: root.recordingActive ? "Stop recording" : "Start recording"
      height: 24
      width: 26
      radius: 12
      color: root.recordingActive ? root.theme.accentRed
           : (recHover.containsMouse ? root.theme.bgSelected : root.chipColor)
      Text {
        anchors.centerIn: parent
        text: root.recordingActive ? "󰑊" : "󰻂"
        color: root.recordingActive ? root.theme.bgBase : root.theme.textPrimary
        font.pixelSize: 14
        font.family: root.font
      }
      Rectangle {
        visible: root.recordingActive
        anchors.centerIn: parent
        width: 20; height: 20; radius: 10
        color: "transparent"
        border.color: root.theme.bgBase
        border.width: 0
      }
      MouseArea {
        id: recHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggleRecording()
      }
    }
  }

  Component {
    id: cScreenshot
    Rectangle {
      id: shotButton
      objectName: "aequalyn-screenshot-button"
      Accessible.role: Accessible.Button
      Accessible.name: "Take region screenshot"
      height: 24
      width: 26
      radius: 12
      color: shotHover.containsMouse ? root.theme.bgSelected : root.chipColor
      Text {
        anchors.centerIn: parent
        text: "󰹑"
        color: root.theme.textPrimary
        font.pixelSize: 14
        font.family: root.font
      }
      MouseArea {
        id: shotHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.takeScreenshot()
      }
    }
  }

  Component {
    id: cPower
    Rectangle {
      id: powerButton
      objectName: "aequalyn-power-button"
      Accessible.role: Accessible.Button
      Accessible.name: "Power menu"
      height: 24
      width: 26
      radius: 12
      color: powerHover.containsMouse ? root.theme.bgSelected : root.chipColor
      Text {
        anchors.centerIn: parent
        text: "󰐥"
        color: powerHover.containsMouse ? root.theme.accentRed : root.theme.textPrimary
        font.pixelSize: 14
        font.family: root.font
      }
      MouseArea {
        id: powerHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.openPowerMenu()
      }
    }
  }


  Component {
    id: cCaffeine
    Rectangle {
      id: caffeineButton
      objectName: "aequalyn-caffeine-button"
      Accessible.role: Accessible.Button
      Accessible.name: CaffeineService.active ? "Caffeine on (idle inhibited)" : "Caffeine off"
      height: 24
      width: 26
      radius: 12
      color: caffeineHover.containsMouse ? root.theme.bgSelected : root.chipColor
      Text {
        anchors.centerIn: parent
        text: CaffeineService.active ? "" : "󰾪"
        color: CaffeineService.active ? root.theme.accentOrange : root.theme.textMuted
        font.pixelSize: 14
        font.family: root.font
      }
      MouseArea {
        id: caffeineHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: CaffeineService.toggle()
      }
    }
  }

  Component { id: cEmpty; Item { width: 0; height: 24 } }

  // ---- plugin widgets ---------------------------------------------------
  Component {
    id: cClock
    Rectangle {
      height: 24
      width: timeDate.width + 16
      radius: 12
      color: root.chipColor
      Row {
        id: timeDate
        anchors.centerIn: parent
        spacing: 8
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: Time.timeString
          color: root.theme.textPrimary
          font.pixelSize: 12
          font.family: root.font
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: Time.dateString
          color: root.theme.textSecondary
          font.pixelSize: 12
          font.family: root.font
        }
      }
    }
  }

  Component {
    id: cWorkspaces
    Item {
      implicitWidth: wsRow.implicitWidth
      implicitHeight: 24
      Process { id: wsScrollProc; running: false }
      Row {
        id: wsRow
        anchors.fill: parent
        spacing: 4
        Repeater {
          model: Hyprland.workspaces
          Rectangle {
            id: wsPill
            required property var modelData
            property bool urgentBlink: false
            width: modelData.focused ? 32 : 24
            height: 24
            radius: 12
            color: modelData.focused ? root.theme.accentPrimary :
                   modelData.urgent && urgentBlink ? root.theme.accentRed : root.chipColor
            Behavior on color { ColorAnimation { duration: 150 } }
            SequentialAnimation {
              loops: Animation.Infinite
              running: wsPill.modelData.urgent && !wsPill.modelData.focused
              PropertyAction { target: wsPill; property: "urgentBlink"; value: true }
              PauseAnimation { duration: 500 }
              PropertyAction { target: wsPill; property: "urgentBlink"; value: false }
              PauseAnimation { duration: 500 }
              onStopped: wsPill.urgentBlink = false
            }
            Text {
              anchors.centerIn: parent
              text: wsPill.modelData.id
              color: wsPill.modelData.focused ? root.theme.bgBase : root.theme.textPrimary
              font.pixelSize: 11
              font.family: root.font
              font.bold: wsPill.modelData.focused
            }
            MouseArea {
              anchors.fill: parent
              onClicked: wsPill.modelData.activate()
              onWheel: (wheel) => {
                const dir = wheel.angleDelta.y > 0 ? "e-1" : "e+1";
                wsScrollProc.command = ["hyprctl", "dispatch",
                  "hl.dsp.focus({ workspace = \"" + dir + "\" })"];
                wsScrollProc.running = true;
              }
            }
            Behavior on width { NumberAnimation { duration: 150 } }
          }
        }
      }
    }
  }

  Component {
    id: cMedia
    Rectangle {
      height: 24
      width: nowPlayingContent.width + 16
      radius: 12
      color: root.chipColor
      visible: root.activePlayer !== null
      Row {
        id: nowPlayingContent
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 8
        spacing: 6
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: root.activePlayer && root.activePlayer.isPlaying ? "󰐊" : "󰏤"
          color: root.theme.accentPrimary
          font.pixelSize: 14
          font.family: root.font
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: {
            if (!root.activePlayer) return "";
            const artist = root.activePlayer.trackArtist || "";
            const title = root.activePlayer.trackTitle || "";
            return artist ? artist + " - " + title : title;
          }
          color: root.theme.textPrimary
          font.pixelSize: 11
          font.family: root.font
          elide: Text.ElideRight
          width: Math.min(implicitWidth, 200)
        }
      }
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activePlayer.togglePlaying()
      }
    }
  }

  Component {
    id: cTitle
    Item {
      implicitWidth: Math.min(titleText.implicitWidth, 360)
      implicitHeight: 24
      width: implicitWidth
      Text {
        id: titleText
        anchors.fill: parent
        text: Hyprland.activeToplevel ? Hyprland.activeToplevel.title : ""
        color: root.theme.textPrimary
        font.pixelSize: 12
        font.family: root.font
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
      }
    }
  }

  Component {
    id: cVolume
    Rectangle {
      height: 24
      width: volContent.width + 12
      radius: 12
      color: root.chipColor
      Row {
        id: volContent
        anchors.centerIn: parent
        spacing: 6
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: {
            const sink = Pipewire.defaultAudioSink;
            if (!sink || !sink.audio || sink.audio.muted || sink.audio.volume <= 0) return "󰖁";
            if (sink.audio.volume < 0.33) return "󰕿";
            if (sink.audio.volume < 0.66) return "󰖀";
            return "󰕾";
          }
          color: {
            const sink = Pipewire.defaultAudioSink;
            if (!sink || !sink.audio || sink.audio.muted) return root.theme.textMuted;
            return root.theme.accentPrimary;
          }
          font.pixelSize: 14
          font.family: root.font
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: {
            const sink = Pipewire.defaultAudioSink;
            if (!sink || !sink.audio) return "–";
            if (sink.audio.muted) return "Mute";
            return Math.round(sink.audio.volume * 100) + "%";
          }
          color: root.theme.textPrimary
          font.pixelSize: 11
          font.family: root.font
        }
      }
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onClicked: {
          const sink = Pipewire.defaultAudioSink;
          if (sink && sink.audio) sink.audio.muted = !sink.audio.muted;
        }
        onWheel: (wheel) => {
          const sink = Pipewire.defaultAudioSink;
          if (!sink || !sink.audio) return;
          const delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
          sink.audio.volume = Math.max(0, Math.min(1.5, sink.audio.volume + delta));
        }
      }
    }
  }

  Component {
    id: cBrightness
    Rectangle {
      height: 24
      width: brightContent.width + 12
      radius: 12
      color: root.chipColor
      visible: brightnessFile.path !== ""
      Row {
        id: brightContent
        anchors.centerIn: parent
        spacing: 6
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "󰃠"
          color: root.theme.accentOrange
          font.pixelSize: 14
          font.family: root.font
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: Math.round(root.brightnessValue * 100) + "%"
          color: root.theme.textPrimary
          font.pixelSize: 11
          font.family: root.font
        }
      }
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onWheel: (wheel) => {
          brightnessSetProc.command = wheel.angleDelta.y > 0
            ? ["brightnessctl", "set", "5%+"]
            : ["brightnessctl", "set", "5%-"];
          brightnessSetProc.running = true;
        }
      }
    }
  }

  Component {
    id: cCpu
    Rectangle {
      height: 24
      width: cpuContent.width + 12
      radius: 12
      color: root.chipColor
      Row {
        id: cpuContent
        anchors.centerIn: parent
        spacing: 6
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "󰻠"
          color: root.theme.accentOrange
          font.pixelSize: 14
          font.family: root.font
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: SystemInfo.cpuUsage
          color: root.theme.textPrimary
          font.pixelSize: 11
          font.family: root.font
        }
      }
    }
  }

  Component {
    id: cNetwork
    Rectangle {
      id: netPill
      height: 24
      width: netContent.width + 12
      radius: 12
      color: root.chipColor

      Row {
        id: netContent
        anchors.centerIn: parent
        spacing: 6
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: {
            if (SystemInfo.networkType === "ethernet") return "󰈀"
            if (SystemInfo.networkType === "wifi") return "󰖩"
            return "󰖪"
          }
          color: SystemInfo.networkType === "disconnected" ? root.theme.textMuted : root.theme.accentGreen
          font.pixelSize: 14
          font.family: root.font
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: SystemInfo.networkInfo
          color: root.theme.textPrimary
          font.pixelSize: 11
          font.family: root.font
        }
      }

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
          if (mouse.button === Qt.RightButton) {
            settingsProc.command = ["qs", "ipc", "call", "aequalyn", "wifi"]
            settingsProc.running = true
          } else {
            const w = netPill.QsWindow.window;
            if (w) {
              wifiPopup.anchor.window = w;
              const r = netPill.mapToItem(null, 0, netPill.height);
              wifiPopup.anchor.rect.x = r.x;
              wifiPopup.anchor.rect.y = r.y;
              wifiPopup.anchor.rect.width = netPill.width;
              wifiPopup.anchor.rect.height = 1;
            }
            root.wifiPopupVisible = !root.wifiPopupVisible
          }
        }
      }

      PopupWindow {
        id: wifiPopup
        visible: root.wifiPopupVisible
        Shortcut {
          sequence: "Escape"
          onActivated: root.wifiPopupVisible = false
        }
        implicitWidth: 320
        implicitHeight: 360
        color: "transparent"

        anchor.window: netPill.QsWindow.window
        anchor.rect.x: netPill.mapToItem(null, 0, 0).x
        anchor.rect.y: netPill.QsWindow.window ? netPill.QsWindow.window.height : 32
        anchor.rect.width: netPill.width
        anchor.rect.height: 1
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.adjustment: PopupAdjustment.Slide

        onVisibleChanged: if (root.wifiPopupVisible) WifiService.scan()

        Rectangle {
          id: wifiPopupBg
          anchors.fill: parent
          color: root.theme.bgBase
          border.color: root.theme.bgBorder
          border.width: 1
          radius: 12

          ColumnLayout {
            id: wifiContent
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8
          width: parent.width

          RowLayout {
            Layout.fillWidth: true
            Text {
              text: WifiService.available ? (WifiService.wifiEnabled ? "Wi-Fi on" : "Wi-Fi off") : "No adapter"
              color: root.theme.textPrimary
              font.pixelSize: 12
              font.family: root.font
              Layout.fillWidth: true
            }
            Rectangle {
              implicitWidth: 52
              implicitHeight: 24
              radius: 6
              color: root.theme.bgSelected
              border.color: root.theme.bgBorder
              border.width: 1
              Text {
                anchors.centerIn: parent
                text: WifiService.wifiEnabled ? "Off" : "On"
                color: root.theme.textPrimary
                font.pixelSize: 10
                font.family: root.font
              }
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: WifiService.toggleWifi()
              }
            }
            Rectangle {
              implicitWidth: 52
              implicitHeight: 24
              radius: 6
              color: root.theme.bgSelected
              border.color: root.theme.bgBorder
              border.width: 1
              Text {
                anchors.centerIn: parent
                text: WifiService.scanning ? "…" : "Scan"
                color: root.theme.textPrimary
                font.pixelSize: 10
                font.family: root.font
              }
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: WifiService.scan()
              }
            }
            Rectangle {
              implicitWidth: 24
              implicitHeight: 24
              radius: 6
              color: root.theme.bgSelected
              border.color: root.theme.bgBorder
              border.width: 1
              Text { anchors.centerIn: parent; text: "✕"; color: root.theme.textPrimary; font.pixelSize: 10; font.family: root.font }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.wifiPopupVisible = false }
            }
          }

          Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.bgBorder }

          Text {
            visible: WifiService.networkCount === 0
            text: "No networks found"
            color: root.theme.textMuted
            font.pixelSize: 11
            font.family: root.font
          }

          ScrollView {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(260, WifiService.networkCount * 44 + 8)
            clip: true
            ColumnLayout {
              width: parent.width
              spacing: 4
              Repeater {
                model: WifiService.networks
                Rectangle {
                  required property var modelData
                  Layout.fillWidth: true
                  implicitHeight: 40
                  radius: 8
                  color: root.theme.bgSurface
                  border.color: modelData.connected ? root.theme.accentPrimary : root.theme.bgBorder
                  border.width: 1
                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8
                    ColumnLayout {
                      Layout.fillWidth: true
                      spacing: 0
                      Text {
                        Layout.fillWidth: true
                        text: modelData.name || "(hidden)"
                        color: root.theme.textPrimary
                        font.pixelSize: 11
                        font.family: root.font
                        elide: Text.ElideRight
                      }
                      Text {
                        Layout.fillWidth: true
                        text: Math.round(modelData.signalStrength || 0) + "% · " + WifiService.securityText(modelData.security)
                        color: root.theme.textMuted
                        font.pixelSize: 9
                        font.family: root.font
                      }
                    }
                    Rectangle {
                      implicitWidth: 64
                      implicitHeight: 22
                      radius: 6
                      color: connHover.containsMouse ? root.theme.accentPrimary : root.theme.bgSelected
                      border.color: root.theme.bgBorder
                      border.width: 1
                      Text {
                        anchors.centerIn: parent
                        text: modelData.connected ? "Disconnect" : "Connect"
                        color: connHover.containsMouse ? root.theme.bgBase : root.theme.textPrimary
                        font.pixelSize: 9
                        font.family: root.font
                      }
                      MouseArea {
                        id: connHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          if (modelData.connected) {
                            WifiService.disconnectNetwork(modelData)
                          } else if (WifiService.requiresCredentials(modelData.security) && !modelData.known) {
                            // fall back to settings for password entry
                            root.wifiPopupVisible = false
                            settingsProc.command = ["qs", "ipc", "call", "aequalyn", "wifi"]
                            settingsProc.running = true
                          } else {
                            WifiService.connectNetwork(modelData)
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
    }
  }

  // Compact Bluetooth pill: icon only (plus a dot when a device is
  // connected). Full status is in the tooltip / Settings -> Bluetooth.
  Component {
    id: cBluetooth
    Rectangle {
      id: btPill
      height: 24
      width: 26
      radius: 12
      color: btHover.containsMouse ? root.theme.bgSelected : root.chipColor
      Accessible.role: Accessible.Button
      Accessible.name: BluetoothService.connectedName !== ""
          ? "Bluetooth: connected to " + BluetoothService.connectedName
          : (BluetoothService.powered ? "Bluetooth on" : "Bluetooth off")

      Text {
        anchors.centerIn: parent
        text: "󰂯"
        color: BluetoothService.powered ? root.theme.accentCyan : root.theme.textMuted
        font.pixelSize: 14
        font.family: root.font
      }
      Rectangle {
        visible: BluetoothService.connectedName !== ""
        width: 6; height: 6; radius: 3
        color: root.theme.accentGreen
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 3
      }

      // Hover tooltip with the full state / connected device name.
      Rectangle {
        visible: btHover.containsMouse
        anchors.top: parent.bottom
        anchors.topMargin: 6
        anchors.horizontalCenter: parent.horizontalCenter
        width: btTip.implicitWidth + 16
        height: 24
        radius: 6
        color: root.theme.bgBase
        border.color: root.theme.bgBorder
        border.width: 1
        z: 50
        Text {
          id: btTip
          anchors.centerIn: parent
          text: !BluetoothService.available ? "No Bluetooth adapter"
              : BluetoothService.connectedName !== "" ? BluetoothService.connectedName
              : BluetoothService.powered ? "Bluetooth on" : "Bluetooth off"
          color: root.theme.textPrimary
          font.pixelSize: 10
          font.family: root.font
        }
      }

      MouseArea {
        id: btHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => {
          if (mouse.button === Qt.RightButton) {
            settingsProc.command = ["qs", "ipc", "call", "aequalyn", "bluetooth"]
            settingsProc.running = true
          } else {
            BluetoothService.togglePower()
          }
        }
      }
    }
  }

  Component {
    id: cBattery
    Rectangle {
      height: 24
      width: battContent.width + 12
      radius: 12
      color: root.chipColor
      readonly property color batteryColor: {
        if (SystemInfo.batteryCharging) return root.theme.accentGreen;
        if (SystemInfo.batteryLevelRaw > 20) return root.theme.batteryGood;
        if (SystemInfo.batteryLevelRaw > 10) return root.theme.batteryWarning;
        return root.theme.batteryCritical;
      }
      Row {
        id: battContent
        anchors.centerIn: parent
        spacing: 6
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: SystemInfo.batteryIcon
          color: parent.parent.batteryColor
          font.pixelSize: 14
          font.family: root.font
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: SystemInfo.batteryLevel
          color: root.theme.textPrimary
          font.pixelSize: 11
          font.family: root.font
        }
      }
    }
  }

  Component {
    id: cTemperature
    Rectangle {
      height: 24
      width: tempContent.width + 12
      radius: 12
      color: root.chipColor
      Row {
        id: tempContent
        anchors.centerIn: parent
        spacing: 6
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "󰔏"
          color: root.theme.accentRed
          font.pixelSize: 14
          font.family: root.font
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: SystemInfo.temperature
          color: root.theme.textPrimary
          font.pixelSize: 11
          font.family: root.font
        }
      }
    }
  }

  Component {
    id: cTray
    Rectangle {
      implicitHeight: 24
      implicitWidth: trayIcons.implicitWidth + 8
      radius: 12
      color: root.chipColor
      RowLayout {
        id: trayIcons
        anchors.centerIn: parent
        spacing: 2
        Repeater {
          model: SystemTray.items
          MouseArea {
            id: trayDelegate
            required property SystemTrayItem modelData
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: (mouse) => {
              if (mouse.button === Qt.LeftButton) modelData.activate()
              else if (mouse.button === Qt.RightButton && modelData.hasMenu) menuAnchor.open()
              else if (mouse.button === Qt.MiddleButton) modelData.secondaryActivate()
            }
            IconImage {
              anchors.centerIn: parent
              source: trayDelegate.modelData.icon
              implicitSize: 16
            }
            QsMenuAnchor {
              id: menuAnchor
              menu: trayDelegate.modelData.menu
              anchor.window: trayDelegate.QsWindow.window
              anchor.adjustment: PopupAdjustment.Flip
              anchor.onAnchoring: {
                const window = trayDelegate.QsWindow.window;
                const widgetRect = window.contentItem.mapFromItem(
                  trayDelegate, 0, trayDelegate.height,
                  trayDelegate.width, trayDelegate.height);
                menuAnchor.anchor.rect = widgetRect;
              }
            }
          }
        }
      }
    }
  }

  // ---- windows (one bar per screen) --------------------------------------
  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: barWindow
      required property var modelData
      screen: modelData
      visible: root.barVisible

      anchors { top: true; left: true; right: true }
      implicitHeight: root.windowThickness
      // styled: the shapes are the background; plain: one band in the theme
      color: root.styled ? "transparent"
           : Qt.rgba(root.theme.bgBase.r, root.theme.bgBase.g, root.theme.bgBase.b, AequalynSettings.barOpacity / 100)

      // the strip the shapes and widgets live in (below the float gap)
      Item {
        id: band
        x: 0
        y: root.floatGap
        width: parent.width
        height: root.bandThickness

        property string dragRegion: ""
        property int dragIndex: -1
        property string dragPlugin: ""
        property string hoverRegion: ""
        property int hoverIndex: -1
        property string dragGhostLabel: ""
        readonly property bool dragging: dragRegion !== ""

        // Floating drag ghost
        Rectangle {
          id: barDragGhost
          visible: band.dragging
          z: 1000
          width: Math.max(120, ghostText.implicitWidth + 24)
          height: 26
          radius: 7
          color: root.theme.bgSelected
          border.color: root.theme.accentPrimary
          border.width: 1
          Text {
            id: ghostText
            anchors.centerIn: parent
            text: band.dragGhostLabel
            color: root.theme.textPrimary
            font.pixelSize: 11
            font.family: root.font
          }
        }        BarDecor {
          id: decor
          anchors.fill: parent
          visible: root.styled
          z: -1
          theme: root.theme
          look: root.look
          barSize: root.barSize
          sections: [leftSection, centerSection, rightSection]
          regionNames: ["left", "center", "right"]
        }

        // Three sections (left / center / right) so plugins don't spread across
        // the whole width. Their order and contents come from AequalynSettings.
        Item {
          anchors.fill: parent
          anchors.leftMargin: root.sectionMargin
          anchors.rightMargin: root.sectionMargin

          // Each section is a horizontally-flickable strip so too many plugins
          // in one region (e.g. the right side) scroll instead of overlapping
          // the centre and becoming unselectable.
          Flickable {
            id: leftFlick
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width / 3
            height: parent.height
            clip: true
            contentWidth: leftSection.width
            contentHeight: parent.height
            flickableDirection: Flickable.HorizontalFlick
            interactive: AequalynSettings.barLeft.length > 0
            Row {
              id: leftSection
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              spacing: root.widgetSpacing
              Repeater {
                model: AequalynSettings.barLeft
                delegate: Item {
                  id: leftWrap
                  required property string modelData
                  required property int index
                  width: loader.item ? ((loader.item.implicitWidth > 0 ? loader.item.implicitWidth : (loader.item.width > 0 ? loader.item.width : 24)) + 8) : 32
                  height: band.height
                  opacity: (band.dragging && band.dragRegion === "left" && band.dragIndex === index)
                           ? 0.35 : (AequalynSettings.pluginVisible(modelData) ? 1.0 : 0.0)
                  visible: AequalynSettings.pluginVisible(modelData) || (band.dragging && band.dragRegion === "left" && band.dragIndex === index)

                  Loader {
                    id: loader
                    anchors.centerIn: parent
                    property bool hovered: hh.hovered
                    HoverHandler { id: hh }
                    sourceComponent: root.componentFor(modelData)
                    visible: AequalynSettings.pluginVisible(modelData)
                  }

                  DragHandler {
                    id: leftDrag
                    target: null
                    onActiveChanged: {
                      if (active) {
                        band.dragRegion = "left"
                        band.dragIndex = index
                        band.dragPlugin = modelData
                        band.hoverRegion = "left"
                        band.hoverIndex = index
                        band.dragGhostLabel = AequalynSettings.pluginLabels[modelData] || modelData
                        leftFlick.interactive = false
                        centerFlick.interactive = false
                        rightFlick.interactive = false
                      } else {
                        // finish
                        if (band.hoverRegion === "") {
                          AequalynSettings.removeBarPlugin(band.dragRegion, band.dragIndex)
                        } else if (band.hoverRegion !== "" && !(band.hoverRegion === band.dragRegion && band.hoverIndex === band.dragIndex)) {
                          AequalynSettings.moveBarPlugin(band.dragRegion, band.dragIndex, band.hoverRegion, band.hoverIndex)
                        }
                        band.dragRegion = ""
                        band.dragIndex = -1
                        band.dragPlugin = ""
                        band.hoverRegion = ""
                        band.hoverIndex = -1
                        band.dragGhostLabel = ""
                        barDragGhost.visible = false
                        leftFlick.interactive = AequalynSettings.barLeft.length > 0
                        centerFlick.interactive = AequalynSettings.barCenter.length > 0
                        rightFlick.interactive = AequalynSettings.barRight.length > 0
                      }
                    }
                    onCentroidChanged: {
                      if (!active) return
                      const p = centroid.position
                      // position in band coords
                      const bandPos = leftWrap.mapToItem(band, p.x, p.y)
                      barDragGhost.x = bandPos.x - barDragGhost.width / 2
                      barDragGhost.y = bandPos.y - barDragGhost.height / 2
                      // target region by x
                      if (bandPos.y < -20 || bandPos.y > band.height + 20) {
                        band.hoverRegion = ""
                        band.hoverIndex = -1
                      } else {
                      let tr = "left"
                      const third = band.width / 3
                      if (bandPos.x < third) tr = "left"
                      else if (bandPos.x < third * 2) tr = "center"
                      else tr = "right"
                      // index within section
                      const section = (tr === "left") ? leftSection : (tr === "center" ? centerSection : rightSection)
                      const sp = band.mapToItem(section, bandPos.x, bandPos.y)
                      let idx = 0
                      for (let i = 0; i < section.children.length; i++) {
                        const c = section.children[i]
                        if (sp.x > c.x + c.width / 2) idx = i + 1
                      }
                      const len = (tr === "left") ? AequalynSettings.barLeft.length
                               : (tr === "center") ? AequalynSettings.barCenter.length
                               : AequalynSettings.barRight.length
                      idx = Math.max(0, Math.min(len, idx))
                      band.hoverRegion = tr
                      band.hoverIndex = idx
                      }
                    }
                  }
                }
              }
            }
          }

          Flickable {
            id: centerFlick
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width / 3
            height: parent.height
            clip: true
            contentWidth: centerSection.width
            contentHeight: parent.height
            flickableDirection: Flickable.HorizontalFlick
            interactive: AequalynSettings.barCenter.length > 0
            Row {
              id: centerSection
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.verticalCenter: parent.verticalCenter
              spacing: root.widgetSpacing
              Repeater {
                model: AequalynSettings.barCenter
                delegate: Item {
                  id: centerWrap
                  required property string modelData
                  required property int index
                  width: loader.item ? ((loader.item.implicitWidth > 0 ? loader.item.implicitWidth : (loader.item.width > 0 ? loader.item.width : 24)) + 8) : 32
                  height: band.height
                  opacity: (band.dragging && band.dragRegion === "center" && band.dragIndex === index)
                           ? 0.35 : (AequalynSettings.pluginVisible(modelData) ? 1.0 : 0.0)
                  visible: AequalynSettings.pluginVisible(modelData) || (band.dragging && band.dragRegion === "center" && band.dragIndex === index)

                  Loader {
                    id: loader
                    anchors.centerIn: parent
                    property bool hovered: hh.hovered
                    HoverHandler { id: hh }
                    sourceComponent: root.componentFor(modelData)
                    visible: AequalynSettings.pluginVisible(modelData)
                  }

                  DragHandler {
                    id: centerDrag
                    target: null
                    onActiveChanged: {
                      if (active) {
                        band.dragRegion = "center"
                        band.dragIndex = index
                        band.dragPlugin = modelData
                        band.hoverRegion = "center"
                        band.hoverIndex = index
                        band.dragGhostLabel = AequalynSettings.pluginLabels[modelData] || modelData
                        leftFlick.interactive = false
                        centerFlick.interactive = false
                        rightFlick.interactive = false
                      } else {
                        if (band.hoverRegion === "") {
                          AequalynSettings.removeBarPlugin(band.dragRegion, band.dragIndex)
                        } else if (band.hoverRegion !== "" && !(band.hoverRegion === band.dragRegion && band.hoverIndex === band.dragIndex)) {
                          AequalynSettings.moveBarPlugin(band.dragRegion, band.dragIndex, band.hoverRegion, band.hoverIndex)
                        }
                        band.dragRegion = ""
                        band.dragIndex = -1
                        band.dragPlugin = ""
                        band.hoverRegion = ""
                        band.hoverIndex = -1
                        band.dragGhostLabel = ""
                        barDragGhost.visible = false
                        leftFlick.interactive = AequalynSettings.barLeft.length > 0
                        centerFlick.interactive = AequalynSettings.barCenter.length > 0
                        rightFlick.interactive = AequalynSettings.barRight.length > 0
                      }
                    }
                    onCentroidChanged: {
                      if (!active) return
                      const p = centroid.position
                      const bandPos = centerWrap.mapToItem(band, p.x, p.y)
                      barDragGhost.x = bandPos.x - barDragGhost.width / 2
                      barDragGhost.y = bandPos.y - barDragGhost.height / 2
                      if (bandPos.y < -20 || bandPos.y > band.height + 20) {
                        band.hoverRegion = ""
                        band.hoverIndex = -1
                      } else {
                      let tr = "left"
                      const third = band.width / 3
                      if (bandPos.x < third) tr = "left"
                      else if (bandPos.x < third * 2) tr = "center"
                      else tr = "right"
                      const section = (tr === "left") ? leftSection : (tr === "center" ? centerSection : rightSection)
                      const sp = band.mapToItem(section, bandPos.x, bandPos.y)
                      let idx = 0
                      for (let i = 0; i < section.children.length; i++) {
                        const c = section.children[i]
                        if (sp.x > c.x + c.width / 2) idx = i + 1
                      }
                      const len = (tr === "left") ? AequalynSettings.barLeft.length
                               : (tr === "center") ? AequalynSettings.barCenter.length
                               : AequalynSettings.barRight.length
                      idx = Math.max(0, Math.min(len, idx))
                      band.hoverRegion = tr
                      band.hoverIndex = idx
                      }
                    }
                  }
                }
              }
            }
          }

          Flickable {
            id: rightFlick
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width / 3
            height: parent.height
            clip: true
            contentWidth: rightSection.width
            contentHeight: parent.height
            flickableDirection: Flickable.HorizontalFlick
            interactive: AequalynSettings.barRight.length > 0
            Row {
              id: rightSection
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: root.widgetSpacing
              Repeater {
                model: AequalynSettings.barRight
                delegate: Item {
                  id: rightWrap
                  required property string modelData
                  required property int index
                  width: loader.item ? ((loader.item.implicitWidth > 0 ? loader.item.implicitWidth : (loader.item.width > 0 ? loader.item.width : 24)) + 8) : 32
                  height: band.height
                  opacity: (band.dragging && band.dragRegion === "right" && band.dragIndex === index)
                           ? 0.35 : (AequalynSettings.pluginVisible(modelData) ? 1.0 : 0.0)
                  visible: AequalynSettings.pluginVisible(modelData) || (band.dragging && band.dragRegion === "right" && band.dragIndex === index)

                  Loader {
                    id: loader
                    anchors.centerIn: parent
                    property bool hovered: hh.hovered
                    HoverHandler { id: hh }
                    sourceComponent: root.componentFor(modelData)
                    visible: AequalynSettings.pluginVisible(modelData)
                  }

                  DragHandler {
                    id: rightDrag
                    target: null
                    onActiveChanged: {
                      if (active) {
                        band.dragRegion = "right"
                        band.dragIndex = index
                        band.dragPlugin = modelData
                        band.hoverRegion = "right"
                        band.hoverIndex = index
                        band.dragGhostLabel = AequalynSettings.pluginLabels[modelData] || modelData
                        leftFlick.interactive = false
                        centerFlick.interactive = false
                        rightFlick.interactive = false
                      } else {
                        if (band.hoverRegion === "") {
                          AequalynSettings.removeBarPlugin(band.dragRegion, band.dragIndex)
                        } else if (band.hoverRegion !== "" && !(band.hoverRegion === band.dragRegion && band.hoverIndex === band.dragIndex)) {
                          AequalynSettings.moveBarPlugin(band.dragRegion, band.dragIndex, band.hoverRegion, band.hoverIndex)
                        }
                        band.dragRegion = ""
                        band.dragIndex = -1
                        band.dragPlugin = ""
                        band.hoverRegion = ""
                        band.hoverIndex = -1
                        band.dragGhostLabel = ""
                        barDragGhost.visible = false
                        leftFlick.interactive = AequalynSettings.barLeft.length > 0
                        centerFlick.interactive = AequalynSettings.barCenter.length > 0
                        rightFlick.interactive = AequalynSettings.barRight.length > 0
                      }
                    }
                    onCentroidChanged: {
                      if (!active) return
                      const p = centroid.position
                      const bandPos = rightWrap.mapToItem(band, p.x, p.y)
                      barDragGhost.x = bandPos.x - barDragGhost.width / 2
                      barDragGhost.y = bandPos.y - barDragGhost.height / 2
                      if (bandPos.y < -20 || bandPos.y > band.height + 20) {
                        band.hoverRegion = ""
                        band.hoverIndex = -1
                      } else {
                      let tr = "left"
                      const third = band.width / 3
                      if (bandPos.x < third) tr = "left"
                      else if (bandPos.x < third * 2) tr = "center"
                      else tr = "right"
                      const section = (tr === "left") ? leftSection : (tr === "center" ? centerSection : rightSection)
                      const sp = band.mapToItem(section, bandPos.x, bandPos.y)
                      let idx = 0
                      for (let i = 0; i < section.children.length; i++) {
                        const c = section.children[i]
                        if (sp.x > c.x + c.width / 2) idx = i + 1
                      }
                      const len = (tr === "left") ? AequalynSettings.barLeft.length
                               : (tr === "center") ? AequalynSettings.barCenter.length
                               : AequalynSettings.barRight.length
                      idx = Math.max(0, Math.min(len, idx))
                      band.hoverRegion = tr
                      band.hoverIndex = idx
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
