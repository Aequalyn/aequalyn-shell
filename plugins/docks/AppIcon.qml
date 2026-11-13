import QtQuick
import Quickshell
import Quickshell.Widgets

// An app's icon, found the way the dock finds it: the desktop entry's icon name in the
// active theme, then image files outside the theme (pixmaps, hicolor, AdwaitaLegacy), then
// a generic app icon. `missing` is true when nothing could be shown, so callers can draw
// their own placeholder. Used by dock slots and by the dock's "add app" list.
Item {
  id: root
  property var entry: null
  // open windows of the app; their class is used when the entry names no icon
  property var wins: []
  property int size: 24
  readonly property bool missing: iconSrc === "" || img.status === Image.Error
  implicitWidth: size
  implicitHeight: size

  // Desktop entry icon name, with the live window class as a fallback. A plain binding:
  // setting it from onWinsChanged changed it while iconCandidates was being worked out
  // (reading `wins` the first time fires that signal), a binding loop at every start.
  readonly property string iconName: (entry && entry.icon) ? entry.icon
      : ((wins || []).length > 0 ? (wins[0].appId || "") : "")
  property int iconTick: 0
  property int iconCandidateIndex: 0

  // Try desktop-entry icon names, then image files shipped outside the icon theme.
  // Some entries use a filename such as "tlauncher.png" even when that file is
  // installed directly in /usr/share/icons rather than in a theme directory.
  readonly property var iconCandidates: {
    root.iconTick;
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
    const w = root.wins || [];
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
  // Installing an app makes quickshell rescan every desktop entry, which rebuilds this
  // list even when nothing changed for this slot; only start over when it really changed.
  property string iconCandidatesKey: ""
  onIconCandidatesChanged: {
    const key = iconCandidates.join("\n");
    if (key === iconCandidatesKey) return;
    iconCandidatesKey = key;
    iconCandidateIndex = 0;
  }
  readonly property string iconSrc: iconCandidateIndex < iconCandidates.length
    ? iconCandidates[iconCandidateIndex] : ""
  // A missing local file fails synchronously, so stepping to the next candidate inside the
  // status handler re-enters the iconSrc binding; Qt breaks that loop and leaves the slot on
  // a failed candidate, showing the letter tile. Step on the next event loop turn instead.
  function nextIcon() {
    if (img.status === Image.Error && iconCandidateIndex < iconCandidates.length - 1)
      iconCandidateIndex++;
  }
  // icon theme can change (theme switch, app install), so retry every few seconds while nothing resolves
  Timer {
    interval: 3000; repeat: true
    running: root.iconSrc === "" || img.status === Image.Error
    onTriggered: {
      root.iconTick++;
      if (root.iconCandidateIndex === 0) Qt.callLater(root.nextIcon);
      else root.iconCandidateIndex = 0;
    }
  }

  IconImage {
    id: img
    anchors.centerIn: parent
    implicitSize: root.size
    visible: !root.missing
    source: root.iconSrc
    onStatusChanged: if (status === Image.Error) Qt.callLater(root.nextIcon)
  }
}
