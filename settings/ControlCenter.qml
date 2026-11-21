// The control center: every setting of the desktop in one window, in plain words.
// Two levels: six categories down the left, the pages of the one chosen beside them,
// then the page. Each page starts with a picture of what it changes, then the choices,
// with the rarely needed ones folded under "More options".
//
// The search is the quickest way in: type anywhere and the window becomes a list of
// every setting that matches (center/SettingsIndex.js, read from the pages), as the
// Applications menu lists apps. A switch, an amount or a choice changes right there
// (Enter, ← →); anything else opens on its page, scrolled to and lit up.
//
// Opens over the blurred desktop: Super + comma, the bar's gear, or
//   qs ipc call aequalyn settings            toggle
//   qs ipc call aequalyn page <name>         open a page (see center/Pages.js)
//   qs ipc call aequalyn search <words>      open it searching
//   qs ipc call aequalyn wifi | bluetooth | bar | dock | ...   the same, by name
//
// Keys: type to search (Ctrl+K or / from anywhere), ↑ ↓ between pages, Page Up /
// Page Down between categories, Esc closes.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import "root:/settings"
import "center"
import "center/Pages.js" as Pages
import "../Plugins.js" as PluginRegistry
import "../PluginInfo.js" as PluginInfo
import "root:/plugins/kit"
import "root:/style/backdrop"

Scope {
    id: root
    property var theme: AequalynDefaultTheme {}
    property bool panelVisible: false
    property string page: "home"
    // the kept pages (Pages.kept) are made in the background once the control center has
    // been open a moment, so the first visit to one doesn't wait for it to be built
    property bool warm: false
    Timer {
        running: root.panelVisible && !root.warm
        interval: 400
        onTriggered: root.warm = true
    }
    readonly property string version: "0.1.0"

    // Lock Screens page is only shown when the user opted into the (optional)
    // SDDM theme pack during install/update. The marker is created by
    // aequalyn-sddm / the installer when themes are actually installed.
    readonly property bool lockscreensInstalled: AequalynSettings.lockscreensInstalled
    readonly property var filteredOrder: root.lockscreensInstalled ? Pages.order : Pages.order.filter(p => p !== "lockscreens")
    // the categories as shown (Login screen only when its themes are installed), and the one the page is in
    readonly property var categories: Pages.categories.map(c => Object.assign({}, c, {
        pages: c.pages.filter(p => root.filteredOrder.indexOf(p) >= 0) }))
    readonly property string category: Pages.categoryOf(root.page)
    readonly property var categoryNow: root.categories.find(c => c.key === root.category) || null
    // the page last open in each category, so coming back to one lands where you were
    property var lastPage: ({})
    onPageChanged: {
        if (root.category !== "") {
            const n = Object.assign({}, root.lastPage);
            n[root.category] = root.page;
            root.lastPage = n;
        }
    }
    function openCategory(key) {
        if (key === "") { root.goTo("home"); return; }
        const c = root.categories.find(x => x.key === key);
        if (c && c.pages.length > 0) root.goTo(root.lastPage[key] && c.pages.indexOf(root.lastPage[key]) >= 0 ? root.lastPage[key] : c.pages[0]);
    }
    function stepCategory(delta) {
        const keys = [""].concat(root.categories.map(c => c.key));
        const i = keys.indexOf(root.category);
        root.openCategory(keys[Math.max(0, Math.min(keys.length - 1, i + delta))]);
    }

    // ---- the search ------------------------------------------------------------------
    property string query: ""
    property string queryCat: ""           // a category chip, "" for all
    readonly property bool searching: root.query.trim() !== ""
    readonly property var results: Pages.search(root.query, root.queryCat)
    readonly property var resultCounts: root.searching ? Pages.counts(root.query) : ({})
    property int pick: 0
    onQueryChanged: { root.pick = 0; if (root.query.trim() === "") root.queryCat = ""; }
    onQueryCatChanged: root.pick = 0
    // a setting's value as the search shows it
    function valueText(e) {
        if (!e || !e.setting) return "";
        const v = AequalynSettings[e.setting];
        if (e.kind === "toggle") return v ? "On" : "Off";
        if (e.kind === "slider") return (Number(v) % 1 === 0 ? String(v) : Number(v).toFixed(1)) + (e.unit || "");
        if (e.kind === "choice") { const o = (e.options || []).find(x => x.key === v); return o ? o.label : String(v); }
        return "";
    }
    // change a setting from the search: a switch flips; an amount or a choice steps
    function adjust(e, dir) {
        if (!e || !e.setting) return false;
        const v = AequalynSettings[e.setting];
        if (e.kind === "toggle") { AequalynSettings.apply(e.setting, !v); return true; }
        if (e.kind === "slider") {
            const step = e.step || 1, lo = e.from !== undefined ? e.from : 0, hi = e.to !== undefined ? e.to : 100;
            const next = Math.max(lo, Math.min(hi, Number((Number(v) + dir * step).toFixed(4))));
            if (next !== Number(v)) AequalynSettings.apply(e.setting, next);
            return true;
        }
        if (e.kind === "choice" && (e.options || []).length > 0) {
            const keys = e.options.map(o => o.key);
            const i = keys.indexOf(v);
            AequalynSettings.apply(e.setting, keys[((i < 0 ? 0 : i) + dir + keys.length) % keys.length]);
            return true;
        }
        return false;
    }
    // Enter on a result: a switch flips; anything else opens its page, scrolled to it
    function activate(r) {
        if (!r) return;
        if (r.entry && r.entry.setting && r.entry.kind === "toggle") { root.adjust(r.entry, 1); return; }
        root.openResult(r);
    }
    function openResult(r) {
        const label = r.entry ? r.label : "";
        root.open(r.page + (r.tab ? ":" + r.tab : ""));
        search.text = "";
        keys.forceActiveFocus();
        if (label !== "") { root.revealWhat = label; root.revealPage = r.page; revealTimer.restart(); }
    }
    property string pendingSearch: ""
    Timer { id: searchText; interval: 350; onTriggered: { search.text = root.pendingSearch; search.forceActiveFocus(); } }
    property string revealWhat: ""
    property string revealPage: ""
    Timer {
        id: revealTimer
        interval: 60
        onTriggered: {
            const it = root.pageItem(root.revealPage);
            if (it && it.reveal) it.reveal(root.revealWhat);
        }
    }

    // pages and the controls read the palette from here
    Binding { target: Cc; property: "theme"; value: root.theme }
    Binding { target: Cc; property: "updates"; value: updates }
    Binding { target: Cc; property: "backup"; value: backup }
    Connections {
        target: Cc
        function onGoRequested(p) { root.open(p); }
        function onCloseRequested() { root.panelVisible = false; }
    }

    BackupService { id: backup }
    UpdatesService { id: updates }
    Component.onCompleted: updates.refresh()

    // the wallpaper on the screen right now, for the pictures on the pages
    FileView {
        id: wallpaperFile
        path: Quickshell.env("HOME") + "/.config/quickshell/wallpaper.conf"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: Cc.wallpaper = text().trim()
    }

    // a page by name ("wifi"), alias ("rotation") or with its sub page ("wallpaper:1")
    function open(name) {
        const r = Pages.resolve(name || "home");
        if (r.page !== "") {
            Cc.startTab = r.tab;
            root.page = r.page;
            // already showing: the page isn't made again, so switch its sub page here
            // already made (shown now, or kept): it isn't made again, so set its sub page here
            const it = root.pageItem(r.page);
            if (it && it.tabs !== undefined) it.tab = r.tab < it.tabs.length ? r.tab : 0;
        }
        root.panelVisible = true;
    }
    function pageItem(name) {
        // the loaders follow filteredOrder (Login screen may be left out): look it up there
        const i = root.filteredOrder.indexOf(name);
        const l = i >= 0 ? pageLoaders.itemAt(i) : null;
        return l && l.status === Loader.Ready ? l.item : null;
    }
    function step(delta) {
        const order = root.filteredOrder;
        const i = order.indexOf(root.page);
        Cc.startTab = 0;
        root.page = order[Math.max(0, Math.min(order.length - 1, i + delta))];
    }

    IpcHandler {
        target: "aequalyn"
        function settings(): void { root.panelVisible = !root.panelVisible }
        // a plugin's settings: its own page, or Plugins › Name (`qs ipc call aequalyn pluginPage weather`)
        function pluginPage(id: string): string {
            if (!PluginRegistry.list.some(p => p.id === id)) return "no plugin " + id;
            const pg = PluginInfo.of(id).page;
            if (pg !== "") root.open(pg);
            else KitHost.openSettings(id);
            return "ok";
        }
        // a plugin on or off, at once: `qs ipc call aequalyn plugin docks off`
        function plugin(id: string, state: string): string {
            if (id === "settings") return "the control center stays on";
            if (!PluginRegistry.list.some(p => p.id === id)) return "no plugin " + id;
            const on = state === "toggle" ? AequalynSettings.enabledPlugins.indexOf(id) < 0 : state === "on";
            if (state !== "on" && state !== "off" && state !== "toggle") return "say on, off or toggle";
            AequalynSettings.togglePlugin(id, on);
            return id + " " + (on ? "on" : "off");
        }
        function openSettings(): void { root.panelVisible = true }
        function closeSettings(): void { root.panelVisible = false }
        function page(name: string): void { root.open(name) }
        // the live ISO's "Install Aequalyn" launcher calls this: the gate's
        // window opens (the password feeds sudo on a pipe), and the installer
        // GUI starts as root on this session's Wayland. Reached through the
        // shell on purpose -- a launcher spawned from the menu is outside the
        // supervised tree, but the shell that answers for it is not.
        function install(): string {
            installProc.wayland = Quickshell.env("WAYLAND_DISPLAY") || "wayland-0"
            if (installProc.running) return "already asking"
            installProc.running = true
            return "asked"
        }
        // the control center, already searching: `qs ipc call aequalyn search "dark"`
        function search(words: string): void { root.panelVisible = true; searchText.restart(); root.pendingSearch = words }
        // the page names older parts of the shell use
        function appearance(): void { root.open("theme") }

        function displays(): void { root.open("screens") }
        function bluetooth(): void { root.open("bluetooth") }
        function wifi(): void { root.open("wifi") }
        function hyprland(): void { root.open("windows") }
        function bar(): void { root.open("bar") }
        function dock(): void { root.open("dock") }
        function updates(): void { root.open("updates") }
        function power(): void { root.open("sleep") }
    }

    // the gate half of "Install Aequalyn" (see the install() IPC above): the
    // socket this shell draws on is staged for the installer's root half,
    // and the reply (exit code, denied or not) is said in the corner
    property Process installProc: Process {
        id: installProc
        property string wayland: "wayland-0"
        command: ["sh", "-c",
            'mkdir -p "$HOME/.local/state/aequalyn/gate" '
            + '&& printf \'{"wayland": "%s"}\' "$1" > "$HOME/.local/state/aequalyn/gate/install.json" '
            + '&& aequalyn-watchdog exec-root --as settings install-aequalyn; r=$?; '
            + 'rm -f "$HOME/.local/state/aequalyn/gate/install.json"; exit $r',
            "sh", installProc.wayland]
        stdout: StdioCollector { id: installOut }
        stderr: StdioCollector { id: installErr }
        onExited: (code) => {
            const denied = (installOut.text || "").indexOf("denied") >= 0
            if (code === 0) return          // the installer GUI is up
            Quickshell.execDetached(["notify-send", "-a", "Aequalyn",
                denied ? "Install Aequalyn denied" : "Install Aequalyn failed",
                denied ? "The approval window was denied or timed out; nothing started."
                    : (((installErr.text || "") + (installOut.text || "")).trim().slice(-300)
                       || "the installer could not start")])
        }
    }

    PanelWindow {
        id: win
        visible: veil.shown
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: veil.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None   // none while it fades away
        WlrLayershell.namespace: veil.layerName("settings")
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }

        onVisibleChanged: {
            if (visible) { search.text = ""; keys.forceActiveFocus(); backup.refresh(); }
        }

        Item {
            id: keys
            anchors.fill: parent
            focus: true

            Keys.onPressed: event => {
                const ctrl = event.modifiers & Qt.ControlModifier;
                if (event.key === Qt.Key_Escape) { root.panelVisible = false; event.accepted = true; }
                else if ((ctrl && event.key === Qt.Key_K) || event.key === Qt.Key_Slash) { search.forceActiveFocus(); event.accepted = true; }
                else if (event.key === Qt.Key_Up || (ctrl && event.key === Qt.Key_Backtab)) { root.step(-1); event.accepted = true; }
                else if (event.key === Qt.Key_Down || (ctrl && event.key === Qt.Key_Tab)) { root.step(1); event.accepted = true; }
                else if (event.key === Qt.Key_PageUp) { root.stepCategory(-1); event.accepted = true; }
                else if (event.key === Qt.Key_PageDown) { root.stepCategory(1); event.accepted = true; }
                // just start typing: it goes to the search
                else if (!ctrl && event.text.length === 1 && event.text > " ") {
                    search.text += event.text;
                    search.forceActiveFocus();
                    event.accepted = true;
                }
            }

            // the desktop behind, blurred and dimmed as Window look sets; a click closes
            MouseArea {
                anchors.fill: parent
                onClicked: root.panelVisible = false
                Backdrop { id: veil; open: root.panelVisible; theme: root.theme; tintAlpha: 0.35 }
            }

            Rectangle {
                id: card
                anchors.centerIn: parent
                opacity: veil.progress
                scale: 0.97 + 0.03 * veil.progress
                width: Math.min(1320, parent.width * 0.9)
                height: Math.min(900, parent.height * 0.9)
                radius: 20
                color: Cc.theme.bgBase
                border.color: Cc.theme.bgBorder
                border.width: 1
                clip: true
                MouseArea { anchors.fill: parent; onClicked: keys.forceActiveFocus() }

                // ---- title bar: name, search, close ---------------------------------
                Item {
                    id: titleBar
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 68

                    Row {
                        id: brand
                        anchors.left: parent.left
                        anchors.leftMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10
                        Image {
                            source: "root:/assets/ae-mark.svg"
                            sourceSize.width: 42; sourceSize.height: 28
                            width: 42; height: 28
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            layer.enabled: true
                            layer.effect: MultiEffect {
                                colorization: 1.0
                                colorizationColor: Cc.theme.accentPrimary
                            }
                        }
                        Text {
                            text: "Aequalyn"
                            color: Cc.theme.textPrimary
                            font.family: Cc.sans
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Rectangle {
                        id: searchBox
                        anchors.left: brand.right
                        anchors.leftMargin: 28
                        anchors.right: closeButton.left
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        height: 42
                        radius: 12
                        color: Cc.theme.bgSurface
                        border.width: search.activeFocus ? 2 : 1
                        border.color: search.activeFocus ? Cc.theme.accentPrimary : Cc.theme.bgBorder

                        Text {
                            id: searchIcon
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            text: "\u{F0349}"
                            color: Cc.theme.accentPrimary
                            font.family: Cc.mono
                            font.pixelSize: 16
                        }
                        TextInput {
                            id: search
                            anchors.left: searchIcon.right
                            anchors.leftMargin: 10
                            anchors.right: keyHint.left
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            color: Cc.theme.textPrimary
                            font.family: Cc.sans
                            font.pixelSize: 14
                            clip: true
                            selectByMouse: true
                            onTextChanged: root.query = text
                            Keys.onPressed: event => {
                                const r = root.results[root.pick];
                                const inline = r && r.entry && r.entry.setting && (r.entry.kind === "slider" || r.entry.kind === "choice");
                                if (event.key === Qt.Key_Escape) {
                                    if (text !== "") text = "";
                                    else keys.forceActiveFocus();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Down) {
                                    root.pick = Math.min(root.results.length - 1, root.pick + 1); event.accepted = true;
                                } else if (event.key === Qt.Key_Up) {
                                    root.pick = Math.max(0, root.pick - 1); event.accepted = true;
                                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    root.activate(r);
                                    event.accepted = true;
                                } else if ((event.key === Qt.Key_Left || event.key === Qt.Key_Right) && inline) {
                                    root.adjust(r.entry, event.key === Qt.Key_Right ? 1 : -1);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                                    // the next category chip
                                    const cats = [""].concat(root.categories.map(c => c.key)).filter(k => k === "" || (root.resultCounts[k] || 0) > 0);
                                    const i = cats.indexOf(root.queryCat);
                                    root.queryCat = cats[(i + (event.key === Qt.Key_Tab ? 1 : cats.length - 1)) % cats.length];
                                    event.accepted = true;
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: search.text === ""
                                text: "Search every setting, like “dark”, “bigger bar” or “headphones”"
                                color: Cc.theme.textMuted
                                font: search.font
                            }
                        }
                        Text {
                            id: keyHint
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            text: "ctrl k"
                            color: Cc.theme.textMuted
                            font.family: Cc.mono
                            font.pixelSize: 11
                        }
                    }

                    Rectangle {
                        id: closeButton
                        anchors.right: parent.right
                        anchors.rightMargin: 18
                        anchors.verticalCenter: parent.verticalCenter
                        width: 34; height: 34; radius: 10
                        color: closeArea.containsMouse ? Cc.theme.bgHover : "transparent"
                        Accessible.role: Accessible.Button
                        Accessible.name: "Close"
                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            color: Cc.theme.textSecondary
                            font.family: Cc.sans
                            font.pixelSize: 14
                        }
                        MouseArea {
                            id: closeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.panelVisible = false
                        }
                    }
                }
                Rectangle { anchors.top: titleBar.bottom; width: parent.width; height: 1; color: Cc.theme.bgBorder }

                // ---- the categories: Home and six, down the left --------------------------
                Column {
                    id: rail
                    anchors.left: parent.left
                    anchors.top: titleBar.bottom
                    anchors.topMargin: 12
                    width: 96
                    spacing: 4
                    Repeater {
                        model: [{ key: "", title: "Home", icon: "\u{F02DC}" }].concat(root.categories)
                        delegate: Item {
                            id: cat
                            required property var modelData
                            readonly property bool on: root.category === modelData.key && !root.searching
                            width: rail.width
                            height: 64
                            Accessible.role: Accessible.PageTab
                            Accessible.name: modelData.title
                            Rectangle {
                                id: catBox
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 6
                                width: 40; height: 34; radius: 10
                                color: cat.on ? Cc.theme.bgSelected : (catArea.containsMouse ? Cc.theme.bgSurface : "transparent")
                                border.width: cat.on ? 1 : 0
                                border.color: Cc.theme.accentPrimary
                                Text {
                                    anchors.centerIn: parent
                                    text: cat.modelData.icon
                                    color: cat.on ? Cc.theme.accentPrimary : Cc.theme.textSecondary
                                    font.family: Cc.mono
                                    font.pixelSize: 17
                                }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: catBox.bottom
                                anchors.topMargin: 4
                                text: cat.modelData.title
                                color: cat.on ? Cc.theme.textPrimary : Cc.theme.textMuted
                                font.family: Cc.mono
                                font.pixelSize: 11
                                font.bold: cat.on
                            }
                            MouseArea {
                                id: catArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { search.text = ""; root.openCategory(cat.modelData.key); }
                            }
                        }
                    }
                }
                Rectangle { anchors.left: rail.right; anchors.top: titleBar.bottom; anchors.bottom: footer.top; width: 1; color: Cc.theme.bgBorder }

                // ---- the pages of the category, beside it -------------------------------------
                Item {
                    id: side
                    anchors.left: rail.right
                    anchors.leftMargin: 1
                    anchors.top: titleBar.bottom
                    anchors.bottom: footer.top
                    // Home has no pages of its own: the page takes the room
                    width: root.categoryNow && !root.searching ? 214 : 0
                    visible: width > 0
                    clip: true
                    // It takes its room at once, never by animating its width: the page area is
                    // laid out from it, and a width that moves lays every page out again on each
                    // frame of the animation. Its list slides in instead, which only moves pixels.
                    onVisibleChanged: if (visible) navIn.restart()

                    Column {
                        id: nav
                        x: 12
                        y: 16
                        width: 214 - 24
                        spacing: 2
                        transform: Translate { id: navShift }
                        ParallelAnimation {
                            id: navIn
                            NumberAnimation { target: nav; property: "opacity"; from: 0; to: 1; duration: 150; easing.type: Easing.OutCubic }
                            NumberAnimation { target: navShift; property: "x"; from: -14; to: 0; duration: 180; easing.type: Easing.OutCubic }
                        }
                        Text {
                            leftPadding: 8
                            text: root.categoryNow ? root.categoryNow.icon + "  " + root.categoryNow.title : ""
                            color: Cc.theme.accentPrimary
                            font.family: Cc.mono
                            font.pixelSize: 14
                            font.bold: true
                        }
                        Text {
                            leftPadding: 8
                            bottomPadding: 10
                            text: root.categoryNow ? root.categoryNow.pages.length + (root.categoryNow.pages.length === 1 ? " page" : " pages") : ""
                            color: Cc.theme.textMuted
                            font.family: Cc.mono
                            font.pixelSize: 11
                        }
                        Repeater {
                            model: root.categoryNow ? root.categoryNow.pages : []
                            delegate: Rectangle {
                                id: navItem
                                required property string modelData
                                readonly property var info: Pages.pages[modelData]
                                readonly property bool on: root.page === modelData
                                width: nav.width
                                height: 38
                                radius: 8
                                color: on ? Cc.theme.bgSelected : (navArea.containsMouse ? Cc.theme.bgSurface : "transparent")
                                Accessible.role: Accessible.PageTab
                                Accessible.name: info.label
                                // the chosen page, as the Applications menu marks it: a bar at its left
                                Rectangle {
                                    visible: navItem.on
                                    width: 3; height: 20; radius: 2
                                    anchors.left: parent.left
                                    anchors.leftMargin: 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Cc.theme.accentPrimary
                                }
                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 10
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 18
                                        horizontalAlignment: Text.AlignHCenter
                                        text: navItem.info.icon
                                        color: Cc.theme.accentPrimary
                                        font.family: Cc.mono
                                        font.pixelSize: 14
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: navItem.info.label
                                        color: navItem.on ? Cc.theme.textPrimary : Cc.theme.textSecondary
                                        font.family: Cc.sans
                                        font.pixelSize: 13
                                        font.weight: navItem.on ? Font.DemiBold : Font.Normal
                                    }
                                }
                                MouseArea {
                                    id: navArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.goTo(navItem.modelData)
                                }
                            }
                        }
                    }
                }
                Rectangle { visible: side.visible; anchors.left: side.right; anchors.top: titleBar.bottom; anchors.bottom: footer.top; width: 1; color: Cc.theme.bgBorder }

                // ---- the page ------------------------------------------------------------
                // One loader per page. A kept page (Pages.kept: the ones with live
                // pictures) is made the first time it is shown and then stays, painted,
                // so its pictures are there at once every time after; any other page is
                // made when shown and dropped when left, so its scans and timers only run
                // while you look at it.
                Item {
                    id: pageArea
                    clip: true
                    anchors.left: side.visible ? side.right : rail.right
                    anchors.leftMargin: 32
                    anchors.right: parent.right
                    anchors.rightMargin: 22
                    anchors.top: titleBar.bottom
                    anchors.topMargin: 26
                    anchors.bottom: footer.top
                    anchors.bottomMargin: 4

                    // the room a page has when it is shown: all of it for Home, the room beside
                    // the pages list for a page in a category
                    readonly property real wideRoom: width + (side.visible ? side.width + side.anchors.leftMargin : 0)
                    readonly property real narrowRoom: wideRoom - 214 - side.anchors.leftMargin

                    Repeater {
                        id: pageLoaders
                        model: root.filteredOrder
                        delegate: Loader {
                            id: pageLoader
                            required property string modelData
                            readonly property bool current: root.page === modelData
                            readonly property bool kept: Pages.kept.indexOf(modelData) >= 0
                            // A kept page out of view stays drawn for a moment, just outside the
                            // page area (which clips it) and out of reach: its pictures (canvases,
                            // which only paint while drawn) are painted then, in the background,
                            // not all at once when you switch to it. Opacity 0 would skip them: Qt
                            // doesn't draw it. Then it rests, not drawn at all: the clip hides it
                            // but doesn't stop it being drawn, and nine pages drawn on every frame
                            // made each frame of a switch slow. Its pictures keep what they painted.
                            // Every page keeps the width it is shown at, hidden or not, so going
                            // to Home, a category or the search never lays a page out again.
                            width: Pages.categoryOf(modelData) === "" ? pageArea.wideRoom : pageArea.narrowRoom
                            height: pageArea.height
                            x: current ? 0 : pageArea.wideRoom + 64
                            property bool resting: false
                            visible: current || (kept && !resting)
                            enabled: current
                            Timer {
                                id: restTimer
                                interval: 800
                                onTriggered: if (!pageLoader.current) pageLoader.resting = true
                            }
                            // Coming into view it fades and rises a little: opacity and a shift
                            // move what is drawn already, nothing is laid out or painted again
                            property real enter: 1
                            opacity: current ? 0.35 + 0.65 * enter : 1
                            transform: Translate { y: (1 - pageLoader.enter) * 10 }
                            onCurrentChanged: {
                                if (current) { resting = false; restTimer.stop(); enterAnim.restart(); }
                                else restTimer.restart();
                            }
                            NumberAnimation { id: enterAnim; target: pageLoader; property: "enter"; from: 0; to: 1; duration: 170; easing.type: Easing.OutCubic }
                            // made when first shown, or, for a kept page, in the background soon
                            // after the control center opens (a bit at a time, so nothing stalls),
                            // so it is ready the first time you go to it; a kept page then stays made
                            property bool made: false
                            active: (current && root.panelVisible) || (kept && (made || root.warm))
                            // the page you go to is made at once; the others in the background
                            asynchronous: !current
                            onLoaded: {
                                made = true;
                                // made in the background: drawn while its pictures paint, then rests
                                if (!current) restTimer.restart();
                                // the sub page asked for, when the page is opened by name
                                if (current && item.tabs !== undefined && Cc.startTab < item.tabs.length) item.tab = Cc.startTab;
                            }
                            source: Qt.resolvedUrl("center/pages/" + Pages.pages[modelData].file + ".qml")
                            onStatusChanged: if (status === Loader.Error) console.error("control center: page failed to load:", modelData)
                        }
                    }
                }

                // ---- footer --------------------------------------------------------------
                Rectangle {
                    id: footer
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 34
                    color: "transparent"
                    Rectangle { width: parent.width; height: 1; color: Cc.theme.bgBorder }
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.searching
                            ? "↑ ↓  move     ⏎  change or open     ← →  adjust     tab  category     esc  clear"
                            : "↑ ↓  pages     pg up pg dn  categories     ctrl k  search     esc  close"
                        color: Cc.theme.textMuted
                        font.family: Cc.mono
                        font.pixelSize: 10
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Changes are saved as you make them"
                        color: Cc.theme.textMuted
                        font.family: Cc.sans
                        font.pixelSize: 11
                    }
                }

                // ---- the search: every setting that matches, in place of the page -------------
                Rectangle {
                    id: resultsView
                    visible: root.searching
                    anchors.left: rail.right
                    anchors.leftMargin: 1
                    anchors.right: parent.right
                    anchors.top: titleBar.bottom
                    anchors.topMargin: 1
                    anchors.bottom: footer.top
                    color: Cc.theme.bgBase
                    z: 10

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 32
                        anchors.rightMargin: 22
                        anchors.topMargin: 20
                        anchors.bottomMargin: 8
                        spacing: 12

                        // the categories, as the Applications menu's chips (tab steps through them)
                        Flow {
                            Layout.fillWidth: true
                            spacing: 6
                            Repeater {
                                model: [{ key: "", title: "All" }].concat(root.categories)
                                delegate: Rectangle {
                                    id: chip
                                    required property var modelData
                                    readonly property int n: root.resultCounts[modelData.key] || 0
                                    readonly property bool on: root.queryCat === modelData.key
                                    visible: modelData.key === "" || n > 0 || on
                                    width: chipText.implicitWidth + 20
                                    height: 28
                                    radius: 8
                                    color: on ? Cc.theme.bgSelected : (chipArea.containsMouse ? Cc.theme.bgHover : Cc.theme.bgSurface)
                                    border.width: 1
                                    border.color: on ? Cc.theme.accentPrimary : Cc.theme.bgBorder
                                    Text {
                                        id: chipText
                                        anchors.centerIn: parent
                                        text: chip.modelData.title + "  " + chip.n
                                        color: chip.on ? Cc.theme.accentPrimary : Cc.theme.textSecondary
                                        font.family: Cc.mono
                                        font.pixelSize: 11
                                    }
                                    MouseArea {
                                        id: chipArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: { root.queryCat = chip.modelData.key; search.forceActiveFocus(); }
                                    }
                                }
                            }
                        }
                        Text {
                            text: root.results.length === 0 ? "" : root.results.length + (root.results.length === 1 ? " setting" : " settings")
                            color: Cc.theme.textMuted
                            font.family: Cc.mono
                            font.pixelSize: 11
                        }
                        Text {
                            visible: root.results.length === 0
                            Layout.fillWidth: true
                            text: "Nothing matches “" + root.query.trim() + "”. Try other words, like “dark”, “bigger” or “headphones”."
                            color: Cc.theme.textMuted
                            font.family: Cc.sans
                            font.pixelSize: 13
                            wrapMode: Text.WordWrap
                        }

                        ListView {
                            id: resultList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 2
                            model: root.results
                            currentIndex: root.pick
                            boundsBehavior: Flickable.StopAtBounds
                            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                            highlightMoveDuration: 120
                            highlight: Rectangle {
                                radius: 8
                                color: Cc.theme.bgSelected
                                Rectangle {
                                    width: 3; height: 24; radius: 2
                                    anchors.left: parent.left
                                    anchors.leftMargin: 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Cc.theme.accentPrimary
                                }
                            }
                            delegate: Item {
                                id: res
                                required property var modelData
                                required property int index
                                readonly property var e: modelData.entry
                                readonly property bool editable: !!(e && e.setting)
                                readonly property bool on: root.pick === index
                                width: resultList.width
                                height: 50
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onPositionChanged: root.pick = res.index
                                    onClicked: { root.pick = res.index; root.activate(res.modelData); }
                                }
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 12
                                    spacing: 12
                                    Text {
                                        Layout.preferredWidth: 20
                                        horizontalAlignment: Text.AlignHCenter
                                        text: res.modelData.icon
                                        color: Cc.theme.accentPrimary
                                        font.family: Cc.mono
                                        font.pixelSize: 16
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Text {
                                            Layout.fillWidth: true
                                            text: res.modelData.label
                                            color: res.on ? Cc.theme.textPrimary : Cc.theme.textSecondary
                                            font.family: Cc.sans
                                            font.pixelSize: 13
                                            font.weight: res.on ? Font.DemiBold : Font.Normal
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: res.modelData.where
                                            color: Cc.theme.textMuted
                                            font.family: Cc.mono
                                            font.pixelSize: 11
                                            elide: Text.ElideRight
                                        }
                                    }
                                    // a switch: flips here
                                    CcSwitch {
                                        visible: res.editable && res.e.kind === "toggle"
                                        checked: res.editable ? !!AequalynSettings[res.e.setting] : false
                                        onToggled: v => AequalynSettings.apply(res.e.setting, v)
                                    }
                                    // an amount or a choice: ‹ value ›
                                    RowLayout {
                                        visible: res.editable && res.e.kind !== "toggle"
                                        spacing: 6
                                        StepButton { glyph: "‹"; onClicked: root.adjust(res.e, -1) }
                                        Text {
                                            Layout.preferredWidth: 150
                                            horizontalAlignment: Text.AlignHCenter
                                            text: root.valueText(res.e)
                                            color: Cc.theme.accentPrimary
                                            font.family: Cc.mono
                                            font.pixelSize: 12
                                            elide: Text.ElideRight
                                        }
                                        StepButton { glyph: "›"; onClicked: root.adjust(res.e, 1) }
                                    }
                                    Text {
                                        visible: !res.editable
                                        text: "Open  ›"
                                        color: res.on ? Cc.theme.accentPrimary : Cc.theme.textMuted
                                        font.family: Cc.mono
                                        font.pixelSize: 11
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // open a page from the window itself: the search is done with
    function goTo(p) {
        Cc.startTab = 0;
        root.page = p;
        search.text = "";
        keys.forceActiveFocus();
    }

    // ‹ and › beside an amount or a choice in the search
    component StepButton: Rectangle {
        id: sb
        property string glyph: ""
        signal clicked()
        Layout.preferredWidth: 26
        Layout.preferredHeight: 26
        radius: 7
        color: sbArea.containsMouse ? Cc.theme.bgHover : Cc.theme.bgSurface
        border.width: 1
        border.color: Cc.theme.bgBorder
        Text {
            anchors.centerIn: parent
            text: sb.glyph
            color: Cc.theme.textSecondary
            font.family: Cc.mono
            font.pixelSize: 14
        }
        MouseArea {
            id: sbArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: sb.clicked()
        }
    }
}
