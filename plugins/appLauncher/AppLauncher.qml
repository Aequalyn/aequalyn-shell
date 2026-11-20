// Application launcher overlay.
// Searchable launcher UI for desktop applications (and related actions),
// shown as a layer-shell panel. Opened/closed via IPC (target "launcher")
// and keybinds (e.g. SUPER+D), and styled using the shared theme.

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "root:/plugins/docks"
import "root:/style/backdrop"

Scope {
  id: root
  property var theme: DefaultTheme {}
  property string font: "JetBrainsMono Nerd Font"

  IpcHandler {
    target: "launcher"

    function toggle(): void {
      root.open = !root.open
      if (root.open) {
        searchInput.text = ""
        selectedIndex = -1
        searchInput.forceActiveFocus()
      }
    }
    // every app the launcher would list whose name matches, as text: a way to
    // see the list from a terminal (and to check one is seen at all)
    function search(words: string): string {
      const q = words.trim().toLowerCase();
      const hits = root.mergedApps()
        .filter(d => String(d.name || d.id || "").toLowerCase().includes(q))
        .map(d => String(d.name || d.id) + " [" + d.id + "]");
      return hits.length ? hits.join("\n") : "(nothing matches \"" + words + "\")";
    }
    // re-read the applications directories: the startup model never sees a file
    // written after it (apps installed while the shell ran)
    function refresh(): string { root.scan(); return "ok"; }
  }

  property int selectedIndex: 0
  property bool open: false
  // a look at the directories as the launcher opens: an app may have arrived since
  onOpenChanged: if (root.open) root.scan()

  // ---- what the launcher lists ----------------------------------------------------------
  // Quickshell reads the desktop entries once, as the shell starts, and is never told
  // of a file written after: an app installed while the shell ran -- a package, an
  // AppImage the Store imported -- stays invisible until the next restart. So the
  // applications directories are read again as the launcher opens, and what the
  // model missed is listed beside it, launched the same way.
  property var scanApps: []
  readonly property string scanLs: 'shopt -s nullglob\n'
    + 'A=\'\n'
    + 'FNR == 1 { id = FILENAME; sub(/.*\\//, "", id); sub(/\\.desktop$/, "", id) }\n'
    + '/^\\[Desktop Entry\\]$/ { inentry = 1; next }\n'
    + '/^\\[/ { inentry = 0; next }\n'
    + 'inentry && /^(Name|GenericName|Exec|Icon|Terminal|NoDisplay|Type|Categories|Keywords)=/ {\n'
    + '  print id "\\t" substr($0, 1, index($0, "=") - 1) "\\t" substr($0, index($0, "=") + 1)\n'
    + '}\n'
    + '\'\n'
    + 'scan() { local f=("$1"/*.desktop); [ ${#f[@]} -gt 0 ] && awk "$A" "${f[@]}"; return 0; }\n'
    + 'scan "${XDG_DATA_HOME:-$HOME/.local/share}/applications"\n'
    + 'oldifs=$IFS; IFS=:\n'
    + 'for x in ${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do scan "$x/applications"; done\n'
    + 'IFS=$oldifs\n'
    + 'scan /var/lib/flatpak/exports/share/applications\n'
    + 'scan "$HOME/.local/share/flatpak/exports/share/applications"\n'
  function scanLaunch(e) {
    // a desktop Exec with its field codes left out, in a terminal when it asks for one
    const cmd = String(e.exec).replace(/%[a-zA-Z]/g, "").trim();
    if (e.runInTerminal)
      Quickshell.execDetached(["sh", "-c",
        't=kitty; command -v kitty >/dev/null 2>&1 || t=foot; command -v foot >/dev/null 2>&1 || t=alacritty; '
        + 'exec "$t" -e sh -c "$1"', "sh", cmd]);
    else
      Quickshell.execDetached(["sh", "-c", cmd]);
  }
  Process {
    id: scanProc
    command: ["bash", "-c", root.scanLs]
    stdout: StdioCollector {
      onStreamFinished: {
        // one line an id, a key and a value of its [Desktop Entry]
        const byId = {};
        for (const line of text.split("\n")) {
          const f = line.split("\t");
          if (f.length === 3) (byId[f[0]] = byId[f[0]] || {})[f[1]] = f[2];
        }
        const out = [];
        for (const id in byId) {
          const e = byId[id];
          if (e.Type !== "Application" || e.NoDisplay === "true" || !e.Name || !e.Exec) continue;
          out.push({ id: id, name: e.Name, genericName: e.GenericName || "", icon: e.Icon || "",
                     runInTerminal: e.Terminal === "true",
                     categories: (e.Categories || "").split(";").filter(c => c !== ""),
                     keywords: (e.Keywords || "").split(/[; ]/).filter(k => k !== ""),
                     exec: e.Exec, execute: () => root.scanLaunch(e) });
        }
        root.scanApps = out;
      }
    }
  }
  function scan() { if (!scanProc.running) scanProc.running = true; }
  // the list as the launcher shows it: the model first (its entries are the richer
  // ones), then what the scan saw that the model never did
  function mergedApps() {
    const seenId = new Set(), seenName = new Set(), all = [];
    for (const d of [...DesktopEntries.applications.values, ...root.scanApps]) {
      const n = String(d.name || d.id || "").trim().toLowerCase();
      if (!n || seenName.has(n) || seenId.has(d.id)) continue;
      seenId.add(d.id); seenName.add(n); all.push(d);
    }
    return all;
  }

  // 1 for a command-line program (a terminal app), 0 for the rest: they always list last
  function cliRank(d) { return (d.runInTerminal === true) ? 1 : 0; }

  ScriptModel {
    id: filteredApps
    objectProp: "id"
    values: {
      const all = root.mergedApps();
      const q = searchInput.text.trim().toLowerCase();
      if (q === "") return all.sort((a, b) => root.cliRank(a) - root.cliRank(b) || a.name.localeCompare(b.name));
      return all.filter(d =>
        (d.name && d.name.toLowerCase().includes(q)) ||
        (d.genericName && d.genericName.toLowerCase().includes(q)) ||
        (d.keywords && d.keywords.some(k => k.toLowerCase().includes(q))) ||
        (d.categories && d.categories.some(c => c.toLowerCase().includes(q)))
      ).sort((a, b) => {
        // command-line programs after the apps, whatever matches better
        const cli = root.cliRank(a) - root.cliRank(b);
        if (cli !== 0) return cli;
        const an = a.name.toLowerCase();
        const bn = b.name.toLowerCase();
        const aStarts = an.startsWith(q);
        const bStarts = bn.startsWith(q);
        if (aStarts && !bStarts) return -1;
        if (!aStarts && bStarts) return 1;
        return an.localeCompare(bn);
      });
    }
  }

  function launchApp(entry) {
    entry.execute();
    root.open = false;
  }

  PanelWindow {
    id: launcherPanel
    visible: veil.shown
    focusable: true
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: veil.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None   // none while it fades away
    WlrLayershell.namespace: veil.layerName("launcher")

    exclusionMode: ExclusionMode.Ignore

    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }

    // the desktop behind, blurred and dimmed as Window look sets; a click closes
    MouseArea {
      anchors.fill: parent
      onClicked: root.open = false

      Backdrop {
        id: veil
        open: root.open
        theme: root.theme
        tintAlpha: root.theme.bgOverlay.a
      }
    }

    // Centered launcher box
    Rectangle {
      id: launcherBox
      anchors.centerIn: parent
      opacity: veil.progress
      scale: 0.97 + 0.03 * veil.progress
      width: 580
      height: 480
      radius: 16
      color: root.theme.bgBase
      border.color: root.theme.bgBorder
      border.width: 1

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // Header
        Text {
          text: "  Applications"
          color: root.theme.accentPrimary
          font.pixelSize: 14
          font.family: root.font
          font.bold: true
        }

        // Search bar
        Rectangle {
          Layout.fillWidth: true
          height: 44
          radius: 10
          color: root.theme.bgSurface
          border.color: searchInput.activeFocus ? root.theme.accentPrimary : root.theme.bgBorder
          border.width: 1

          Behavior on border.color {
            ColorAnimation { duration: 150 }
          }

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 10

            Text {
              text: ""
              color: root.theme.textMuted
              font.pixelSize: 16
              font.family: root.font
              Layout.alignment: Qt.AlignVCenter
            }

            TextInput {
              id: searchInput
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              color: root.theme.textPrimary
              font.pixelSize: 15
              font.family: root.font
              clip: true
              focus: true
              Accessible.role: Accessible.EditableText
              Accessible.name: "Search applications"

              Text {
                anchors.fill: parent
                text: "Type to search..."
                color: root.theme.textMuted
                font: parent.font
                visible: !parent.text && !parent.activeFocus
                verticalAlignment: Text.AlignVCenter
              }

              onTextChanged: root.selectedIndex = text === "" ? -1 : 0

              Keys.onEscapePressed: root.open = false

              Keys.onPressed: event => {
                if (event.key === Qt.Key_Down) {
                  event.accepted = true;
                  root.selectedIndex = Math.min(root.selectedIndex + 1, resultsList.count - 1);
                  resultsList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                } else if (event.key === Qt.Key_Up) {
                  event.accepted = true;
                  root.selectedIndex = Math.max(root.selectedIndex - 1, 0);
                  resultsList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                  event.accepted = true;
                  if (root.selectedIndex >= 0) {
                    const entry = filteredApps.values[root.selectedIndex];
                    if (entry) root.launchApp(entry);
                  }
                } else if (event.key === Qt.Key_Tab) {
                  event.accepted = true;
                  root.selectedIndex = Math.min(root.selectedIndex + 1, resultsList.count - 1);
                  resultsList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                }
              }
            }
          }
        }

        // Results count
        Text {
          text: resultsList.count + " application" + (resultsList.count !== 1 ? "s" : "")
          color: root.theme.textMuted
          font.pixelSize: 11
          font.family: root.font
        }

        // App list
        ListView {
          id: resultsList
          Layout.fillWidth: true
          Layout.fillHeight: true
          model: filteredApps
          clip: true
          spacing: 2
          boundsBehavior: Flickable.StopAtBounds
          // the selected row paints itself (below): a highlight that follows the list's own
          // current item went stale when a search replaced the results

          delegate: Rectangle {
            id: delegateRoot
            required property var modelData
            required property int index

            Accessible.role: Accessible.Button
            Accessible.name: (modelData.name ?? "Application") + (modelData.genericName ? " - " + modelData.genericName : "")

            readonly property bool selected: root.selectedIndex === index
            width: resultsList.width
            height: 44
            radius: 8
            color: selected ? root.theme.bgSelected : "transparent"

            Rectangle {
              visible: delegateRoot.selected
              width: 3
              height: 24
              radius: 2
              color: root.theme.accentPrimary
              anchors.left: parent.left
              anchors.leftMargin: 2
              anchors.verticalCenter: parent.verticalCenter
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 12
              anchors.rightMargin: 12
              spacing: 12

              // App icon
              Item {
                width: 28
                height: 28
                Layout.alignment: Qt.AlignVCenter

                AppIcon {
                  anchors.fill: parent
                  entry: delegateRoot.modelData
                  wins: []
                  size: 28
                }

                // Fallback icon
                Text {
                  anchors.centerIn: parent
                  text: ""
                  color: root.theme.accentPrimary
                  font.pixelSize: 20
                  font.family: root.font
                  visible: (delegateRoot.modelData.icon ?? "") === ""
                }
              }

              // App info
              ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 1

                Text {
                  text: delegateRoot.modelData.name ?? ""
                  color: root.selectedIndex === delegateRoot.index ? root.theme.textPrimary : root.theme.textSecondary
                  font.pixelSize: 13
                  font.family: root.font
                  font.bold: root.selectedIndex === delegateRoot.index
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }

                Text {
                  text: delegateRoot.modelData.genericName ?? delegateRoot.modelData.comment ?? ""
                  color: root.theme.textMuted
                  font.pixelSize: 11
                  font.family: root.font
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                  visible: text !== ""
                }
              }
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.launchApp(delegateRoot.modelData)
              onPositionChanged: root.selectedIndex = delegateRoot.index
            }
          }

          // Empty state
          Text {
            anchors.centerIn: parent
            text: "  No applications found"
            color: root.theme.textMuted
            font.pixelSize: 14
            font.family: root.font
            visible: resultsList.count === 0 && searchInput.text !== ""
          }
        }

        // Footer hint
        RowLayout {
          Layout.fillWidth: true
          spacing: 16

          Row {
            spacing: 4
            Rectangle {
              width: hintUp.width + 8; height: 18; radius: 4; color: root.theme.bgSurface
              Text { id: hintUp; anchors.centerIn: parent; text: "↑↓"; color: root.theme.textMuted; font.pixelSize: 10; font.family: root.font }
            }
            Text { text: "navigate"; color: root.theme.textMuted; font.pixelSize: 10; font.family: root.font; anchors.verticalCenter: parent.verticalCenter }
          }

          Row {
            spacing: 4
            Rectangle {
              width: hintEnter.width + 8; height: 18; radius: 4; color: root.theme.bgSurface
              Text { id: hintEnter; anchors.centerIn: parent; text: "⏎"; color: root.theme.textMuted; font.pixelSize: 10; font.family: root.font }
            }
            Text { text: "launch"; color: root.theme.textMuted; font.pixelSize: 10; font.family: root.font; anchors.verticalCenter: parent.verticalCenter }
          }

          Row {
            spacing: 4
            Rectangle {
              width: hintEsc.width + 8; height: 18; radius: 4; color: root.theme.bgSurface
              Text { id: hintEsc; anchors.centerIn: parent; text: "esc"; color: root.theme.textMuted; font.pixelSize: 10; font.family: root.font }
            }
            Text { text: "close"; color: root.theme.textMuted; font.pixelSize: 10; font.family: root.font; anchors.verticalCenter: parent.verticalCenter }
          }

          Item { Layout.fillWidth: true }

          Rectangle {
            id: installAppsButton
            width: installAppsLabel.implicitWidth + 16
            height: 20
            radius: 6
            color: installAppsArea.containsMouse ? root.theme.bgHover : root.theme.bgSurface
            Text {
              id: installAppsLabel
              anchors.centerIn: parent
              text: "Install apps…"
              color: root.theme.accentPrimary
              font.pixelSize: 10
              font.family: root.font
            }
            MouseArea {
              id: installAppsArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.open = false;
                Quickshell.execDetached(["qs", "ipc", "call", "aequalyn", "page", "store"]);
              }
            }
          }
        }
      }
    }
  }
}
