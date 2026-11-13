// Up to 16 docks, on any edge of any monitor (4 per edge), each with its own
// apps, place, size, auto-hide effect and look. A dock can wear the bar's look
// ("Same as the bar"), so the bar and its docks are styled together, or a look
// of its own. Settings live in Atelier -> Docks; right-click a dock to get there.
//
// Saved to ~/.config/aequalyn/docks.json. The first start takes the old single
// dock's settings (pinned apps, edge, size, auto-hide, screen) from settings.json.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import  "../../style/Style.js" as Style
import  "../../style/Shapes.js" as Shapes
import  "../../style/BarLooks.js" as BarLooks
import  "../../style/Colors.js" as Colors
import  "../../style/AequalynLooks.js" as AequalynLooks
import "root:/plugins/atelier"
import "root:/settings"

Scope {
  id: root

  // the shell's palette (ThemeSwitcher's theme)
  property var shellTheme
  readonly property bool enabled: AequalynSettings.dockEnabled

  readonly property string home: Quickshell.env("HOME")
  readonly property string cfgDir: home + "/.config/aequalyn"
  readonly property string cfgPath: cfgDir + "/docks.json"
  readonly property string cacheDir: home + "/.cache/aequalyn"

  readonly property int maxDocks: 16
  readonly property int maxPerEdge: 4
  // a dock's settings. the body's shape, surface, edge and ornaments come from style/Style.js
  readonly property var defaults: Object.assign({
    apps: [], edge: "bottom", align: "center", stretch: false,
    autohide: false, reserve: true, style: "theme", size: 44, iconScale: 100,
    opacity: 90, radius: 16, monitor: "", attention: "pulse",
    hideEffect: "slide", hideSpeed: 180, showDelay: 0, hideDelay: 450,
    revealStrip: 3, edgeHint: true, followBar: true,
    customBg: "#141414", customFg: "#e0e0e0", accentColor: "#ff6a1f"
  }, Style.defaults())

  // color modes: theme, theme + your accent, greys, or theme with a tint per app category
  readonly property var styles: ["theme", "custom", "monochrome", "category"]
  // custom color swatches: backgrounds, text, accents
  readonly property var swatches: [
    "#141414", "#1d1510", "#1a1b26", "#282a36", "#2e3440", "#2d353b", "#1f1f28", "#3b2a1f",
    "#e0e0e0", "#eadbc8", "#ffffff", "#c0caf5", "#d8dee9", "#dcd7ba", "#f8f8f2", "#e0def4",
    "#d4a35a", "#c8925a", "#7aa2f7", "#cba6f7", "#a7c080", "#88c0d0", "#fabd2f", "#ff6a1f"
  ]

  function validHex(v, fallback) {
    const t = String(v === undefined || v === null ? "" : v).trim();
    return /^#[0-9a-fA-F]{6}$/.test(t) ? t.toLowerCase() : fallback;
  }

  // stable hue (0..1) per category name
  function hueOf(name) {
    const t = String(name || "");
    let h = 0;
    for (let k = 0; k < t.length; k++) h = (h * 31 + t.charCodeAt(k)) % 360;
    return h / 360;
  }

  // hide effects, in settings order
  readonly property var hideEffects: ["slide", "fade", "glide", "zoom", "fold", "bounce", "pop", "wave"]

  // allowed range per number, used to clean hand edited configs and resets
  readonly property var ranges: ({
    size: [1, 64], iconScale: [50, 200], opacity: [1, 100], radius: [1, 64],
    hideSpeed: [60, 800], showDelay: [0, 1000], hideDelay: [0, 2000], revealStrip: [1, 12]
  })

  function cleanDock(x) {
    const d = Object.assign({}, defaults, x, Style.clean(x));
    delete d.outline;   // older configs: became an accent line in Style.clean
    for (const k in ranges) {
      const v = Number(d[k]);
      d[k] = isFinite(v) ? Math.max(ranges[k][0], Math.min(ranges[k][1], Math.round(v))) : defaults[k];
    }
    if (hideEffects.indexOf(d.hideEffect) < 0) d.hideEffect = defaults.hideEffect;
    if (["bottom", "top", "left", "right"].indexOf(d.edge) < 0) d.edge = defaults.edge;
    if (["start", "center", "end"].indexOf(d.align) < 0) d.align = defaults.align;
    if (["off", "dot", "pulse"].indexOf(d.attention) < 0) d.attention = defaults.attention;
    if (d.style === "mono") d.style = "monochrome";
    if (styles.indexOf(d.style) < 0) d.style = defaults.style;
    for (const c of ["customBg", "customFg", "accentColor"]) d[c] = validHex(d[c], defaults[c]);
    if (!Array.isArray(d.apps)) d.apps = [];
    // app ids only: plain strings, no control chars, no dupes; DesktopEntries.byId wants
    // "kitty", not "kitty.desktop", so older docks get their ids fixed here
    d.apps = d.apps.filter(a => typeof a === "string" && a.length > 0 && a.length <= 255
                                && !/[\u0000-\u001f\u007f]/.test(a))
      .map(a => a.replace(/\.desktop$/, ""))
      .filter((a, i, all) => a.length > 0 && all.indexOf(a) === i).slice(0, 64);
    for (const b of ["stretch", "autohide", "reserve", "edgeHint"]) d[b] = d[b] === true;
    d.followBar = d.followBar !== false;
    d.monitor = typeof d.monitor === "string" && d.monitor.length <= 64 ? d.monitor : "";
    return d;
  }
  readonly property var mono: ({ bg: "#161616", fg: "#e0e0e0", ac: "#ffffff", hot: "#ff6b5e", spectrum: [] })
  readonly property var defaultMargins: ({ top: 6, bottom: 6, left: 6, right: 6 })

  // empty until the config is read, so a default bottom dock never reserves space at startup
  property var docks: []

  // the shell's colors, in the painter's terms (hot = attention color,
  // spectrum = the theme's own colors, for gradients beyond the accent)
  readonly property var theme: Colors.fromTheme(root.shellTheme)

  // ---- the bar --------------------------------------------------------------
  // the bar's look, and how far it reaches in from the top of every screen
  readonly property var barStyle: BarLooks.clean(AequalynSettings.barStyleCfg)
  readonly property int barThickness: {
    const size = AequalynSettings.barHeight;
    if (!barStyle.enabled) return size;
    return Shapes.thicknessFor(size, barStyle) + Shapes.floatGapFor(barStyle);
  }
  property bool barShown: true

  // what a dock following the bar takes from it
  readonly property var barKeys: Style.keys.concat(["opacity", "radius", "style", "customBg", "customFg", "accentColor"])

  // a dock about to stop following the bar starts from the bar's look
  function unlinked(j, set) {
    const d = docks[j];
    if (!d.followBar || set.followBar !== false) return d;
    const e = effective(j), out = Object.assign({}, d);
    for (const k of barKeys) out[k] = e[k];
    return out;
  }

  // a dock as it is drawn: its own settings, with the bar's look on top when it follows the bar
  function effective(i) {
    const d = docks[i];
    if (!d) return defaults;
    return d.followBar ? Object.assign({}, d, BarLooks.styleOf(barStyle)) : d;
  }

  // gap between the edge (or the bar) and the docks, one per edge, shared
  property var margins: Object.assign({}, defaultMargins)

  function barOffset(mon, edge) { return edge === "top" && barShown ? barThickness : 0; }
  function barInfoFor(mon) { return barShown ? "top " + barThickness + "px" : "hidden"; }
  function marginOf(edge) { const v = margins[edge]; return v === undefined ? 6 : v; }

  // colors for a dock or a style name. custom = your own bg/text/accent, attention stays the theme's
  function palette(d) {
    const style = typeof d === "string" ? d : (d ? d.style : "theme");
    if (style === "monochrome") return mono;
    if (style === "custom") return {
      bg: validHex(d && d.customBg, defaults.customBg),
      fg: validHex(d && d.customFg, defaults.customFg),
      ac: validHex(d && d.accentColor, defaults.accentColor),
      hot: theme.hot,
      spectrum: []
    };
    return theme;
  }

  // saving
  function save() {
    Quickshell.execDetached(["sh", "-c",
      'umask 077; mkdir -p "$1" && chmod 700 "$1" && printf %s "$2" > "$3.tmp" && mv -f "$3.tmp" "$3"', "sh",
      cfgDir, JSON.stringify({ version: 1, docks: docks, margins: margins }, null, 2), cfgPath]);
  }

  function commit(next) {
    docks = next;
    save();
  }

  property string notice: ""

  Timer { id: noticeTimer; interval: 4000; onTriggered: root.notice = "" }
  function warn(text) { notice = text; noticeTimer.restart(); }

  // monitors. no monitor set, or not connected -> primary screen
  function screenByName(name) {
    const list = Quickshell.screens;
    for (let k = 0; k < list.length; k++) if (list[k].name === name) return list[k];
    return null;
  }

  function screenFor(d) {
    const found = (d && d.monitor) ? screenByName(d.monitor) : null;
    if (found) return found;
    return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
  }

  function monOf(d) { const s = screenFor(d); return s ? s.name : ""; }
  function sameGroup(a, b) { return !!a && !!b && a.edge === b.edge && monOf(a) === monOf(b); }

  function edgeLen(mon, edge) {
    const s = screenByName(mon);
    const hz = edge === "top" || edge === "bottom";
    return s ? (hz ? s.width : s.height) : (hz ? 1920 : 1080);
  }

  function dockThick(d) { return d.size + 28; }
  // how far pointed or curled ends reach in, so the first and last icon stay clear of them
  function endRoom(d) { return Style.endRoom(d, dockThick(d), 8); }

  // how far in from the edge things reach on mon/edge: bar + docks (margin + thickness)
  function extent(list, mon, edge) {
    const bar = barOffset(mon, edge);
    const ds = list.filter(d => d.edge === edge && monOf(d) === mon);
    if (ds.length === 0) return bar;
    return bar + marginOf(edge) + ds.reduce((m, d) => Math.max(m, dockThick(d)), 0);
  }

  function cornersFor(list, mon, edge) {
    const hz = edge === "top" || edge === "bottom";
    return { start: extent(list, mon, hz ? "left" : "top"),
             end: extent(list, mon, hz ? "right" : "bottom") };
  }

  function usableLen(list, mon, edge) {
    const c = cornersFor(list, mon, edge);
    return Math.max(0, edgeLen(mon, edge) - c.start - c.end);
  }

  function slotLen(list, i) {
    const d = list[i];
    if (!d) return 0;   // a dock that was just removed, until its window goes
    const mon = monOf(d);
    const n = list.filter(x => sameGroup(x, d)).length;
    return Math.floor(usableLen(list, mon, d.edge) / n) - (n > 1 ? 6 : 0);
  }

  function capacity(list, i) {
    if (!list[i]) return 0;
    const step = list[i].size + 12 + 6;
    return Math.max(0, Math.floor((slotLen(list, i) - 10 - 2 * endRoom(list[i])) / step) - 1);
  }

  function layoutOk(list) {
    for (let i = 0; i < list.length; i++) {
      const n = list.filter(x => sameGroup(x, list[i])).length;
      if (n > maxPerEdge || list[i].apps.length > capacity(list, i)) return false;
    }
    return true;
  }

  // reserve space. index -> is that dock on screen right now (only matters with auto-hide)
  property var shown: ({})

  function setShown(i, v) {
    if ((shown[i] === true) === v) return;
    const n = Object.assign({}, shown);
    if (v) n[i] = true; else delete n[i];
    shown = n;
  }

  // a visible dock holds its space. with auto-hide it gives it back while hidden,
  // the setting itself doesn't change
  function reserving(i) {
    const d = docks[i];
    return !!d && d.reserve && (!d.autohide || shown[i] === true);
  }

  function edgeZone(mon, edge) {
    // window is thickness + margin deep (see DockWindow), so the band matches exactly
    let zone = 0;
    for (let i = 0; i < docks.length; i++) {
      const d = docks[i];
      if (d.edge === edge && monOf(d) === mon && reserving(i))
        zone = Math.max(zone, dockThick(d) + marginOf(edge));
    }
    return zone;
  }

  // changes
  function patch(i, key, value) {
    const n = docks.slice();
    if (key === "reserve") {
      // reserve is shared by every dock on the same edge of the same monitor
      const ref = n[i];
      for (let j = 0; j < n.length; j++) {
        if (sameGroup(n[j], ref)) n[j] = Object.assign({}, n[j], { reserve: value });
      }
    } else {
      n[i] = Object.assign({}, n[i], { [key]: value });
    }
    if ((key === "edge" || key === "size" || key === "monitor") && !layoutOk(n)) {
      warn("Not enough room for those icons there. Remove some icons or pick a smaller size, another edge or another monitor.");
      return;
    }
    commit(n);
  }

  // look settings for one dock, its edge, or everything
  function patchScope(i, key, value, scope) {
    patchManyScope(i, { [key]: value }, scope);
  }
  function patchManyScope(i, set, scope) {
    const ref = docks[i];
    if (!ref) return false;
    // a dock that gets a look of its own stops following the bar
    if (Object.keys(set).some(k => root.barKeys.indexOf(k) >= 0) && set.followBar === undefined)
      set = Object.assign({ followBar: false }, set);
    const n = docks.map((d, j) => (j === i || (scope === "all") || (scope === "edge" && sameGroup(d, ref)))
      ? cleanDock(Object.assign({}, unlinked(j, set), set)) : d);
    // deeper ends take room from the icons (a layout that already didn't fit, say from a
    // hand edited config, isn't blocked by it)
    if (!layoutOk(n) && layoutOk(docks)) {
      warn("Those ends need more room than this dock has. Remove some icons or pick a smaller icon size first.");
      return false;
    }
    commit(n);
    return true;
  }

  // ready made looks, with one step back. undo remembers each dock's body before the
  // last look and is forgotten when the shell restarts
  property var undoStyles: ({})
  function applyLook(i, key, scope) {
    const set = AequalynLooks.dockSet(key);
    if (!set || !docks[i]) return false;
    const ref = docks[i];
    const before = {};
    for (let j = 0; j < docks.length; j++)
      if (j === i || scope === "all" || (scope === "edge" && sameGroup(docks[j], ref)))
        before[j] = Object.assign(Style.styleOf(docks[j]), { followBar: docks[j].followBar });
    if (!patchManyScope(i, set, scope)) return false;
    undoStyles = before;
    return true;
  }
  readonly property bool canUndo: Object.keys(undoStyles).length > 0
  function undoLook() {
    const before = undoStyles;
    if (Object.keys(before).length === 0) return false;
    const n = docks.map((d, j) => before[j] ? cleanDock(Object.assign({}, d, before[j])) : d);
    if (!layoutOk(n)) { warn("The previous look no longer fits. Remove some icons first."); return false; }
    undoStyles = ({});
    commit(n);
    return true;
  }

  function setMargin(edge, value) {
    const old = margins;
    margins = Object.assign({}, old, { [edge]: value });
    if (!layoutOk(docks)) {
      margins = old;
      warn("That margin leaves too little room for the icons on the other edges.");
      return;
    }
    save();
  }

  function addApp(i, id) {
    id = String(id || "").replace(/\.desktop$/, "");
    if (!id || docks[i].apps.indexOf(id) >= 0) return;
    const n = docks.slice();
    n[i] = Object.assign({}, n[i], { apps: n[i].apps.concat([id]) });
    if (!layoutOk(n)) { warn("This dock is full. Use a smaller icon size or fewer docks on this edge."); return; }
    commit(n);
  }

  function removeApp(i, id) { patch(i, "apps", docks[i].apps.filter(a => a !== id)); }

  // Uninstalled apps leave the docks by themselves. Apps are only ever pinned from the
  // desktop entries, so one whose entry is gone was uninstalled. It has to stay gone a
  // while first, so a package being replaced or a rescan of the entries doesn't count,
  // and nothing is decided before the entries have been read at all.
  property var missingSince: ({})
  property int goneAfter: 20000
  function pruneUninstalled() {
    const list = DesktopEntries.applications.values;
    if (!list || list.length < 5 || docks.length === 0) return;
    const now = Date.now(), since = {}, gone = [];
    for (const d of docks) for (const id of d.apps) {
      if (DesktopEntries.byId(id)) continue;
      since[id] = missingSince[id] || now;
      if (now - since[id] >= goneAfter && gone.indexOf(id) < 0) gone.push(id);
    }
    missingSince = since;
    if (gone.length === 0) return;
    // more than half of them at once looks like the entries not being read right,
    // not like uninstalling: leave the docks alone
    const pinned = [];
    for (const d of docks) for (const id of d.apps) if (pinned.indexOf(id) < 0) pinned.push(id);
    if (gone.length > 1 && gone.length * 2 > pinned.length) return;
    commit(docks.map(d => d.apps.some(a => gone.indexOf(a) >= 0)
      ? Object.assign({}, d, { apps: d.apps.filter(a => gone.indexOf(a) < 0) }) : d));
    warn(gone.length === 1 ? gone[0].replace(/\.desktop$/, "") + " is no longer installed, so it left the dock."
                           : gone.length + " apps are no longer installed, so they left the docks.");
  }
  Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: root.pruneUninstalled()
  }

  function moveApp(i, from, to) {
    const a = docks[i].apps.slice();
    a.splice(to, 0, a.splice(from, 1)[0]);
    patch(i, "apps", a);
  }

  // new dock goes on the monitor of the dock whose settings are open
  function addDock(from) {
    if (docks.length >= maxDocks) { warn("Maximum of " + maxDocks + " docks."); return; }
    const monitor = (from !== undefined && docks[from]) ? docks[from].monitor : "";
    const probe = { monitor: monitor };
    const count = e => docks.filter(d => d.edge === e && monOf(d) === monOf(probe)).length;
    const order = ["bottom", "left", "right", "top"].filter(e => count(e) < maxPerEdge)
      .sort((a, b) => count(a) - count(b));
    for (let k = 0; k < order.length; k++) {
      const next = docks.concat([Object.assign({}, defaults, { apps: [], edge: order[k], monitor: monitor })]);
      if (layoutOk(next)) { commit(next); return; }
    }
    warn("No room for another dock. Shrink icons or remove some apps first.");
  }

  // reset everything except what the dock is (apps, edge, position, monitor)
  function resetDock(i) {
    const d = docks[i];
    if (!d) return;
    const n = docks.slice();
    n[i] = cleanDock({ apps: d.apps, edge: d.edge, align: d.align, monitor: d.monitor, reserve: d.reserve });
    if (!layoutOk(n)) { warn("The default icon size does not fit here. Remove some icons first."); return; }
    commit(n);
  }

  function removeDock(i) {
    if (docks.length > 1) commit(docks.filter((d, j) => j !== i));
  }

  // ---- the bar and the docks together -----------------------------------------
  // Follow the bar (or stop): one dock, its edge or all of them.
  function setFollow(i, on, scope) {
    const ref = docks[i];
    if (!ref) return;
    let n = docks.map((d, j) => (j === i || scope === "all" || (scope === "edge" && sameGroup(d, ref)))
      ? Object.assign({}, d, on ? { followBar: true } : Object.assign({ followBar: false }, Style.styleOf(effective(j)))) : d);
    if (!layoutOk(n)) { warn("The bar's ends need more room than this dock has. Remove some icons first."); return; }
    commit(n);
  }
  // A dock's look onto the bar, and every dock following the bar.
  function lookToBar(i) {
    const d = docks[i];
    if (!d) return;
    const s = Style.styleOf(effective(i));
    const next = Object.assign({}, AequalynSettings.barStyleCfg, s, { opacity: d.opacity });
    if (d.style === "custom" || d.style === "monochrome") {
      next.colorMode = d.style;
      next.customBg = d.customBg; next.customFg = d.customFg; next.accentColor = d.accentColor;
    }
    AequalynSettings.setBarStyle(next);
    setFollow(i, true, "all");
  }

  // An ensemble: the bar's look, and every dock either wearing it or a look of its own.
  function applyEnsemble(key) {
    const e = AequalynLooks.byKey(AequalynLooks.ensembles, key);
    if (!e) return;
    AequalynSettings.setBarStyle(Object.assign(BarLooks.applyLook(barStyle, e.bar),
      { enabled: true, chips: AequalynSettings.barStyleCfg.chips }));
    if (docks.length === 0) return;
    if (e.dock === "follow") setFollow(0, true, "all");
    else applyLook(0, e.dock, "all");
  }
  // the ensemble the bar and docks are wearing right now, or ""
  function ensembleOf() {
    const barKey = BarLooks.lookOf(barStyle);
    for (const e of AequalynLooks.ensembles) {
      if (e.bar !== barKey) continue;
      const ok = docks.every(d => e.dock === "follow" ? d.followBar : (!d.followBar && AequalynLooks.dockLookOf(d) === e.dock));
      if (ok) return e.key;
    }
    return "";
  }

  FileView {
    id: cfgFile
    path: root.cfgPath
    blockLoading: true
    printErrors: false
    onLoaded: {
      try {
        const j = JSON.parse(text());
        const d = j.docks;
        if (d && d.length)
          root.docks = d.slice(0, root.maxDocks).map(x => root.cleanDock(x));
        if (j.margins) {
          const m = Object.assign({}, root.defaultMargins);
          for (const k of ["top", "bottom", "left", "right"]) {
            const v = Number(j.margins[k]);
            if (isFinite(v)) m[k] = Math.max(0, Math.min(64, Math.round(v)));
          }
          root.margins = m;
        }
      } catch (e) {}
      root.ensureDock();
    }
    onLoadFailed: root.ensureDock()
  }

  // no docks.json yet: start with one dock made from the old dock settings
  function ensureDock() {
    if (docks.length > 0) return;
    const S = AequalynSettings;
    const edge = ["bottom", "top", "left", "right"].indexOf(S.dockPosition) >= 0 ? S.dockPosition : "bottom";
    docks = [cleanDock(Object.assign({}, defaults, {
      apps: (S.dockPinned || []).map(a => String(a).replace(/\.desktop$/, "")),
      edge: edge,
      autohide: S.dockAutohide === true,
      size: Math.max(24, Math.min(64, S.dockIconSize || 44)),
      monitor: S.dockScreen && S.dockScreen !== "all" ? S.dockScreen : ""
    }))];
    save();
  }

  // settings for a dock: Atelier's Docks tab, on that dock
  function openSettings(i, screenName) {
    AtelierHost.dockFocus = i;
    AtelierHost.open("docks", screenName || "");
  }

  // qs ipc call dock toggle | show | hide | add | settings [n]
  IpcHandler {
    target: "dock"
    function toggle(): void { AequalynSettings.apply("dockEnabled", !root.enabled); }
    function show(): void { AequalynSettings.apply("dockEnabled", true); }
    function hide(): void { AequalynSettings.apply("dockEnabled", false); }
    function add(): void { root.addDock(0); }
    function settings(n: int): void { root.openSettings(Math.max(0, Math.min(root.docks.length - 1, n - 1)), ""); }
  }

  Component.onCompleted: AtelierHost.docks = root
  Component.onDestruction: if (AtelierHost.docks === root) AtelierHost.docks = null

  // attention. hyprland sends urgent>>ADDRESS and drops it on focus/close.
  // we follow those events ourselves instead of relying on what quickshell exposes.
  // urgentMap: address (hex, no 0x) -> app class ("" until known)
  property var urgentMap: ({})
  readonly property string clientsPath: cacheDir + "/clients.json"
  property bool clientsAgain: false

  function classUrgent(cls) {
    const c = String(cls || "").toLowerCase();
    if (c === "") return false;
    for (const k in urgentMap) if (urgentMap[k] === c) return true;
    return false;
  }

  function normAddr(a) {
    return String(a || "").trim().toLowerCase().split(",")[0].replace(/^0x/, "");
  }

  function markUrgent(a) {
    const addr = normAddr(a);
    if (addr === "") return;
    if (!(addr in urgentMap)) {
      const n = Object.assign({}, urgentMap);
      n[addr] = "";
      urgentMap = n;
    }
    probeClients();
  }

  function clearUrgent(a) {
    const addr = normAddr(a);
    if (addr === "" || !(addr in urgentMap)) return;
    const n = Object.assign({}, urgentMap);
    delete n[addr];
    urgentMap = n;
  }

  function probeClients() {
    if (clientsProbe.running) { clientsAgain = true; return; }
    clientsProbe.running = true;
  }

  // fill in the class of each urgent window, forget the ones that are gone
  function resolveClients(json) {
    let list;
    try { list = JSON.parse(json); } catch (e) { return; }
    if (!Array.isArray(list)) return;
    const byAddr = {};
    for (const c of list) byAddr[normAddr(c.address)] = String(c["class"] || c["initialClass"] || "").toLowerCase();
    const n = {};
    let changed = false;
    for (const k in urgentMap) {
      if (!(k in byAddr)) { changed = true; continue; }
      n[k] = byAddr[k];
      if (n[k] !== urgentMap[k]) changed = true;
    }
    if (changed) urgentMap = n;
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name === "urgent") root.markUrgent(event.data);
      else if (event.name === "activewindowv2" || event.name === "closewindow") root.clearUrgent(event.data);
    }
  }

  Process {
    id: clientsProbe
    command: ["sh", "-c",
      // titles in here, so private: owner-only dir/file, old copy removed first (> keeps the old mode)
      'umask 077; mkdir -p "$1" && chmod 700 "$1" && rm -f "$1/clients.json" && ' +
      'hyprctl -j clients > "$1/clients.json" 2>/dev/null || true',
      "sh", root.cacheDir]
    running: false
    onExited: {
      clientsFile.reload();
      if (root.clientsAgain) { root.clientsAgain = false; running = true; }
    }
  }

  FileView {
    id: clientsFile
    path: root.clientsPath
    blockLoading: true
    printErrors: false
    onLoaded: root.resolveClients(text())
  }

  // one window per dock
  Variants {
    model: root.enabled ? Array.from({ length: root.docks.length }, (_, i) => i) : []

    DockWindow {
      required property int modelData
      idx: modelData
      svc: root
    }
  }

  // spacers for reserved space, one per monitor and edge
  Variants {
    model: root.enabled ? Quickshell.screens : []

    Scope {
      id: perScreen
      required property var modelData

      Spacer { svc: root; screen: perScreen.modelData; edge: "top" }
      Spacer { svc: root; screen: perScreen.modelData; edge: "bottom" }
      Spacer { svc: root; screen: perScreen.modelData; edge: "left" }
      Spacer { svc: root; screen: perScreen.modelData; edge: "right" }
    }
  }
}
