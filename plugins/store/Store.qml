// The Store: plugins, themes, cursors, wallpaper packs and looks from git, every one
// checked before it is kept (bin/aequalyn-store does the work; this is its window), and
// a door to the package search for apps. Super + Alt + S, or `qs ipc call store open`
// (`section <name>` opens it on a section, `install <kind> <git-url>` installs).
//
// Sections on the left, the chosen one's page beside them, drawn like the control
// center over the blurred desktop. Every action runs aequalyn-store, and its report
// shows live under the page.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "root:/settings"
import "root:/style/backdrop"

Scope {
    id: root
    property var theme: ({
        bgBase: "#121515", bgSurface: "#1a1f1f", bgHover: "#202727", bgSelected: "#26383a",
        bgBorder: "#2f3a3a", textPrimary: "#dde5e3", textSecondary: "#b2bfbc", textMuted: "#6c7a78",
        accentPrimary: "#4fc1b0", accentGreen: "#8bc79a", accentOrange: "#e0a96c", accentRed: "#e06c6c"
    })
    readonly property string font: "JetBrainsMono Nerd Font"
    property bool open: false
    property string section: "home"

    readonly property var sections: [
        { key: "home",      label: "Home",       glyph: "\u{F02DC}" },
        { key: "plugin",    label: "Plugins",    glyph: "\u{F0431}" },
        { key: "theme",     label: "Themes",     glyph: "\u{F03D8}" },
        { key: "cursor",    label: "Cursors",    glyph: "\u{F01BE}" },
        { key: "wallpaper", label: "Wallpapers", glyph: "\u{F02E9}" },
        { key: "look",      label: "Looks",      glyph: "\u{F0E09}" },
        { key: "apps",      label: "Apps",       glyph: "\u{F003B}" },
        { key: "market",    label: "Market",     glyph: "\u{F0110}" },
        { key: "updates",   label: "Updates",    glyph: "\u{F06B0}" }
    ]
    readonly property var kindWords: ({
        plugin: { one: "plugin", hint: "A git repo with a plugin.json: it is checked (its files, qmllint, what it may run), then installed into ~/.local/share/aequalyn/plugins and switched on at once." },
        theme: { one: "theme", hint: "A git repo with a theme.json (or colors.toml) and a backgrounds/ folder. It is checked, then lands in ~/.config/aequalyn/themes and shows in Super + T." },
        cursor: { one: "cursor", hint: "A git repo with an XCursor cursors/ folder or a Hyprcursor manifest. It lands in ~/.local/share/icons; wear it here or on the Cursor page." },
        wallpaper: { one: "wallpaper pack", hint: "A git repo with an index.json listing its wallpapers: each file is fetched from the pack's own repo, checked, and kept in ~/.local/share/aequalyn/wallpapers." },
        look: { one: "look", hint: "A git repo with a look.json: a bar look, a dock look, a cursor look, a lock screen, lock and sleep timings, a login (SDDM) theme, or several. Wear all of it or one piece." }
    })
    readonly property var pieceWords: ({ bar: "Bar", dock: "Docks", cursor: "Cursor", lock: "Lock screen", sleep: "Lock and sleep", sddm: "Login screen" })

    // ---- what is installed ------------------------------------------------------------
    property var installed: []
    function itemsOf(kind) { return root.installed.filter(i => i.kind === kind); }
    function refresh() { if (!listProc.running) listProc.running = true; }
    Process {
        id: listProc
        command: ["aequalyn-store", "list", "--json"]
        stdout: StdioCollector {
            onStreamFinished: { try { root.installed = JSON.parse(text); } catch (e) { root.installed = []; } }
        }
    }

    // ---- the Market's catalog (aequalyn-store refresh keeps it, checked) ---------------
    property var market: []
    property bool marketLoaded: false
    function loadMarket() { if (!marketProc.running) marketProc.running = true; }
    Process {
        id: marketProc
        command: ["aequalyn-store", "market", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.market = JSON.parse(text); root.marketLoaded = true; }
                catch (e) { root.market = []; root.marketLoaded = false; }
            }
        }
    }
    onSectionChanged: {
        if (section === "market") { loadMarket(); if (!busy) runJob("Refreshing the catalog", ["refresh"]); }
        if (section === "apps") { detectApps(); if (root.foundPage === 0) searchApps("", false); }
    }

    // ---- apps: the curated grid (apps.json) and the four backends ----------------------
    // pacman always; yay (the AUR), flatpak (Flathub) and snap when they are installed.
    // Installs run in a terminal, where sudo asks for the password.
    property var apps: []
    property var backends: ({ yay: false, flatpak: false, snap: false })
    property var installedPkgs: ({ pacman: [], flatpak: [], snap: [] })
    FileView {
        path: Qt.resolvedUrl("apps.json").toString().replace("file://", "")
        onLoaded: { try { root.apps = JSON.parse(text()); } catch (e) { root.apps = []; } }
    }
    function detectApps() { if (!detect.running) detect.running = true; }
    Process {
        id: detect
        command: ["sh", "-c", 'for b in yay flatpak snap; do command -v "$b" >/dev/null 2>&1 && echo "has $b"; done; '
            + 'echo "#pacman"; pacman -Qq 2>/dev/null; echo "#flatpak"; flatpak list --app --columns=application 2>/dev/null; '
            + 'echo "#snap"; snap list 2>/dev/null | tail -n +2 | cut -d" " -f1']
        stdout: StdioCollector {
            onStreamFinished: {
                const b = { yay: false, flatpak: false, snap: false };
                const got = { pacman: [], flatpak: [], snap: [] };
                let part = "";
                for (const line of text.split("\n")) {
                    if (line.startsWith("has ")) b[line.slice(4)] = true;
                    else if (line.startsWith("#")) part = line.slice(1);
                    else if (line !== "" && got[part]) got[part].push(line.trim());
                }
                root.backends = b;
                root.installedPkgs = got;
            }
        }
    }
    // which backend this app is installed from, or ""
    function installedVia(a) {
        const pk = a.pacman || a.aur;
        if (pk && root.installedPkgs.pacman.indexOf(pk) >= 0) return a.pacman ? "Arch" : "AUR";
        if (a.flatpak && root.installedPkgs.flatpak.indexOf(a.flatpak) >= 0) return "Flatpak";
        if (a.snap && root.installedPkgs.snap.indexOf(a.snap) >= 0) return "Snap";
        return "";
    }
    // a command in a terminal, kept open at the end so its output can be read
    Process {
        id: terminal
        onExited: root.detectApps()
    }
    function inTerminal(cmd) {
        if (terminal.running) return;
        const tail = cmd + '; echo; read -rp "Done. Press Enter to close " _';
        terminal.command = ["sh", "-c", 'if command -v kitty >/dev/null; then exec kitty sh -c "$1"; '
            + 'elif command -v foot >/dev/null; then exec foot sh -c "$1"; else exec alacritty -e sh -c "$1"; fi', "sh", tail];
        terminal.running = true;
    }
    readonly property string flathub: "flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo"
    // every app from every backend: aequalyn-store search-apps (no words: Flathub's most
    // installed, page by page, and Snap's featured)
    property var found: []
    property var foundErrors: ({})
    property string foundQuery: ""
    property int foundPage: 0
    property int flathubPages: 1
    property string foundSource: "All"
    property bool searching: false
    function searchApps(q, more) {
        if (searchProc.running) return;
        root.foundPage = more ? root.foundPage + 1 : 1;
        if (!more) { root.found = []; root.foundQuery = q; }
        root.searching = true;
        searchProc.command = ["aequalyn-store", "search-apps"].concat(q !== "" ? [q] : []).concat(["--page", String(root.foundPage)]);
        searchProc.running = true;
    }
    Process {
        id: searchProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.searching = false;
                try {
                    const d = JSON.parse(text);
                    root.found = root.found.concat(d.results);
                    root.foundErrors = d.errors || {};
                    root.flathubPages = d.flathubPages || 1;
                } catch (e) { root.foundErrors = { all: "the search failed" }; }
            }
        }
    }
    function foundInstalled(r) {
        if (r.source === "Arch" || r.source === "AUR") return root.installedPkgs.pacman.indexOf(r.id) >= 0;
        if (r.source === "Flatpak") return root.installedPkgs.flatpak.indexOf(r.id) >= 0;
        return root.installedPkgs.snap.indexOf(r.id) >= 0;
    }
    function installFound(r) {
        const a = r.source === "Arch" ? { pacman: r.id } : r.source === "AUR" ? { aur: r.id }
                : r.source === "Flatpak" ? { flatpak: r.id } : { snap: r.id, snapAsk: true };
        root.installApp(a, r.source);
    }
    function installApp(a, via) {
        // only plain package names ever reach the shell
        const name = a.pacman || a.aur || a.flatpak || a.snap || "";
        if (!/^[A-Za-z0-9@._+-]{1,128}$/.test(name)) return;
        if (via === "Snap" && a.snapAsk) {
            root.inTerminal("sudo snap install " + name + " || { echo; read -rp \"" + name + " asks for classic confinement: it can reach your whole system. Install it that way? [y/N] \" a; "
                            + "[ \"$a\" = y ] && sudo snap install " + name + " --classic; }");
            return;
        }
        if (via === "Arch") root.inTerminal("sudo pacman -S --needed " + a.pacman);
        else if (via === "AUR") root.inTerminal("yay -S --needed " + a.aur);
        else if (via === "Flatpak") root.inTerminal(root.flathub + " && flatpak install --user -y flathub " + a.flatpak);
        else if (via === "Snap") root.inTerminal("sudo snap install " + a.snap + (a.snapClassic ? " --classic" : ""));
    }
    function installBackend(name) {
        if (name === "yay") root.inTerminal("sudo pacman -S --needed git base-devel && d=$(mktemp -d) && git clone https://aur.archlinux.org/yay-bin.git \"$d\" && cd \"$d\" && makepkg -si");
        else if (name === "flatpak") root.inTerminal("sudo pacman -S --needed flatpak && " + root.flathub);
        else if (name === "snap") root.inTerminal("yay -S --needed snapd && sudo systemctl enable --now snapd.socket && sudo ln -sfn /var/lib/snapd/snap /snap");
    }
    onOpenChanged: if (open && section === "apps") detectApps()

    // ---- one job at a time, its report live -------------------------------------------
    property bool busy: false
    property string jobTitle: ""
    property int jobCode: -1
    ListModel { id: logModel }
    function runJob(title, args) {
        if (root.busy) return;
        logModel.clear();
        root.jobTitle = title;
        root.jobCode = -1;
        root.busy = true;
        job.command = ["aequalyn-store"].concat(args);
        job.running = true;
    }
    Process {
        id: job
        stdout: SplitParser { onRead: line => logModel.append({ line: line }) }
        stderr: SplitParser { onRead: line => logModel.append({ line: line }) }
        onExited: code => {
            root.busy = false;
            root.jobCode = code;
            root.refresh();
            root.loadMarket();
            UserPlugins.rescan();
        }
    }
    Process { id: side }
    function runSide(cmd) { side.command = cmd; side.running = true; }

    // ---- IPC ----------------------------------------------------------------------------
    IpcHandler {
        target: "store"
        function open(): void { root.open = true; root.refresh(); }
        function close(): void { root.open = false; }
        function toggle(): void { root.open = !root.open; if (root.open) root.refresh(); }
        // open on a section: home, plugin, theme, cursor, wallpaper, look, apps, market, updates
        function section(name: string): string {
            const section = name;
            if (!root.sections.some(s => s.key === section)) return "no section " + section;
            root.section = section; root.open = true; root.refresh(); return "ok";
        }
        // look for apps in Arch, the AUR, Flathub and Snap
        function search(words: string): void {
            root.section = "apps"; root.open = true; root.detectApps(); root.searchApps(words, false);
        }
        // install from a git URL (or a folder), with every check first
        function install(kind: string, source: string): string {
            if (!root.kindWords[kind]) return "no kind " + kind;
            root.section = kind; root.open = true;
            root.runJob("Installing " + source, ["install", kind, source]);
            return "ok";
        }
    }

    // ---- small parts --------------------------------------------------------------------
    component Btn: Rectangle {
        id: btn
        property string text: ""
        property bool primary: false
        property bool danger: false
        signal clicked()
        implicitHeight: 30
        implicitWidth: label.implicitWidth + 24
        radius: 8
        opacity: enabled ? 1 : 0.45
        color: primary ? (ma.containsMouse ? Qt.lighter(root.theme.accentPrimary, 1.1) : root.theme.accentPrimary)
             : ma.containsMouse ? root.theme.bgHover : root.theme.bgSurface
        border.width: primary ? 0 : 1
        border.color: danger && ma.containsMouse ? root.theme.accentRed : root.theme.bgBorder
        Text {
            id: label
            anchors.centerIn: parent
            text: btn.text
            color: btn.primary ? root.theme.bgBase : btn.danger ? root.theme.accentRed : root.theme.textPrimary
            font.family: root.font
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: btn.clicked() }
    }
    component Field: Rectangle {
        id: fld
        property alias text: input.text
        property string placeholder: ""
        Layout.fillWidth: true
        implicitHeight: 32
        radius: 8
        color: root.theme.bgBase
        border.width: 1
        border.color: input.activeFocus ? root.theme.accentPrimary : root.theme.bgBorder
        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            verticalAlignment: TextInput.AlignVCenter
            color: root.theme.textPrimary
            font.family: root.font
            font.pixelSize: 12
            clip: true
            selectByMouse: true
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: input.text === ""
                text: fld.placeholder
                color: root.theme.textMuted
                font: input.font
            }
        }
    }
    component Box: Rectangle {
        default property alias content: col.data
        property string title: ""
        property string hint: ""
        Layout.fillWidth: true
        implicitHeight: col.implicitHeight + 28
        radius: 12
        color: root.theme.bgSurface
        border.width: 1
        border.color: root.theme.bgBorder
        ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10
            Text {
                visible: parent.parent.title !== ""
                text: parent.parent.title
                color: root.theme.textPrimary
                font.family: root.font
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
            Text {
                visible: parent.parent.hint !== ""
                text: parent.parent.hint
                color: root.theme.textMuted
                font.family: root.font
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }
    }
    component Pill: Rectangle {
        property string text: ""
        property color tone: root.theme.accentGreen
        implicitWidth: pt.implicitWidth + 14
        implicitHeight: 20
        radius: 10
        color: Qt.rgba(tone.r, tone.g, tone.b, 0.16)
        Text { id: pt; anchors.centerIn: parent; text: parent.text; color: parent.tone; font.family: root.font; font.pixelSize: 10; font.weight: Font.DemiBold }
    }

    // one installed item: its name, where it came from, its state and its actions
    component ItemRow: Rectangle {
        id: row
        required property var modelData
        readonly property string kind: modelData.kind
        readonly property bool pluginOn: kind === "plugin" && (AequalynSettings.enabledPlugins || []).indexOf(modelData.id) >= 0
        Layout.fillWidth: true
        implicitHeight: rowCol.implicitHeight + 20
        radius: 10
        color: root.theme.bgBase
        ColumnLayout {
            id: rowCol
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8
            RowLayout {
                spacing: 10
                ColumnLayout {
                    spacing: 2
                    Layout.fillWidth: true
                    RowLayout {
                        spacing: 8
                        Text { text: row.modelData.label || row.modelData.id; color: root.theme.textPrimary; font.family: root.font; font.pixelSize: 13; font.weight: Font.DemiBold }
                        Pill { visible: row.kind === "plugin"; text: row.pluginOn ? "Active" : "Inactive"; tone: row.pluginOn ? root.theme.accentGreen : root.theme.textMuted }
                        Pill { visible: row.modelData.present === false; text: "Missing"; tone: root.theme.accentRed }
                    }
                    Text {
                        text: (row.modelData.version ? "v" + row.modelData.version + "  ·  " : "")
                            + (row.modelData.commit ? row.modelData.commit.slice(0, 12) + "  ·  " : "")
                            + (row.modelData.source || "")
                        color: root.theme.textMuted; font.family: root.font; font.pixelSize: 10
                        elide: Text.ElideMiddle; Layout.fillWidth: true
                    }
                }
                Btn {
                    visible: row.kind === "plugin"
                    text: row.pluginOn ? "Deactivate" : "Activate"
                    onClicked: AequalynSettings.togglePlugin(row.modelData.id, !row.pluginOn)
                }
                Btn {
                    visible: row.kind === "theme"
                    text: "Apply"
                    primary: true
                    onClicked: root.runSide(["qs", "ipc", "call", "theme", "set", row.modelData.id])
                }
                Btn {
                    visible: row.kind === "cursor"
                    text: "Wear"
                    primary: true
                    onClicked: root.runSide(["sh", "-c", 'hyprctl setcursor "$1" 24 && gsettings set org.gnome.desktop.interface cursor-theme "$1"', "sh", row.modelData.id])
                }
                Btn {
                    visible: row.kind === "look"
                    text: "Wear all"
                    primary: true
                    enabled: !root.busy
                    onClicked: root.runJob("Wearing " + (row.modelData.label || row.modelData.id), ["apply-look", row.modelData.id])
                }
                Btn {
                    text: "Update"
                    enabled: !root.busy
                    onClicked: root.runJob("Updating " + row.modelData.id, ["update", row.kind, row.modelData.id])
                }
                Btn {
                    text: "Remove"
                    danger: true
                    enabled: !root.busy
                    onClicked: root.runJob("Removing " + row.modelData.id, ["remove", row.kind, row.modelData.id])
                }
            }
            // a look: wear one piece of it
            Flow {
                visible: row.kind === "look" && (row.modelData.pieces || []).length > 0
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: row.modelData.pieces || []
                    delegate: Btn {
                        required property string modelData
                        text: (root.pieceWords[modelData] || modelData)
                        enabled: !root.busy
                        onClicked: root.runJob("Wearing the " + (root.pieceWords[modelData] || modelData).toLowerCase()
                                               + " of " + row.modelData.id, ["apply-look", row.modelData.id, "--piece", modelData])
                    }
                }
            }
        }
    }

    // the form that installs one kind from a git URL, with Check beside Install
    component InstallBox: Box {
        id: ib
        property string kind: "plugin"
        title: "Install a " + root.kindWords[kind].one + " from git"
        hint: root.kindWords[kind].hint
        RowLayout {
            spacing: 8
            Field { id: urlField; placeholder: "https://github.com/someone/aequalyn-" + ib.kind + "-name   (or a folder)" }
            Field { id: atField; placeholder: "commit (optional)"; Layout.fillWidth: false; Layout.preferredWidth: 160 }
        }
        RowLayout {
            spacing: 8
            Btn {
                text: "Check"
                enabled: !root.busy && urlField.text.trim() !== ""
                onClicked: root.runJob("Checking " + urlField.text.trim(), ["check", ib.kind, urlField.text.trim()]
                                       .concat(atField.text.trim() !== "" ? ["--at", atField.text.trim()] : []))
            }
            Btn {
                text: "Install"
                primary: true
                enabled: !root.busy && urlField.text.trim() !== ""
                onClicked: root.runJob("Installing " + urlField.text.trim(), ["install", ib.kind, urlField.text.trim()]
                                       .concat(atField.text.trim() !== "" ? ["--at", atField.text.trim()] : []))
            }
        }
    }

    // ---- the window -------------------------------------------------------------------------
    PanelWindow {
        id: win
        visible: veil.shown
        focusable: true
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: veil.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace: veil.layerName("store")
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }

        MouseArea {
            anchors.fill: parent
            onClicked: root.open = false
            Backdrop { id: veil; open: root.open; theme: root.theme; tintAlpha: 0.35 }
        }

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: Math.min(parent.width - 80, 1180)
            height: Math.min(parent.height - 80, 780)
            radius: 18
            color: root.theme.bgBase
            border.width: 1
            border.color: root.theme.bgBorder
            opacity: veil.progress
            scale: 0.97 + 0.03 * veil.progress
            focus: true
            Keys.onEscapePressed: root.open = false
            MouseArea { anchors.fill: parent }   // clicks inside never close it

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // title bar
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
                    Layout.leftMargin: 20
                    Layout.rightMargin: 14
                    spacing: 12
                    Text { text: "\u{F0110}"; color: root.theme.accentPrimary; font.family: root.font; font.pixelSize: 20 }
                    Text { text: "Store"; color: root.theme.textPrimary; font.family: root.font; font.pixelSize: 17; font.weight: Font.DemiBold }
                    Text {
                        text: (root.sections.find(s => s.key === root.section) || {}).label || ""
                        color: root.theme.textMuted; font.family: root.font; font.pixelSize: 13
                    }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        implicitWidth: 30; implicitHeight: 30; radius: 8
                        color: closeMa.containsMouse ? root.theme.bgHover : "transparent"
                        Text { anchors.centerIn: parent; text: "✕"; color: root.theme.textSecondary; font.pixelSize: 14 }
                        MouseArea { id: closeMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.open = false }
                    }
                }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: root.theme.bgBorder }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    // the rail of sections
                    ColumnLayout {
                        Layout.fillWidth: false
                        Layout.preferredWidth: 170
                        Layout.maximumWidth: 170
                        Layout.fillHeight: true
                        Layout.margins: 10
                        spacing: 4
                        Repeater {
                            model: root.sections
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool on: root.section === modelData.key
                                Layout.fillWidth: true
                                implicitHeight: 36
                                radius: 9
                                color: on ? root.theme.bgSelected : railMa.containsMouse ? root.theme.bgHover : "transparent"
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    spacing: 10
                                    Text { text: modelData.glyph; color: on ? root.theme.accentPrimary : root.theme.textSecondary; font.family: root.font; font.pixelSize: 16 }
                                    Text {
                                        text: modelData.label + (root.kindWords[modelData.key] && root.itemsOf(modelData.key).length ? "  " + root.itemsOf(modelData.key).length : "")
                                        color: on ? root.theme.textPrimary : root.theme.textSecondary
                                        font.family: root.font; font.pixelSize: 13; font.weight: on ? Font.DemiBold : Font.Normal
                                        Layout.fillWidth: true
                                    }
                                }
                                MouseArea { id: railMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.section = modelData.key }
                            }
                        }
                        Item { Layout.fillHeight: true }
                    }
                    Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: root.theme.bgBorder }

                    // the page, and the report of the last job under it
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 0
                        Flickable {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            contentHeight: pageCol.implicitHeight + 40
                            boundsBehavior: Flickable.StopAtBounds
                            ColumnLayout {
                                id: pageCol
                                x: 20; y: 20
                                width: parent.width - 40
                                spacing: 14

                                // Home
                                Box {
                                    visible: root.section === "home"
                                    title: "Everything here is checked before it is kept"
                                    hint: "Plugins, themes, cursors, wallpaper packs and looks come from git. Each one goes through the same checks first: its files, its syntax (qmllint), what it may run and where it may write. Nothing that fails is installed, and the report says why. Looks dress one piece of the desktop or several: the bar, the docks, the cursor, the lock screen, the lock and sleep timings, the login screen."
                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: 8
                                        Repeater {
                                            model: root.sections.filter(s => s.key !== "home")
                                            delegate: Btn {
                                                required property var modelData
                                                text: modelData.label + (root.kindWords[modelData.key] ? "  " + root.itemsOf(modelData.key).length : "")
                                                onClicked: root.section = modelData.key
                                            }
                                        }
                                    }
                                }

                                // a kind's page: what is installed, then the form
                                Box {
                                    visible: !!root.kindWords[root.section]
                                    title: "Installed"
                                    hint: root.kindWords[root.section] && root.itemsOf(root.section).length === 0
                                          ? "No " + root.kindWords[root.section].one + " from the Store yet." : ""
                                    Repeater {
                                        model: root.kindWords[root.section] ? root.itemsOf(root.section) : []
                                        delegate: ItemRow {}
                                    }
                                }
                                InstallBox { visible: !!root.kindWords[root.section]; kind: root.kindWords[root.section] ? root.section : "plugin" }

                                // Apps: the four backends, then the popular apps, each from any backend that has it
                                Box {
                                    visible: root.section === "apps"
                                    title: "Backends"
                                    hint: "Where apps come from. Arch's own repositories (multilib included) are always here; the AUR, Flathub and Snap are one click away."
                                    Repeater {
                                        model: [
                                            { key: "pacman", label: "Arch repositories", tool: "pacman", needs: "" },
                                            { key: "yay", label: "AUR", tool: "yay", needs: "" },
                                            { key: "flatpak", label: "Flathub", tool: "flatpak", needs: "" },
                                            { key: "snap", label: "Snap Store", tool: "snapd, from the AUR", needs: "yay" }
                                        ]
                                        delegate: RowLayout {
                                            required property var modelData
                                            readonly property bool ready: modelData.key === "pacman" || root.backends[modelData.key] === true
                                            Layout.fillWidth: true
                                            spacing: 10
                                            Text { text: modelData.label; color: root.theme.textPrimary; font.family: root.font; font.pixelSize: 13; Layout.preferredWidth: 160 }
                                            Text { text: modelData.tool; color: root.theme.textMuted; font.family: root.font; font.pixelSize: 11; Layout.fillWidth: true }
                                            Pill { visible: parent.ready; text: "Ready"; tone: root.theme.accentGreen }
                                            Btn {
                                                visible: !parent.ready
                                                text: "Install " + modelData.label
                                                enabled: !terminal.running && (modelData.needs === "" || root.backends[modelData.needs] === true)
                                                onClicked: root.installBackend(modelData.key)
                                            }
                                        }
                                    }
                                    Text {
                                        visible: !root.backends.yay && !root.backends.snap
                                        text: "Snap comes from the AUR: install the AUR first."
                                        color: root.theme.textMuted; font.family: root.font; font.pixelSize: 11
                                    }
                                }
                                Box {
                                    visible: root.section === "apps"
                                    title: "Popular apps"
                                    hint: "Each from any backend that carries it. The install opens in a terminal, where sudo asks for your password."
                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: 10
                                        Repeater {
                                            model: root.section === "apps" ? root.apps : []
                                            delegate: Rectangle {
                                                id: appCard
                                                required property var modelData
                                                readonly property string via: root.installedVia(modelData)
                                                width: 236
                                                height: 150
                                                radius: 12
                                                color: root.theme.bgBase
                                                border.width: 1
                                                border.color: root.theme.bgBorder
                                                ColumnLayout {
                                                    anchors.fill: parent
                                                    anchors.margins: 12
                                                    spacing: 6
                                                    RowLayout {
                                                        spacing: 10
                                                        Image {
                                                            source: "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/" + appCard.modelData.icon + ".png"
                                                            sourceSize.width: 64; sourceSize.height: 64
                                                            Layout.preferredWidth: 34; Layout.preferredHeight: 34
                                                            fillMode: Image.PreserveAspectFit
                                                            asynchronous: true
                                                            smooth: true
                                                        }
                                                        ColumnLayout {
                                                            spacing: 1
                                                            Layout.fillWidth: true
                                                            Text { text: appCard.modelData.name; color: root.theme.textPrimary; font.family: root.font; font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
                                                            Pill { visible: appCard.via !== ""; text: "Installed · " + appCard.via; tone: root.theme.accentGreen }
                                                        }
                                                    }
                                                    Text { text: appCard.modelData.about; color: root.theme.textSecondary; font.family: root.font; font.pixelSize: 11; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                                                    Item { Layout.fillHeight: true }
                                                    Flow {
                                                        Layout.fillWidth: true
                                                        spacing: 6
                                                        Repeater {
                                                            model: [
                                                                { via: appCard.modelData.pacman ? "Arch" : "AUR", has: !!(appCard.modelData.pacman || appCard.modelData.aur),
                                                                  ready: !!appCard.modelData.pacman || root.backends.yay === true },
                                                                { via: "Flatpak", has: !!appCard.modelData.flatpak, ready: root.backends.flatpak === true },
                                                                { via: "Snap", has: !!appCard.modelData.snap, ready: root.backends.snap === true }
                                                            ].filter(o => o.has)
                                                            delegate: Btn {
                                                                required property var modelData
                                                                text: modelData.via
                                                                implicitHeight: 26
                                                                primary: modelData.ready && appCard.via === ""
                                                                enabled: modelData.ready && !terminal.running
                                                                onClicked: root.installApp(appCard.modelData, modelData.via)
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                // every app from every backend
                                Box {
                                    visible: root.section === "apps"
                                    title: "All apps"
                                    hint: root.foundQuery === ""
                                        ? "Flathub's most installed and Snap's featured apps. Search to look through Arch, the AUR, Flathub and Snap at once."
                                        : "Everything that matches \"" + root.foundQuery + "\" in Arch, the AUR, Flathub and Snap."
                                    RowLayout {
                                        spacing: 8
                                        Field {
                                            id: appSearch
                                            placeholder: "Search every app, like \"obsidian\""
                                            Keys.onReturnPressed: root.searchApps(appSearch.text.trim(), false)
                                        }
                                        Btn { text: root.searching ? "Searching…" : "Search"; primary: true; enabled: !root.searching; onClicked: root.searchApps(appSearch.text.trim(), false) }
                                    }
                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: 6
                                        Repeater {
                                            model: ["All", "Arch", "AUR", "Flatpak", "Snap"]
                                            delegate: Btn {
                                                required property string modelData
                                                readonly property int count: modelData === "All" ? root.found.length : root.found.filter(r => r.source === modelData).length
                                                text: modelData + "  " + count + (root.foundErrors[modelData] ? "  ⚠" : "")
                                                primary: root.foundSource === modelData
                                                implicitHeight: 26
                                                onClicked: root.foundSource = modelData
                                            }
                                        }
                                    }
                                    Text {
                                        visible: Object.keys(root.foundErrors).length > 0
                                        text: "Could not reach: " + Object.keys(root.foundErrors).join(", ") + ". Search again in a moment."
                                        color: root.theme.accentOrange; font.family: root.font; font.pixelSize: 11
                                    }
                                    Repeater {
                                        model: root.section === "apps" ? root.found.filter(r => root.foundSource === "All" || r.source === root.foundSource).slice(0, 400) : []
                                        delegate: Rectangle {
                                            id: frow
                                            required property var modelData
                                            readonly property bool have: root.foundInstalled(modelData)
                                            readonly property bool ready: modelData.source === "Arch" || (modelData.source === "AUR" && root.backends.yay)
                                                || (modelData.source === "Flatpak" && root.backends.flatpak) || (modelData.source === "Snap" && root.backends.snap)
                                            Layout.fillWidth: true
                                            implicitHeight: 54
                                            radius: 10
                                            color: root.theme.bgBase
                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 10
                                                anchors.rightMargin: 10
                                                spacing: 10
                                                Item {
                                                    Layout.preferredWidth: 32; Layout.preferredHeight: 32
                                                    Image {
                                                        id: ficon
                                                        anchors.fill: parent
                                                        source: frow.modelData.icon || ""
                                                        sourceSize.width: 64; sourceSize.height: 64
                                                        fillMode: Image.PreserveAspectFit
                                                        asynchronous: true
                                                        visible: status === Image.Ready
                                                    }
                                                    Text {
                                                        anchors.centerIn: parent
                                                        visible: ficon.status !== Image.Ready
                                                        text: "\u{F03D6}"
                                                        color: root.theme.textMuted; font.family: root.font; font.pixelSize: 20
                                                    }
                                                }
                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 1
                                                    RowLayout {
                                                        spacing: 8
                                                        Text { text: frow.modelData.name; color: root.theme.textPrimary; font.family: root.font; font.pixelSize: 12; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.maximumWidth: 320 }
                                                        Pill { text: frow.modelData.source === "Flatpak" ? "Flathub" : frow.modelData.source; tone: root.theme.accentPrimary }
                                                        Pill { visible: frow.have; text: "Installed"; tone: root.theme.accentGreen }
                                                    }
                                                    Text { text: frow.modelData.about; color: root.theme.textSecondary; font.family: root.font; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
                                                }
                                                Text {
                                                    visible: frow.modelData.popularity > 0
                                                    text: frow.modelData.source === "AUR" ? frow.modelData.popularity + " votes"
                                                        : Math.round(frow.modelData.popularity / 1000) + "k installs a month"
                                                    color: root.theme.textMuted; font.family: root.font; font.pixelSize: 10
                                                }
                                                Btn {
                                                    visible: !frow.have
                                                    text: frow.ready ? "Install" : "Needs " + (frow.modelData.source === "AUR" ? "the AUR" : frow.modelData.source === "Flatpak" ? "Flathub" : "Snap")
                                                    primary: frow.ready
                                                    enabled: frow.ready && !terminal.running
                                                    onClicked: root.installFound(frow.modelData)
                                                }
                                            }
                                        }
                                    }
                                    Btn {
                                        visible: root.foundPage > 0 && root.foundPage < root.flathubPages && (root.foundSource === "All" || root.foundSource === "Flatpak")
                                        text: root.searching ? "Loading…" : "More from Flathub (page " + (root.foundPage + 1) + " of " + root.flathubPages + ")"
                                        enabled: !root.searching
                                        onClicked: root.searchApps(root.foundQuery, true)
                                    }
                                }
                                Box {
                                    visible: root.section === "apps"
                                    title: "Anything else"
                                    hint: "Search every package in Arch's repositories and the AUR."
                                    Btn {
                                        text: "Search packages"
                                        onClicked: { root.open = false; root.runSide(["qs", "ipc", "call", "aequalyn", "page", "store"]); }
                                    }
                                }

                                // Market: the catalog, every item pinned to the commit that was checked
                                Box {
                                    visible: root.section === "market"
                                    title: "The Market"
                                    hint: root.market.length > 0
                                        ? "Published by others, reviewed, and installed at the exact commit that was checked."
                                        : root.marketLoaded ? "The catalog is empty for now. Publish yours: github.com/Aequalyn/aequalyn-market."
                                        : "The catalog could not be read yet (it is fetched from github.com/Aequalyn/aequalyn-market). Install from a git URL on each section's page meanwhile: the same checks run."
                                    Btn {
                                        text: "Refresh the catalog"
                                        enabled: !root.busy
                                        onClicked: root.runJob("Refreshing the catalog", ["refresh"])
                                    }
                                    Repeater {
                                        model: root.section === "market" ? root.market : []
                                        delegate: Rectangle {
                                            id: mrow
                                            required property var modelData
                                            Layout.fillWidth: true
                                            implicitHeight: mcol.implicitHeight + 20
                                            radius: 10
                                            color: root.theme.bgBase
                                            RowLayout {
                                                id: mcol
                                                anchors.fill: parent
                                                anchors.margins: 10
                                                spacing: 10
                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 2
                                                    RowLayout {
                                                        spacing: 8
                                                        Text { text: mrow.modelData.name || mrow.modelData.id; color: root.theme.textPrimary; font.family: root.font; font.pixelSize: 13; font.weight: Font.DemiBold }
                                                        Pill { text: mrow.modelData.kind; tone: root.theme.accentPrimary }
                                                        Pill {
                                                            visible: mrow.modelData.state !== "not installed"
                                                            text: mrow.modelData.state === "installed" ? "Installed" : "Update available"
                                                            tone: mrow.modelData.state === "installed" ? root.theme.accentGreen : root.theme.accentOrange
                                                        }
                                                    }
                                                    Text { text: mrow.modelData.about || ""; color: root.theme.textSecondary; font.family: root.font; font.pixelSize: 11; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                                                    Text {
                                                        text: (mrow.modelData.by ? "by " + mrow.modelData.by + "  ·  " : "") + String(mrow.modelData.commit || "").slice(0, 12)
                                                              + (mrow.modelData.license ? "  ·  " + mrow.modelData.license : "") + "  ·  " + (mrow.modelData.repo || "")
                                                        color: root.theme.textMuted; font.family: root.font; font.pixelSize: 10; elide: Text.ElideMiddle; Layout.fillWidth: true
                                                    }
                                                }
                                                Btn {
                                                    visible: mrow.modelData.state !== "installed"
                                                    text: mrow.modelData.state === "update available" ? "Update" : "Install"
                                                    primary: true
                                                    enabled: !root.busy
                                                    onClicked: root.runJob((mrow.modelData.state === "update available" ? "Updating " : "Installing ") + (mrow.modelData.name || mrow.modelData.id),
                                                                           ["install-market", mrow.modelData.id])
                                                }
                                            }
                                        }
                                    }
                                }

                                // Updates: everything installed, newest commit fetched and checked again
                                Box {
                                    visible: root.section === "updates"
                                    title: "Updates"
                                    hint: root.installed.length === 0 ? "Nothing from the Store yet."
                                        : "Update fetches the newest commit of each source and runs every check again; a source that fails keeps what you have."
                                    Btn {
                                        visible: root.installed.length > 0
                                        text: "Update all " + root.installed.length
                                        primary: true
                                        enabled: !root.busy
                                        onClicked: root.runJob("Updating everything", ["update-all"])
                                    }
                                    Repeater {
                                        model: root.section === "updates" ? root.installed : []
                                        delegate: ItemRow {}
                                    }
                                }
                            }
                        }

                        // the report
                        Rectangle {
                            visible: root.jobTitle !== ""
                            Layout.fillWidth: true
                            Layout.preferredHeight: 170
                            color: root.theme.bgSurface
                            Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: root.theme.bgBorder }
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 6
                                RowLayout {
                                    Text {
                                        text: root.jobTitle
                                        color: root.theme.textPrimary; font.family: root.font; font.pixelSize: 12; font.weight: Font.DemiBold
                                        elide: Text.ElideMiddle; Layout.fillWidth: true
                                    }
                                    Pill {
                                        text: root.busy ? "Running" : root.jobCode === 0 ? "Done" : "Failed"
                                        tone: root.busy ? root.theme.accentOrange : root.jobCode === 0 ? root.theme.accentGreen : root.theme.accentRed
                                    }
                                }
                                ListView {
                                    id: logView
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    clip: true
                                    model: logModel
                                    onCountChanged: positionViewAtEnd()
                                    delegate: Text {
                                        required property string line
                                        width: logView.width
                                        text: line
                                        textFormat: Text.PlainText
                                        wrapMode: Text.WrapAnywhere
                                        color: line.startsWith("FAIL") ? root.theme.accentRed : line.startsWith("OK") ? root.theme.accentGreen : root.theme.textSecondary
                                        font.family: root.font
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
}
