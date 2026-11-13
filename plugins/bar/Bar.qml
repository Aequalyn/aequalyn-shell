// Aequalyn's top bar: one per screen, in three regions (left, center, right). Which
// widgets sit where, and in what order, comes from AequalynSettings (barLeft / barCenter /
// barRight); you can drag them around on the bar itself. Each widget is its own file in
// widgets/ (see widgets/Widgets.js), placed by BarSlot in a BarSection, with the bar's
// shapes painted behind them by BarDecor. This file keeps what the widgets share: the
// theme, the look, brightness, recording and popup state, and the actions they call.
// IPC target "bar": toggle.
import Quickshell
import QtQuick
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import "root:/settings"
import  "../../style/Shapes.js" as Shapes
import  "../../style/BarLooks.js" as BarLooks

Scope {
  id: root
  property var theme: DefaultTheme {}
  property string font: "JetBrainsMono Nerd Font"
  property bool barVisible: true
  property bool wifiPopupVisible: false
  property bool powerProfileVisible: false
  // every screen has its own bar, but the popups above share one switch: they open only on
  // the screen they were opened from
  property var popupScreen: null
  // toggle a popup from screen `scr`; open on another screen, it moves there instead
  function togglePopup(open, scr) {
    const moving = open && root.popupScreen !== scr;
    root.popupScreen = scr;
    return moving ? true : !open;
  }
  property string currentPowerProfile: ""
  property var powerProfiles: []

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
  readonly property bool hasBacklight: brightnessFile.path !== ""
  // the Brightness widget's scroll wheel
  function stepBrightness(up) {
    brightnessSetProc.command = ["brightnessctl", "set", up ? "5%+" : "5%-"];
    brightnessSetProc.running = true;
  }

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
  // a page of the Aequalyn settings (wifi, bluetooth, ...): widgets' right click
  function openSettingsPage(page) {
    settingsProc.command = ["qs", "ipc", "call", "aequalyn", page];
    settingsProc.running = true;
  }
  function openPowerMenu() {
    powerProc.command = ["qs", "ipc", "call", "power", "toggle"];
    powerProc.running = true;
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
        // the slot being dragged. Dragging only counts while its handler is really active: if
        // the slot goes away mid-drag (its widget list changed) or a popup takes the pointer and
        // the release never arrives, the bar can't get stuck showing a drag
        property var dragSlot: null
        readonly property bool dragging: dragRegion !== "" && dragSlot !== null && dragSlot.dragActive === true

        // Dragging a widget: drop it in another place or region, or off the bar to remove it.
        // The drop reorders the Repeater models, which destroys the dragged slot, so everything
        // here lives on the band and the state is cleared before the move is applied.
        function startDrag(slot, region, index, plugin) {
          dragSlot = slot
          dragRegion = region
          dragIndex = index
          dragPlugin = plugin
          hoverRegion = region
          hoverIndex = index
          dragGhostLabel = AequalynSettings.pluginLabels[plugin] || plugin
        }
        function trackDrag(slot, pos) {
          const p = slot.mapToItem(band, pos.x, pos.y)
          barDragGhost.x = p.x - barDragGhost.width / 2
          barDragGhost.y = p.y - barDragGhost.height / 2
          if (p.y < -20 || p.y > band.height + 20) { hoverRegion = ""; hoverIndex = -1; return }
          const third = band.width / 3
          const region = p.x < third ? "left" : (p.x < third * 2 ? "center" : "right")
          const section = (region === "left" ? leftSec : (region === "center" ? centerSec : rightSec)).row
          const sp = band.mapToItem(section, p.x, p.y)
          // count widget slots only (the Row also holds its Repeater) and use their model index
          let idx = 0
          for (let i = 0; i < section.children.length; i++) {
            const c = section.children[i]
            if (c.index === undefined || !c.visible) continue
            if (sp.x > c.x + c.width / 2) idx = c.index + 1
          }
          const len = region === "left" ? AequalynSettings.barLeft.length
                    : region === "center" ? AequalynSettings.barCenter.length : AequalynSettings.barRight.length
          hoverRegion = region
          hoverIndex = Math.max(0, Math.min(len, idx))
        }
        function finishDrag() {
          const from = dragRegion, fromIndex = dragIndex, to = hoverRegion, toIndex = hoverIndex
          dragSlot = null
          dragRegion = ""
          dragIndex = -1
          dragPlugin = ""
          hoverRegion = ""
          hoverIndex = -1
          dragGhostLabel = ""
          if (from === "") return
          if (to === "") AequalynSettings.removeBarPlugin(from, fromIndex)
          else if (!(to === from && (toIndex === fromIndex || toIndex === fromIndex + 1)))
            AequalynSettings.moveBarPlugin(from, fromIndex, to, toIndex)
        }

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
        }

        BarDecor {
          id: decor
          anchors.fill: parent
          visible: root.styled
          z: -1
          theme: root.theme
          look: root.look
          barSize: root.barSize
          sections: [leftSec.row, centerSec.row, rightSec.row]
          // a widget scrolled out of its region gets no shape
          viewports: [leftSec, centerSec, rightSec]
          regionNames: ["left", "center", "right"]
        }

        // Three regions (left / center / right). Their order and contents come from
        // AequalynSettings (barLeft / barCenter / barRight). Each is as wide as its widgets,
        // up to a limit: its share of the bar set in Settings -> Bar (0 = no limit of its own) and the room
        // left before it would run into the next region. Past that it scrolls sideways.
        Item {
          id: regions
          anchors.fill: parent
          anchors.leftMargin: root.sectionMargin
          anchors.rightMargin: root.sectionMargin

          // the room kept free between two regions
          readonly property int gap: 12
          readonly property real sideMax: AequalynSettings.barSidePercent > 0 ? width * AequalynSettings.barSidePercent / 100 : width
          readonly property real centerMax: AequalynSettings.barCenterPercent > 0 ? width * AequalynSettings.barCenterPercent / 100 : width
          readonly property real leftNeed: leftSec.row.width
          readonly property real centerNeed: centerSec.row.width
          readonly property real rightNeed: rightSec.row.width
          // the center comes first and stays centered on the bar
          readonly property real centerW: centerNeed > 0 ? Math.max(0, Math.min(centerNeed, centerMax, width - 2 * gap)) : 0
          // with a center, each side gets the room on its half; without one, what the other side leaves
          function sideRoom(otherNeed) {
            if (centerW > 0) return Math.max(0, (width - centerW) / 2 - gap);
            return Math.max(0, width - gap - Math.min(otherNeed, sideMax, (width - gap) / 2));
          }
          readonly property real leftW: Math.min(leftNeed, sideMax, sideRoom(rightNeed))
          readonly property real rightW: Math.min(rightNeed, sideMax, sideRoom(leftNeed))

          BarSection {
            id: leftSec
            region: "left"; bar: root; band: band
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: regions.leftW
            height: parent.height
          }
          BarSection {
            id: centerSec
            region: "center"; bar: root; band: band
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: regions.centerW
            height: parent.height
          }
          BarSection {
            id: rightSec
            region: "right"; bar: root; band: band
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: regions.rightW
            height: parent.height
          }
        }
      }
    }
  }
}
