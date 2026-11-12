import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import "../style/Effects.js" as Fx
import "../style/Style.js" as Style
import "../style/Paint.js" as Paint

PanelWindow {
  id: win

  required property var svc
  property int idx: 0

  readonly property var cfg: svc.effective(idx)
  readonly property var pal: svc.palette(cfg)
  // pop-ups (menu, add app, previews) wear the shell's own theme, like the rest of Aequalyn
  readonly property var ui: svc.shellTheme
  readonly property string uiFont: "JetBrainsMono Nerd Font"

  // by category: a steady hue per app from its first category (dot + hover). other modes use the accent
  function toneFor(e) {
    if (cfg.style !== "category") return pal.ac;
    const cats = (e && e.categories) ? e.categories : [];
    const main = cats.filter(c => ["GTK", "Qt", "KDE", "GNOME", "Application"].indexOf(c) < 0)[0] || (e ? e.id : "");
    return Qt.hsla(svc.hueOf(main), 0.55, 0.68, 1);
  }
  readonly property bool hz: cfg.edge === "top" || cfg.edge === "bottom"
  // popup edges: the accent when the dock's line is in the accent, else a plain line
  function edgeColor(base) { return cfg.border === "accent" ? Qt.alpha(pal.ac, 0.8) : Qt.alpha(pal.fg, base) }
  readonly property int pad: 8
  readonly property int cell: cfg.size + 12
  readonly property int step: cell + 6
  readonly property int thick: cell + pad * 2
  // the icons can be bigger or smaller than the dock's size, but never past its outline:
  // at most the slot they sit in, a pixel short on each side
  readonly property int iconPx: Math.max(6, Math.min(cell - 2, Math.round(cfg.size * cfg.iconScale / 100)))
  // pointed or curled ends reach in: the icons start this much further along
  readonly property int endRoom: svc.endRoom(cfg)
  readonly property int padAlong: pad + endRoom
  readonly property int along: (cfg.apps.length + 1) * step - 6 + padAlong * 2
  // room past the dock's inner side for its shadow, glow and ornaments
  readonly property int glow: Style.marginFor(cfg)

  // which monitor (its own choice or the primary)
  readonly property string mon: svc.monOf(cfg)
  screen: svc.screenFor(cfg)
  readonly property var screenNames: {
    const out = [];
    for (let k = 0; k < Quickshell.screens.length; k++) out.push(Quickshell.screens[k].name);
    return out;
  }
  readonly property bool monitorMissing: cfg.monitor !== "" && screenNames.indexOf(cfg.monitor) < 0

  readonly property int groupSize: Math.max(1, svc.docks.filter(d => svc.sameGroup(d, cfg)).length)
  readonly property int groupPos: svc.docks.slice(0, idx).filter(d => svc.sameGroup(d, cfg)).length

  readonly property var corners: svc.cornersFor(svc.docks, mon, cfg.edge)
  readonly property int usableW: Math.max(0, svc.edgeLen(mon, cfg.edge) - corners.start - corners.end)
  readonly property int slotStart: corners.start + Math.floor(usableW / groupSize) * groupPos
  readonly property int slotW: Math.max(thick, svc.slotLen(svc.docks, idx))

  readonly property int maxApps: svc.capacity(svc.docks, idx)
  readonly property bool full: cfg.apps.length >= maxApps
  readonly property int popEdge: ({ bottom: Edges.Top, top: Edges.Bottom, left: Edges.Right, right: Edges.Left })[cfg.edge]

  // margin lives inside the window: window = thickness + margin, dock inset by the margin.
  // keeps the auto-hide strip on the very edge and the reserved band the same size
  readonly property int margin: svc.marginOf(cfg.edge)
  readonly property int winThick: thick + margin
  // bar on this edge -> start behind its inner side so the dock sits above it, never over it
  readonly property int barOffset: svc.barOffset(mon, cfg.edge)

  // what colors/opacity/radius apply to
  property int scopeIdx: 0
  readonly property string scope: ["dock", "edge", "all"][scopeIdx]
  readonly property var scopeLabels: ["this dock", cfg.edge + " edge" + (screenNames.length > 1 ? " here" : ""), "all docks"]

  property int dragFrom: -1
  property int dragTo: -1
  property var hoverSlot: null
  property var previewSlot: null
  property var menuSlot: null
  property bool addOpen: false
  // settings live in Atelier -> Docks
  readonly property bool setOpen: false
  function openSettings() { closePopups(); svc.openSettings(idx, screen ? screen.name : ""); }
  property bool lingering: false
  // pointer on the dock or its strip (after the show delay)
  property bool hoverOpen: false
  readonly property bool popOpen: menuSlot !== null || addOpen || setOpen || previewPop.visible
  readonly property bool open: !cfg.autohide || hoverOpen || popOpen || lingering

  // auto-hide. hideT: 0 shown, 1 hidden. animated by hand (not a Behavior)
  // so showing and hiding can use different easings
  property real hideT: 0
  readonly property string effect: cfg.hideEffect || "slide"
  readonly property int strip: Math.max(1, Math.min(thick, cfg.revealStrip || 3))
  readonly property var fx: Fx.state(effect, hideT, winThick - strip)
  readonly property int speed: cfg.hideSpeed || 180
  // wave: delay between icons
  readonly property int waveStep: Math.max(12, Math.min(45, Math.round(speed / 4)))

  NumberAnimation {
    id: hideAnim
    target: win
    property: "hideT"
  }

  function animateHide() {
    hideAnim.stop();
    hideAnim.to = open ? 0 : 1;
    const springy = Fx.springy(effect);
    hideAnim.easing.type = open
      ? (springy ? Easing.OutBack : Easing.OutCubic)
      : (springy ? Easing.InBack : Easing.InCubic);
    hideAnim.easing.overshoot = effect === "pop" ? 2.2 : 1.7;
    hideAnim.duration = speed;
    hideAnim.start();
  }

  // tell the service if we're on screen (auto-hide docks only reserve while visible)
  onOpenChanged: { svc.setShown(idx, open); animateHide(); }
  onCfgChanged: svc.setShown(idx, open)
  Component.onCompleted: { hideT = open ? 0 : 1; svc.setShown(idx, open); }
  Component.onDestruction: svc.setShown(idx, false)

  anchors {
    top: cfg.edge === "top" || !hz
    bottom: cfg.edge === "bottom"
    left: cfg.edge === "left" || hz
    right: cfg.edge === "right"
  }
  margins {
    top: cfg.edge === "top" ? barOffset : (hz ? 0 : slotStart)
    bottom: cfg.edge === "bottom" ? barOffset : 0
    left: cfg.edge === "left" ? barOffset : (hz ? slotStart : 0)
    right: cfg.edge === "right" ? barOffset : 0
  }
  implicitWidth: hz ? slotW : winThick + glow
  implicitHeight: hz ? winThick + glow : slotW

  // the dock never reserves itself, the spacers in Service.qml do
  exclusionMode: ExclusionMode.Ignore
  exclusiveZone: 0
  color: "transparent"
  // only the dock catches the mouse. with auto-hide also a band on the edge:
  // the strip while hidden, and while shown everything from the edge to the dock,
  // so going from the strip onto the dock never leaves the window
  mask: Region {
    item: barHit
    Region { item: edgeHit }
  }

  WlrLayershell.namespace: "aequalyn-dock"
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: (addOpen || setOpen) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

  function windowsOf(e) {
    if (!e) return [];
    const raw = (e.id || "").toLowerCase();
    const id = raw.replace(/\.desktop$/, "");
    const last = id.split(".").pop();
    const sc = (e.startupClass || "").toLowerCase();
    return ToplevelManager.toplevels.values.filter(t => {
      const a = (t.appId || "").toLowerCase();
      if (!a) return false;
      if (a === raw || a === id || a === sc) return true;
      if (last && last !== id && a === last) return true;
      return false;
    });
  }

  // urgent windows (chat message, finished build...). hyprland clears the flag on focus.
  // service follows the urgent events; quickshell's own flag is a second source when it exists
  function isUrgent(t) {
    if (!t) return false;
    if (svc.classUrgent(t.appId)) return true;
    try {
      const list = Hyprland.toplevels.values;
      for (let k = 0; k < list.length; k++) {
        if (list[k].wayland === t && list[k].urgent) return true;
      }
    } catch (e) {}
    return false;
  }

  // all windows asking for attention, across all docks
  readonly property bool anyUrgent: {
    if (cfg.attention === "off") return false;
    for (let k = 0; k < cfg.apps.length; k++) {
      const ws = windowsOf((DesktopEntries.applications.values, DesktopEntries.byId(cfg.apps[k])));
      for (let j = 0; j < ws.length; j++) if (isUrgent(ws[j])) return true;
    }
    return false;
  }

  function activate(e, ws) {
    if (!e) return;
    if (ws.length === 0) { e.execute(); return; }
    // the one asking for attention first, then normal cycling
    const u = ws.find(t => isUrgent(t));
    if (u && cfg.attention !== "off") { u.activate(); return; }
    const i = ws.findIndex(t => t.activated);
    ws[(i + 1) % ws.length].activate();
  }

  function closePopups() { menuSlot = null; addOpen = false; previewSlot = null; }

  Timer { id: linger; interval: win.cfg.hideDelay; onTriggered: win.lingering = false }
  Timer { id: showDelay; interval: win.cfg.showDelay; onTriggered: win.hoverOpen = true }
  Timer {
    id: hoverDelay
    interval: 250
    onTriggered: {
      if (win.hoverSlot && win.hoverSlot.wins.length > 0 && win.menuSlot === null && !win.addOpen && !win.setOpen)
        win.previewSlot = win.hoverSlot;
    }
  }
  Timer {
    id: hoverLeave
    interval: 350
    onTriggered: { if (!previewHover.hovered) win.previewSlot = null; win.hoverSlot = null; }
  }

  HyprlandFocusGrab {
    windows: [menuPop, addPop]
    active: win.menuSlot !== null || win.addOpen || win.setOpen
    onCleared: { win.menuSlot = null; win.addOpen = false; }
  }

  Item {
    id: stage
    anchors.fill: parent

    // rest geometry (fully shown)
    readonly property real barAlong: win.cfg.stretch ? win.slotW : Math.min(win.along, win.slotW)
    readonly property real barW: win.hz ? barAlong : win.thick
    readonly property real barH: win.hz ? win.thick : barAlong
    function placeAlong(total) {
      return win.cfg.align === "start" ? 0 : win.cfg.align === "end" ? total - barAlong : (total - barAlong) / 2;
    }
    readonly property real restX: win.hz ? placeAlong(width) : (win.cfg.edge === "left" ? win.margin : width - barW - win.margin)
    readonly property real restY: win.hz ? (win.cfg.edge === "top" ? win.margin : height - barH - win.margin) : placeAlong(height)
    // +1 when "toward the edge" is +x/+y, else -1
    readonly property int outward: (win.cfg.edge === "bottom" || win.cfg.edge === "right") ? 1 : -1

    // hover anywhere on the input region
    HoverHandler {
      id: stageHover
      onHoveredChanged: {
        if (hovered) {
          linger.stop();
          if (!win.open && win.cfg.autohide && win.cfg.showDelay > 0) showDelay.restart();
          else win.hoverOpen = true;
        } else {
          showDelay.stop();
          if (win.hoverOpen) { win.lingering = true; linger.restart(); }
          win.hoverOpen = false;
        }
      }
    }

    // input region pieces (see mask)
    Item {
      id: barHit
      x: stage.restX; y: stage.restY
      width: win.open ? stage.barW : 0
      height: win.open ? stage.barH : 0
    }
    Item {
      id: edgeHit
      readonly property real band: win.cfg.autohide ? (win.open ? win.margin + win.strip : win.strip) : 0
      x: win.hz ? stage.restX : (win.cfg.edge === "left" ? 0 : stage.width - band)
      y: win.hz ? (win.cfg.edge === "top" ? 0 : stage.height - band) : stage.restY
      width: win.hz ? stage.barW : band
      height: win.hz ? band : stage.barH
    }

    // little pill on the edge while hidden so you know where it is. attention color when an app asks
    Rectangle {
      id: edgeHint
      visible: win.cfg.autohide && win.cfg.edgeHint && opacity > 0.01
      readonly property real len: Math.max(28, Math.min(stage.barAlong * 0.35, 160))
      width: win.hz ? len : 3
      height: win.hz ? 3 : len
      radius: 1.5
      x: win.hz ? stage.restX + (stage.barW - width) / 2 : (win.cfg.edge === "left" ? 1 : stage.width - width - 1)
      y: win.hz ? (win.cfg.edge === "top" ? 1 : stage.height - height - 1) : stage.restY + (stage.barH - height) / 2
      color: win.anyUrgent ? win.pal.hot : win.pal.fg
      opacity: Math.max(0, Math.min(1, win.hideT)) * (win.anyUrgent ? hintPulse : 0.5)
      property real hintPulse: 1
      SequentialAnimation on hintPulse {
        running: edgeHint.visible && win.anyUrgent && win.cfg.attention === "pulse"
        loops: Animation.Infinite
        NumberAnimation { to: 0.35; duration: 900; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
      }
    }

  Rectangle {
    id: bar
    width: stage.barW
    height: stage.barH
    x: stage.restX + (win.hz ? 0 : stage.outward * win.fx.off)
    y: stage.restY + (win.hz ? stage.outward * win.fx.off : 0)
    opacity: Math.max(0, Math.min(1, win.fx.opacity))
    visible: opacity > 0.005
    transform: Scale {
      // grow from / shrink onto the edge (center for pop)
      origin.x: win.fx.center || win.hz ? bar.width / 2 : (win.cfg.edge === "left" ? 0 : bar.width)
      origin.y: win.fx.center || !win.hz ? bar.height / 2 : (win.cfg.edge === "top" ? 0 : bar.height)
      xScale: win.fx.scale * (win.hz ? 1 : win.fx.fold)
      yScale: win.fx.scale * (win.hz ? win.fx.fold : 1)
    }
    // the rectangle only holds the icons in place; the body is painted just below it
    color: "transparent"
    property real barPulse: 0.9
    readonly property real bgFade: Math.max(0, Math.min(1, win.fx.bg))

    // the dock's body: ends, surface, lines and ornaments (js/Style.js, js/Paint.js)
    Canvas {
      id: body
      x: -win.glow
      y: -win.glow
      width: bar.width + win.glow * 2
      height: bar.height + win.glow * 2
      z: -1
      opacity: bar.bgFade
      readonly property string key: JSON.stringify([Style.styleOf(win.cfg), win.cfg.opacity, win.cfg.radius,
                                                    win.cfg.edge, win.pal, width, height])
      onKeyChanged: requestPaint()
      onVisibleChanged: if (visible) requestPaint()
      onPaint: {
        const ctx = getContext("2d");
        Paint.paint(ctx, Style.params(win.cfg, win.pal, width, height, win.glow, { edge: win.cfg.edge }));
      }
    }
    // an app asking for attention: the outline pulses in the attention color
    Canvas {
      id: urgentRing
      x: -win.glow
      y: -win.glow
      width: body.width
      height: body.height
      z: -1
      visible: win.anyUrgent
      opacity: bar.barPulse * bar.bgFade
      readonly property string key: body.key + win.pal.hot
      onKeyChanged: requestPaint()
      onVisibleChanged: if (visible) requestPaint()
      onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const p = Style.params(win.cfg, win.pal, width, height, win.glow, { edge: win.cfg.edge });
        p.surface = "clear"; p.lines = "solid"; p.ornament = "none"; p.line = String(win.pal.hot);
        p.lineGrad = []; p.lineWidth = 2; p.shadowBlur = 0; p.fill2 = ""; p.glass = false; p.pattern = ""; p.depth = "";
        Paint.paint(ctx, p);
      }
    }
    SequentialAnimation on barPulse {
      running: win.anyUrgent && win.cfg.attention === "pulse"
      loops: Animation.Infinite
      NumberAnimation { to: 0.35; duration: 900; easing.type: Easing.InOutSine }
      NumberAnimation { to: 0.9; duration: 900; easing.type: Easing.InOutSine }
    }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.RightButton
      onPressed: { win.previewSlot = null; win.openSettings(); }
    }

    Grid {
      id: grid
      columns: win.hz ? 1000 : 1
      spacing: 6
      function place(free) {
        return win.cfg.align === "start" ? win.padAlong : win.cfg.align === "end" ? free - win.padAlong : free / 2;
      }
      x: win.hz ? (win.cfg.stretch ? place(bar.width - width) : win.padAlong) : win.pad
      y: win.hz ? win.pad : (win.cfg.stretch ? place(bar.height - height) : win.padAlong)

      Repeater {
        model: win.cfg.apps

        delegate: Item {
          id: slot
          required property string modelData
          required property int index
          // reading .values re-runs this when quickshell rescans entries, so it never goes stale
          readonly property var entry: { DesktopEntries.applications.values; return DesktopEntries.byId(modelData); }
          // Desktop entry icon name, with the live window class as a fallback.
          property string iconName: ""
          property int iconTick: 0
          property int iconCandidateIndex: 0
          function refreshIcon() {
            const n = (entry && entry.icon) ? entry.icon : "";
            if (n !== "") { iconName = n; return; }
            // wins isn't there yet while the slot is still being made
            const w = slot.wins || [];
            if (iconName === "" && w.length > 0) iconName = w[0].appId || "";
          }
          onEntryChanged: refreshIcon()
          onWinsChanged: refreshIcon()

          // Try desktop-entry icon names, then image files shipped outside the icon theme.
          // Some entries use a filename such as "tlauncher.png" even when that file is
          // installed directly in /usr/share/icons rather than in a theme directory.
          readonly property var iconCandidates: {
            slot.iconTick;
            const cands = [];
            const add = (value) => {
              const s = String(value || "").trim();
              if (s && !cands.includes(s)) cands.push(s);
            };
            const addTheme = (name) => {
              if (!name) return;
              const r = Quickshell.iconPath(name, true);
              if (r) add(r);
            };
            const rawNames = [];
            if (iconName !== "") rawNames.push(iconName);
            if (entry) {
              if (entry.id) rawNames.push(entry.id, entry.id.toLowerCase());
              if (entry.startupClass) rawNames.push(entry.startupClass, entry.startupClass.toLowerCase());
            }
            const w = slot.wins || [];
            if (w.length > 0 && w[0].appId) rawNames.push(w[0].appId, w[0].appId.toLowerCase());
            const iconNames = Array.from(new Set(rawNames));

            // Preserve explicit file paths and try icon names with and without a file suffix.
            for (const name of iconNames) {
              const value = String(name || "").trim();
              if (!value) continue;
              if (value.startsWith("/")) add("file://" + value);
              else {
                // Honor an explicit desktop-entry filename before testing a theme name
                // with its suffix removed (for example TLauncher's tlauncher.png).
                if (/\.(png|svg|xpm|jpg|jpeg|webp)$/i.test(value)) {
                  add("file:///usr/share/icons/" + value);
                  add("file:///usr/share/pixmaps/" + value);
                  const dataHome = Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share");
                  add("file://" + dataHome + "/icons/" + value);
                  add("file://" + dataHome + "/pixmaps/" + value);
                }
                addTheme(value);
                const bare = value.replace(/\.(png|svg|xpm|jpg|jpeg|webp)$/i, "");
                if (bare !== value) addTheme(bare);
              }
            }

            // Some desktop icons live in a different installed theme than the active one.
            // Search the usual shared icon sizes, including AdwaitaLegacy's legacy category.
            const iconDirs = [
              "/usr/share/icons/AdwaitaLegacy/48x48/legacy/",
              "/usr/share/icons/AdwaitaLegacy/32x32/legacy/",
              "/usr/share/icons/AdwaitaLegacy/24x24/legacy/",
              "/usr/share/icons/AdwaitaLegacy/16x16/legacy/",
              "/usr/share/icons/hicolor/256x256/apps/",
              "/usr/share/icons/hicolor/48x48/apps/",
              "/usr/share/icons/hicolor/scalable/apps/",
              "/usr/share/pixmaps/"
            ];
            const formats = ["png", "svg", "xpm"];
            for (const name of iconNames) {
              const value = String(name || "").trim();
              if (!value || value.startsWith("/")) continue;
              const base = value.replace(/\.(png|svg|xpm|jpg|jpeg|webp)$/i, "");
              if (!base || base.includes("/")) continue;
              for (const dir of iconDirs) {
                for (const ext of formats) add("file://" + dir + base + "." + ext);
              }
            }

            // Desktop files sometimes name an image that is stored outside the theme.
            for (const name of iconNames) {
              const value = String(name || "").trim();
              if (!value || value.startsWith("/") || !/\.(png|svg|xpm|jpg|jpeg|webp)$/i.test(value)) continue;
              add("file:///usr/share/icons/" + value);
              add("file:///usr/share/pixmaps/" + value);
              const dataHome = Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share");
              add("file://" + dataHome + "/icons/" + value);
              add("file://" + dataHome + "/pixmaps/" + value);
            }

            for (const fallback of ["application-x-executable", "application-default-icon", "applications-other"]) {
              addTheme(fallback);
            }
            return cands;
          }
          onIconCandidatesChanged: iconCandidateIndex = 0
          readonly property string iconSrc: iconCandidateIndex < iconCandidates.length
            ? iconCandidates[iconCandidateIndex] : ""
          // icon theme can change (theme switch), so retry every few seconds while nothing resolves
          Timer {
            interval: 3000; repeat: true
            running: slot.iconSrc === ""
            onTriggered: slot.iconTick++
          }
          readonly property var wins: win.windowsOf(entry)
          readonly property color tone: win.toneFor(entry)
          readonly property bool attention: win.cfg.attention !== "off" && wins.some(t => win.isUrgent(t))
          property bool dragging: false
          property real off: 0
          readonly property real shift: {
            if (dragging) return off;
            if (win.dragFrom < 0) return 0;
            if (win.dragFrom < index && index <= win.dragTo) return -win.step;
            if (win.dragTo <= index && index < win.dragFrom) return win.step;
            return 0;
          }

          // wave: icons pop one after another
          property real pt: 0
          readonly property real waveT: win.effect === "wave" ? Math.max(0, Math.min(1, pt)) : 0
          Connections {
            target: win
            function onOpenChanged() { waveAnim.run(slot.index, win.cfg.apps.length + 1); }
          }
          Component.onCompleted: { pt = win.open ? 0 : 1; refreshIcon(); }
          SequentialAnimation {
            id: waveAnim
            function run(i, n) {
              stop();
              if (win.effect !== "wave") { slot.pt = win.open ? 0 : 1; return; }
              pause.duration = (win.open ? i : n - 1 - i) * win.waveStep;
              grow.to = win.open ? 0 : 1;
              grow.duration = win.speed;
              grow.easing.type = win.open ? Easing.OutBack : Easing.InCubic;
              start();
            }
            PauseAnimation { id: pause }
            NumberAnimation { id: grow; target: slot; property: "pt" }
          }

          width: win.cell
          height: win.cell
          z: dragging ? 10 : 0
          opacity: (dragging ? 0.85 : 1) * (1 - waveT)
          scale: 1 - 0.6 * waveT

          transform: Translate {
            x: win.hz ? slot.shift : 0
            y: win.hz ? 0 : slot.shift
            Behavior on x { enabled: !slot.dragging; NumberAnimation { duration: 120 } }
            Behavior on y { enabled: !slot.dragging; NumberAnimation { duration: 120 } }
          }

          Rectangle {
            anchors.fill: parent
            radius: 12
            color: win.cfg.style === "category"
              ? Qt.alpha(slot.tone, ma.containsMouse || slot.dragging ? 0.22 : 0)
              : Qt.alpha(win.pal.fg, ma.containsMouse || slot.dragging ? 0.14 : 0)
          }

          IconImage {
            id: appIcon
            anchors.centerIn: parent
            implicitSize: win.iconPx
            visible: slot.iconSrc !== "" && status !== Image.Error
            source: slot.iconSrc
            onStatusChanged: {
              if (status === Image.Error && slot.iconCandidateIndex < slot.iconCandidates.length - 1)
                slot.iconCandidateIndex++;
            }
          }

          // letter tile when there's no icon at all
          Rectangle {
            anchors.centerIn: parent
            width: win.iconPx; height: win.iconPx
            radius: width * 0.25
            visible: slot.iconSrc === "" || appIcon.status === Image.Error
            color: Qt.alpha(win.pal.fg, 0.15)
            Text {
              anchors.centerIn: parent
              text: (slot.modelData || "?").charAt(0).toUpperCase()
              color: win.pal.fg
              font.pixelSize: parent.height * 0.5
              font.bold: true
            }
          }

          // glow while the app wants attention
          Rectangle {
            id: glow
            anchors.fill: parent
            radius: 12
            visible: slot.attention && win.cfg.attention === "pulse"
            color: Qt.alpha(win.pal.hot, 0.18)
            border.width: 2
            border.color: win.pal.hot
            opacity: 0.9
            SequentialAnimation on opacity {
              running: glow.visible
              loops: Animation.Infinite
              NumberAnimation { to: 0.25; duration: 900; easing.type: Easing.InOutSine }
              NumberAnimation { to: 0.9; duration: 900; easing.type: Easing.InOutSine }
            }
          }

          Rectangle {
            visible: slot.wins.length > 0
            width: slot.attention ? 8 : 5; height: width; radius: width / 2
            color: slot.attention ? win.pal.hot : slot.tone
            x: win.hz ? (parent.width - width) / 2 : (win.cfg.edge === "left" ? 1 : parent.width - width - 1)
            y: win.hz ? (win.cfg.edge === "top" ? 1 : parent.height - height - 1) : (parent.height - height) / 2
          }

          MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            property real startPos: 0
            property bool moved: false

            function along(m) {
              const p = mapToItem(grid, m.x, m.y);
              return win.hz ? p.x : p.y;
            }

            function reset() {
              slot.dragging = false; slot.off = 0; moved = false;
              win.dragFrom = -1; win.dragTo = -1;
            }

            onEntered: { hoverLeave.stop(); win.hoverSlot = slot; hoverDelay.restart(); }
            onExited: { hoverDelay.stop(); hoverLeave.restart(); }

            onPressed: m => {
              if (m.button === Qt.RightButton) {
                win.previewSlot = null; win.addOpen = false;
                win.menuSlot = slot;
              } else {
                startPos = along(m); moved = false;
              }
            }

            onPositionChanged: m => {
              if (!(pressedButtons & Qt.LeftButton)) return;
              const d = along(m) - startPos;
              if (!moved && Math.abs(d) < 10) return;
              moved = true;
              win.previewSlot = null;
              slot.dragging = true;
              slot.off = d;
              win.dragFrom = slot.index;
              win.dragTo = Math.max(0, Math.min(win.cfg.apps.length - 1, slot.index + Math.round(d / win.step)));
            }

            onReleased: m => {
              if (m.button !== Qt.LeftButton) return;
              if (moved) {
                const to = win.dragTo, from = slot.index;
                reset();
                if (to !== from) win.svc.moveApp(win.idx, from, to);
              } else {
                win.activate(slot.entry, slot.wins);
              }
            }

            onCanceled: reset()
          }
        }
      }

      Item {
        id: addBtn
        width: win.cell
        height: win.cell
        property real pt: 0
        readonly property real waveT: win.effect === "wave" ? Math.max(0, Math.min(1, pt)) : 0
        opacity: 1 - waveT
        scale: 1 - 0.6 * waveT
        Component.onCompleted: pt = win.open ? 0 : 1
        Connections {
          target: win
          function onOpenChanged() {
            addWave.stop();
            if (win.effect !== "wave") { addBtn.pt = win.open ? 0 : 1; return; }
            addPause.duration = win.open ? win.cfg.apps.length * win.waveStep : 0;
            addGrow.to = win.open ? 0 : 1;
            addGrow.duration = win.speed;
            addGrow.easing.type = win.open ? Easing.OutBack : Easing.InCubic;
            addWave.start();
          }
        }
        SequentialAnimation {
          id: addWave
          PauseAnimation { id: addPause }
          NumberAnimation { id: addGrow; target: addBtn; property: "pt" }
        }

        Rectangle {
          anchors.fill: parent
          radius: 12
          color: Qt.alpha(win.pal.fg, addMa.containsMouse ? 0.14 : 0)
        }
        Text {
          textFormat: Text.PlainText
          anchors.centerIn: parent
          text: win.full ? "⋯" : "+"
          color: win.pal.fg
          font.pixelSize: win.cfg.size * 0.6
        }
        MouseArea {
          id: addMa
          anchors.fill: parent
          hoverEnabled: true
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          onPressed: m => {
            win.previewSlot = null; win.menuSlot = null;
            if (m.button === Qt.RightButton || win.full) { win.addOpen = false; win.openSettings(); }
            else win.addOpen = !win.addOpen;
          }
        }
      }
    }
  }
  }

  PopupWindow {
    id: previewPop
    // keep the last list so the popup doesn't collapse into a tiny empty bubble while hiding
    property var shownWins: []
    property var shownSlot: null
    Connections {
      target: win
      function onPreviewSlotChanged() {
        if (win.previewSlot !== null && win.previewSlot.wins.length > 0) {
          previewPop.shownSlot = win.previewSlot;
          previewPop.shownWins = win.previewSlot.wins;
        }
      }
    }
    visible: win.previewSlot !== null && win.previewSlot.wins.length > 0 && shownWins.length > 0
    anchor.item: shownSlot
    anchor.edges: win.popEdge
    anchor.gravity: win.popEdge
    anchor.adjustment: PopupAdjustment.Slide
    implicitWidth: Math.max(previewRow.implicitWidth + 16, 236)
    implicitHeight: Math.max(previewRow.implicitHeight + 16, 166)
    color: "transparent"

    HoverHandler {
      id: previewHover
      onHoveredChanged: if (hovered) hoverLeave.stop(); else hoverLeave.restart();
    }

    Rectangle {
      anchors.fill: parent
      radius: 12
      visible: previewPop.visible && previewPop.shownWins.length > 0
      color: win.ui.bgBase
      border.width: 1
      border.color: win.ui.bgBorder

      Row {
        id: previewRow
        anchors.centerIn: parent
        spacing: 8

        Repeater {
          model: previewPop.shownWins

          delegate: Item {
            id: card
            required property var modelData
            readonly property bool urgent: win.cfg.attention !== "off" && win.isUrgent(modelData)
            width: 220
            height: 150

            Rectangle {
              anchors.fill: parent
              radius: 10
              color: cardMa.containsMouse ? win.ui.bgHover : win.ui.bgSurface
              border.width: card.urgent ? 2 : 0
              border.color: win.ui.accentRed
            }
            ScreencopyView {
              x: 6; y: 6
              width: 208; height: 118
              captureSource: card.modelData
              live: true
            }
            Text {
              textFormat: Text.PlainText
              x: 8; y: 126
              width: 204
              text: card.modelData.title
              color: win.ui.textPrimary
              elide: Text.ElideRight
              font.pixelSize: 11; font.family: win.uiFont
            }
            MouseArea {
              id: cardMa
              anchors.fill: parent
              hoverEnabled: true
              onClicked: { card.modelData.activate(); win.previewSlot = null; }
            }
          }
        }
      }
    }
  }

  PopupWindow {
    id: menuPop
    readonly property var items: {
      const s = win.menuSlot;
      if (!s || !s.entry) return [];
      const out = [{ t: "New window", f: () => s.entry.execute() }];
      (s.entry.actions || []).forEach(a => { out.push({ t: a.name, f: () => a.execute() }); });
      s.wins.forEach(t => { out.push({ t: "Focus: " + t.title.slice(0, 32), f: () => t.activate() }); });
      if (s.wins.length > 0) out.push({ t: "Close window(s)", f: () => s.wins.forEach(t => t.close()) });
      out.push({ t: "Remove from dock", f: () => win.svc.removeApp(win.idx, s.modelData) });
      return out;
    }
    visible: win.menuSlot !== null
    anchor.item: win.menuSlot
    anchor.edges: win.popEdge
    anchor.gravity: win.popEdge
    anchor.adjustment: PopupAdjustment.Slide
    implicitWidth: 240
    implicitHeight: menuCol.implicitHeight + 12
    color: "transparent"

    Rectangle {
      anchors.fill: parent
      radius: 12
      color: win.ui.bgBase
      border.width: 1
      border.color: win.ui.bgBorder

      Column {
        id: menuCol
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }

        Repeater {
          model: menuPop.items

          delegate: Rectangle {
            id: row
            required property var modelData
            width: menuCol.width
            height: 28
            radius: 8
            color: rowMa.containsMouse ? win.ui.bgHover : "transparent"

            Text {
              textFormat: Text.PlainText
              anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 10 }
              text: row.modelData.t
              color: win.ui.textPrimary
              elide: Text.ElideRight
              font.pixelSize: 12; font.family: win.uiFont
            }
            MouseArea {
              id: rowMa
              anchors.fill: parent
              hoverEnabled: true
              onClicked: { const f = row.modelData.f; win.menuSlot = null; f(); }
            }
          }
        }
      }
    }
  }

  PopupWindow {
    id: addPop
    readonly property var choices: DesktopEntries.applications.values
      .filter(e => !e.noDisplay && win.cfg.apps.indexOf(e.id) < 0
        && e.name.toLowerCase().indexOf(search.text.toLowerCase()) >= 0)
      .sort((a, b) => a.name.localeCompare(b.name))
    visible: win.addOpen
    anchor.item: addBtn
    anchor.edges: win.popEdge
    anchor.gravity: win.popEdge
    anchor.adjustment: PopupAdjustment.Slide
    implicitWidth: 300
    implicitHeight: 380
    color: "transparent"
    onVisibleChanged: if (visible) { search.clear(); search.forceActiveFocus(); }

    Rectangle {
      anchors.fill: parent
      radius: 12
      color: win.ui.bgBase
      border.width: 1
      border.color: win.ui.bgBorder

      Rectangle {
        id: searchBox
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
        height: 32
        radius: 8
        color: win.ui.bgSurface; border.color: win.ui.bgBorder

        // no TextInput here on purpose, see SearchField.qml
        SearchField {
          id: search
          anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
          color: win.ui.textPrimary
          selectionColor: win.ui.bgSelected
          fontPixelSize: 12
          fontFamily: win.uiFont
        }
        Text {
          textFormat: Text.PlainText
          anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
          visible: search.text === ""
          text: "Search apps…"
          color: win.ui.textMuted
          font.pixelSize: 12; font.family: win.uiFont
        }
      }

      ListView {
        anchors { left: parent.left; right: parent.right; top: searchBox.bottom; bottom: parent.bottom; margins: 10 }
        clip: true
        model: addPop.choices

        delegate: Rectangle {
          id: choice
          required property var modelData
          width: ListView.view.width
          height: 36
          radius: 8
          color: choiceMa.containsMouse ? win.ui.bgHover : "transparent"

          IconImage {
            id: choiceIcon
            x: 6
            anchors.verticalCenter: parent.verticalCenter
            implicitSize: 24
            source: Quickshell.iconPath(choice.modelData.icon, "application-x-executable")
          }
          Text {
            textFormat: Text.PlainText
            anchors { left: choiceIcon.right; leftMargin: 10; right: parent.right; verticalCenter: parent.verticalCenter }
            text: choice.modelData.name
            color: win.ui.textPrimary
            elide: Text.ElideRight
            font.pixelSize: 12; font.family: win.uiFont
          }
          MouseArea {
            id: choiceMa
            anchors.fill: parent
            hoverEnabled: true
            onClicked: { win.addOpen = false; win.svc.addApp(win.idx, choice.modelData.id); }
          }
        }
      }
    }
  }
}
