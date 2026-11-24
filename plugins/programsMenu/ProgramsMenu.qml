// Full programs menu for desktop apps and installed CLI programs, with category browsing.

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "root:/plugins/docks"
import "root:/style/backdrop"
import "root:/settings"

Scope {
  id: root
  // Inline fallback palette keeps this dynamically loaded plugin self-contained.
  property var theme: ({
    bgBase: "#1a1b26", bgSurface: "#24283b", bgOverlay: "#88000000",
    bgHover: "#1e2235", bgSelected: "#283457", bgBorder: "#32364a",
    textPrimary: "#c0caf5", textSecondary: "#a9b1d6", textMuted: "#565f89",
    accentPrimary: "#7aa2f7"
  })
  property string font: AequalynSettings.monoFont

  IpcHandler {
    target: "programs"

    function toggle(): void {
      root.open = !root.open
      if (root.open) {
        if (!cliPrograms.length) cliScan.running = true
        aiToolScan.running = true
        root.activeCategory = "All"
        searchInput.text = ""
        selectedIndex = -1
        searchInput.forceActiveFocus()
      }
    }
  }

  property int selectedIndex: 0
  property bool open: false

  property string activeCategory: "All"
  property var cliPrograms: []
  property string defaultAiCommand: ""

  Process {
    id: cliScan
    command: ["bash", "-lc", "compgen -c | sort -u | while IFS= read -r c; do p=$(command -v -- \"$c\" 2>/dev/null) || continue; [ -f \"$p\" ] && [ -x \"$p\" ] && printf '%s\\n' \"$c\"; done"]
    stdout: StdioCollector { onStreamFinished: root.cliPrograms = text.trim().split("\n").filter(x => x && !["sh", "bash", "zsh", "fish", "cd", "echo", "printf", "test", "sudo", "doas"].includes(x)) }
  }

  Process {
    id: aiToolScan
    command: ["aequalyn-ai-tool", "list", "--json"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const tools = JSON.parse(text.trim());
          const selected = tools.find(tool => tool.default);
          root.defaultAiCommand = selected ? selected.command : "";
        } catch (e) {
          root.defaultAiCommand = "";
        }
      }
    }
  }

  function categoryFor(entry) {
    const id = String(entry.id || "").toLowerCase();
    const name = String(entry.name || "").toLowerCase();
    const raw = [...(entry.categories || []), ...(entry.keywords || [])].join(" ").toLowerCase();
    if (id.includes("aequalyn-webapp-") || raw.includes("webapp")) {
      const keyword = (entry.keywords || []).find(k => !["webapp", "web app"].includes(String(k).toLowerCase()));
      return keyword ? String(keyword).replace(/^./, c => c.toUpperCase()) : "Web apps";
    }
    if (raw.includes("development") || /codex|git|code|docker|kubectl|npm|cargo/.test(name)) return "Development";
    if (raw.includes("audio") || raw.includes("video") || /btop|glances|htop|top|nvidia-smi/.test(name)) return "System";
    if (raw.includes("office") || raw.includes("wordprocessor") || raw.includes("spreadsheet")) return "Office";
    if (raw.includes("game")) return "Games";
    if (raw.includes("internet") || raw.includes("network") || raw.includes("webbrowser")) return "Internet";
    if (entry.isCli) return "Utilities";
    return "Applications";
  }

  function allEntries() {
    const seen = new Set();
    const apps = [...DesktopEntries.applications.values].filter(e => {
      const key = String(e.name || e.id || "").trim().toLowerCase();
      if (!key || seen.has(key)) return false;
      seen.add(key);
      return true;
    });
    const present = new Set(apps.map(e => String(e.name || "").toLowerCase()));
    for (const name of cliPrograms) {
      if (present.has(name.toLowerCase())) continue;
      apps.push({ id: "cli-" + name, name,
        genericName: name === root.defaultAiCommand ? "Default AI tool" : "Command line program",
        isDefaultAiTool: name === root.defaultAiCommand,
        isCli: true, icon: "utilities-terminal" });
    }
    return apps;
  }

  function categoriesFor(entries) {
    return ["All", ...[...new Set(entries.map(categoryFor))].sort((a, b) => a.localeCompare(b))];
  }

  function stepCategory(delta) {
    const categories = root.categoriesFor(root.allEntries());
    if (!categories.length) return;
    const current = Math.max(0, categories.indexOf(root.activeCategory));
    root.activeCategory = categories[(current + delta + categories.length) % categories.length];
    root.selectedIndex = -1;
  }

  // 1 for a command-line program (a terminal app), 0 for the rest: they always list last
  function cliRank(d) { return (d.isCli === true || d.runInTerminal === true) ? 1 : 0; }

  ScriptModel {
    id: filteredApps
    objectProp: "id"
    values: {
      const all = root.allEntries();
      const q = searchInput.text.trim().toLowerCase();
      const categoryItems = root.activeCategory === "All" ? all : all.filter(d => root.categoryFor(d) === root.activeCategory);
      if (q === "") return categoryItems.sort((a, b) => root.cliRank(a) - root.cliRank(b) || a.name.localeCompare(b.name));
      return categoryItems.filter(d =>
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
    if (entry.isCli) Quickshell.execDetached(["sh", "-c", "if command -v xdg-terminal-exec >/dev/null 2>&1; then exec xdg-terminal-exec " + entry.name + "; elif command -v kitty >/dev/null 2>&1; then exec kitty -e " + entry.name + "; elif command -v foot >/dev/null 2>&1; then exec foot " + entry.name + "; elif command -v alacritty >/dev/null 2>&1; then exec alacritty -e " + entry.name + "; elif command -v ghostty >/dev/null 2>&1; then exec ghostty -e " + entry.name + "; fi"]);
    else entry.execute();
    root.open = false;
  }

  PanelWindow {
    id: launcherPanel
    visible: veil.shown
    focusable: true
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: veil.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None   // none while it fades away
    WlrLayershell.namespace: veil.layerName("programs-menu")

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
                } else if (searchInput.text === "" && event.key === Qt.Key_Left) {
                  event.accepted = true;
                  root.stepCategory(-1);
                } else if (searchInput.text === "" && event.key === Qt.Key_Right) {
                  event.accepted = true;
                  root.stepCategory(1);
                }
              }
            }
          }
        }

        // Browse every application category without leaving the launcher.
        Flickable {
          Layout.fillWidth: true
          height: 34
          contentWidth: categoryRow.implicitWidth
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          Row {
            id: categoryRow
            spacing: 6
            Repeater {
              model: root.categoriesFor(root.allEntries())
              delegate: Rectangle {
                id: categoryChip
                required property string modelData
                width: categoryLabel.implicitWidth + 20
                height: 28
                radius: 8
                color: root.activeCategory === modelData ? root.theme.bgSelected : root.theme.bgSurface
                border.color: root.activeCategory === modelData ? root.theme.accentPrimary : root.theme.bgBorder
                Text {
                  id: categoryLabel
                  anchors.centerIn: parent
                  text: categoryChip.modelData
                  color: root.activeCategory === categoryChip.modelData ? root.theme.accentPrimary : root.theme.textSecondary
                  font.pixelSize: 11
                  font.family: root.font
                }
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.activeCategory = categoryChip.modelData
                    root.selectedIndex = -1
                  }
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

          Rectangle {
            id: addWebAppButton
            width: addWebAppLabel.implicitWidth + 16
            height: 20
            radius: 6
            color: addWebAppArea.containsMouse ? root.theme.bgHover : root.theme.bgSurface
            Text {
              id: addWebAppLabel
              anchors.centerIn: parent
              text: "Add web app…"
              color: root.theme.accentPrimary
              font.pixelSize: 10
              font.family: root.font
            }
            MouseArea {
              id: addWebAppArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.open = false;
                Quickshell.execDetached(["qs", "ipc", "call", "store", "section", "web"]);
              }
            }
          }
        }
      }
    }
  }
}
