// The quick panel: what you change most, one click from the bar. It opens under the
// bar's gear (left click; a right click opens the whole control center). Made of the
// parts every quick panel shares (quick/), as the widgets' own quick panels are.
//
//   the time, and lock / power / control center
//   tiles: Wi-Fi, Bluetooth, Do not disturb, Keep awake, Night light, Power mode,
//          Microphone, Airplane mode (click: on / off, or the next power mode; the
//          arrow: its page in the control center)
//   brightness, volume and the microphone
//   what is playing
//   quick actions: screenshot, recording, colour picker, clipboard, calculator, keys
//   themes and wallpapers, and the control center
// Which tiles and rows show is chosen in Control center -> Bar -> What it shows.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import "root:/settings"
import "root:/plugins/wifi"
import "root:/plugins/bluetooth"
import "root:/plugins/idleInhibitor"
import "root:/plugins/notifications"
import "root:/plugins/bar/quick"
import "root:/plugins/kit"

QuickPopup {
    id: panel
    required property var bar
    readonly property var theme: bar.theme
    readonly property string sans: Quick.sans
    readonly property string mono: bar.font

    onDismissed: bar.quickPanelVisible = false

    function close() { bar.quickPanelVisible = false; }
    // a page of the control center; the panel closes
    function page(name) { close(); bar.openPage(name); }
    function ipc(args) { close(); Quickshell.execDetached(["qs", "ipc", "call"].concat(args)); }

    // Do not disturb lives in the notifications plugin: only asked when it is on, so a
    // turned off plugin isn't started from here
    readonly property bool notesOn: (AequalynSettings.enabledPlugins || []).indexOf("notifications") >= 0
    readonly property bool dnd: notesOn && NotificationService.doNotDisturb

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    PwObjectTracker { objects: [panel.sink, panel.source] }

    // what the panel shows (Control center -> Bar -> What it shows)
    readonly property var cfg: AequalynSettings.quickPanelCfg
    function shows(tile) { return (panel.cfg.tiles || []).indexOf(tile) >= 0; }
    function pluginOn(id) { return (AequalynSettings.enabledPlugins || []).indexOf(id) >= 0; }

    // night light runs in the watchdog's sandbox: its mode is read and set over IPC
    readonly property string nightMode: SandboxSettings.value("nightLight", "mode", "")

    // the power mode (power-profiles-daemon), and the modes this machine has
    property string profile: ""
    property var profiles: []
    readonly property var profileNames: ({ "power-saver": "Power saver", "balanced": "Balanced", "performance": "Performance" })
    function nextProfile() {
        if (panel.profiles.length === 0) return;
        // saver -> balanced -> performance -> saver: the order the names are in, low to high
        const order = ["power-saver", "balanced", "performance"].filter(p => panel.profiles.indexOf(p) >= 0);
        const next = order[(order.indexOf(panel.profile) + 1) % order.length];
        panel.profile = next;
        Quickshell.execDetached(["powerprofilesctl", "set", next]);
    }
    Process {
        id: profileProc
        command: ["sh", "-c", "powerprofilesctl get 2>/dev/null && powerprofilesctl list 2>/dev/null | sed -n 's/^[ *]*\\([a-z-]*\\):$/\\1/p'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n").map(s => s.trim()).filter(s => s !== "");
                panel.profile = l[0] || "";
                panel.profiles = l.slice(1);
            }
        }
    }

    // airplane mode: every radio (Wi-Fi, Bluetooth, ...) blocked, by rfkill
    property bool airplane: false
    property bool hasRadios: false
    Process {
        id: radioProc
        command: ["rfkill", "-J"]
        stdout: StdioCollector {
            onStreamFinished: {
                let d = [];
                try { d = (JSON.parse(text)["rfkilldevices"] || []); } catch (e) { d = []; }
                panel.hasRadios = d.length > 0;
                panel.airplane = d.length > 0 && d.every(x => x.soft === "blocked" || x.hard === "blocked");
            }
        }
    }
    Process {
        id: radioSet
        onExited: radioProc.running = true
    }
    function toggleAirplane() {
        panel.airplane = !panel.airplane;
        radioSet.command = ["rfkill", panel.airplane ? "block" : "unblock", "all"];
        radioSet.running = true;
    }

    onVisibleChanged: if (visible) {
        profileProc.running = true;
        radioProc.running = true;
        if (panel.pluginOn("nightLight")) SandboxSettings.refresh("nightLight");
    }
    readonly property var player: bar.activePlayer

    property date now: new Date()
    Timer { interval: 1000; repeat: true; running: panel.visible; triggeredOnStart: true; onTriggered: panel.now = new Date() }

    // ---- the time, and the three buttons ------------------------------------
    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text {
                text: Qt.formatDateTime(panel.now, AequalynSettings.use24h ? "HH:mm" : "h:mm AP")
                color: panel.theme.textPrimary
                font.family: panel.mono
                font.pixelSize: 24
                font.weight: Font.Medium
            }
            Text {
                text: Qt.formatDateTime(panel.now, "dddd d MMMM")
                color: panel.theme.textMuted
                font.family: panel.sans
                font.pixelSize: 11
            }
        }
        QuickRound { glyph: "\u{F033E}"; tip: "Lock"; onClicked: { panel.close(); Quickshell.execDetached(["aequalyn-lock", "lock"]); } }
        QuickRound { glyph: "\u{F0425}"; tip: "Power"; onClicked: { panel.close(); panel.bar.openPowerMenu(); } }
        QuickRound { glyph: "\u{F0493}"; tip: "Control center"; onClicked: panel.page("home") }
    }

    // ---- tiles --------------------------------------------------------------
    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: 8
        rowSpacing: 8
        QuickTile {
            visible: panel.shows("wifi")
            glyph: "\u{F05A9}"; title: "Wi-Fi"; hasMore: true
            on: WifiService.wifiEnabled
            sub: !WifiService.available ? "Not here" : !WifiService.wifiEnabled ? "Off"
                : WifiService.connectedName !== "" ? WifiService.connectedName : "Not connected"
            enabled: WifiService.available
            onToggled: WifiService.toggleWifi()
            onMore: panel.page("wifi")
        }
        QuickTile {
            visible: panel.shows("bluetooth")
            glyph: "\u{F00AF}"; title: "Bluetooth"; hasMore: true
            on: BluetoothService.powered
            sub: !BluetoothService.available ? "Not here" : !BluetoothService.powered ? "Off"
                : BluetoothService.connectedName !== "" ? BluetoothService.connectedName : "On"
            enabled: BluetoothService.available
            onToggled: BluetoothService.togglePower()
            onMore: panel.page("bluetooth")
        }
        QuickTile {
            visible: panel.shows("notifications")
            glyph: "\u{F009B}"; title: "Notifications"
            hasMore: true                       // › opens the saved-message log
            on: panel.dnd
            sub: !panel.notesOn ? "Notifications are off"
               : panel.dnd ? "Notifications wait"
               : NotificationService.history.length > 0
                   ? NotificationService.history.length + " saved — tap › to re-read"
                   : "Off"
            enabled: panel.notesOn
            onToggled: NotificationService.doNotDisturb = !NotificationService.doNotDisturb
            onMore: {
                const name = panel.anchorItem.screen ? panel.anchorItem.screen.name : ""
                panel.close()
                NotificationService.openHistory(name)
            }
        }
        QuickTile {
            visible: panel.shows("caffeine")
            glyph: "\u{F0176}"; title: "Keep awake"; hasMore: true
            on: CaffeineService.active
            sub: CaffeineService.active ? "Nothing locks or sleeps" : "Off"
            onToggled: CaffeineService.toggle()
            onMore: panel.page("sleep")
        }
        QuickTile {
            visible: panel.shows("nightLight")
            glyph: "\u{F0594}"; title: "Night light"; hasMore: true
            enabled: panel.pluginOn("nightLight")
            on: panel.nightMode === "on"
            sub: !panel.pluginOn("nightLight") ? "The plugin is off"
               : panel.nightMode === "on" ? "Warm colours"
               : panel.nightMode === "schedule" ? "On a schedule" : "Off"
            onToggled: SandboxSettings.setValue("nightLight", "mode", panel.nightMode === "on" ? "off" : "on")
            onMore: { panel.close(); KitHost.openSettings("nightLight"); }
        }
        QuickTile {
            visible: panel.shows("power")
            glyph: panel.profile === "power-saver" ? "\u{F032A}" : panel.profile === "performance" ? "\u{F04C5}" : "\u{F0A72}"
            title: "Power mode"; hasMore: true
            enabled: panel.profiles.length > 1
            on: panel.profile !== "" && panel.profile !== "balanced"
            sub: panel.profiles.length === 0 ? "Not here" : (panel.profileNames[panel.profile] || panel.profile)
            onToggled: panel.nextProfile()
            onMore: panel.page("sleep")
        }
        QuickTile {
            visible: panel.shows("mic")
            readonly property bool live: !!(panel.source && panel.source.audio)
            glyph: live && !panel.source.audio.muted ? "\u{F036C}" : "\u{F036D}"
            title: "Microphone"; hasMore: true
            enabled: live
            on: live && !panel.source.audio.muted
            sub: !live ? "Not here" : panel.source.audio.muted ? "Muted" : (panel.source.description || "On")
            onToggled: panel.source.audio.muted = !panel.source.audio.muted
            onMore: panel.page("sound")
        }
        QuickTile {
            visible: panel.shows("airplane")
            glyph: "\u{F001D}"; title: "Airplane mode"
            enabled: panel.hasRadios
            on: panel.airplane
            sub: !panel.hasRadios ? "No radios" : panel.airplane ? "Every radio is off" : "Off"
            onToggled: panel.toggleAirplane()
        }
    }

    // ---- brightness and volume ---------------------------------------------------
    QuickLevel {
        visible: panel.bar.hasBacklight
        glyph: "\u{F00E0}"
        tip: "Brightness"
        value: panel.bar.brightnessValue
        onMoved: v => panel.bar.setBrightness(Math.max(1, Math.round(v * 100)))
    }
    QuickLevel {
        visible: !!(panel.sink && panel.sink.audio)
        glyph: panel.sink && panel.sink.audio && (panel.sink.audio.muted || panel.sink.audio.volume <= 0) ? "\u{F0581}" : "\u{F057E}"
        tip: "Volume (click the icon to mute)"
        muted: !!(panel.sink && panel.sink.audio && panel.sink.audio.muted)
        value: panel.sink && panel.sink.audio ? Math.min(1, panel.sink.audio.volume) : 0
        onMoved: v => { if (panel.sink && panel.sink.audio) panel.sink.audio.volume = v; }
        onIconClicked: if (panel.sink && panel.sink.audio) panel.sink.audio.muted = !panel.sink.audio.muted
    }
    QuickLevel {
        visible: panel.cfg.mic !== false && !!(panel.source && panel.source.audio)
        glyph: panel.source && panel.source.audio && (panel.source.audio.muted || panel.source.audio.volume <= 0) ? "\u{F036D}" : "\u{F036C}"
        tip: "Microphone (click the icon to mute)"
        muted: !!(panel.source && panel.source.audio && panel.source.audio.muted)
        value: panel.source && panel.source.audio ? Math.min(1, panel.source.audio.volume) : 0
        onMoved: v => { if (panel.source && panel.source.audio) panel.source.audio.volume = v; }
        onIconClicked: if (panel.source && panel.source.audio) panel.source.audio.muted = !panel.source.audio.muted
    }

    // ---- what is playing ------------------------------------------------------
    Rectangle {
        visible: panel.cfg.media !== false && !!panel.player
        Layout.fillWidth: true
        implicitHeight: 60
        radius: 14
        color: panel.theme.bgSurface
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 8
            spacing: 10
            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: 10
                color: panel.theme.bgSelected
                clip: true
                Text {
                    anchors.centerIn: parent
                    text: "\u{F075A}"
                    color: panel.theme.accentPrimary
                    font.family: panel.mono
                    font.pixelSize: 18
                }
                Image {
                    anchors.fill: parent
                    source: panel.player && panel.player.trackArtUrl ? panel.player.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    text: panel.player ? (panel.player.trackTitle || "Playing") : ""
                    color: panel.theme.textPrimary
                    font.family: panel.sans
                    font.pixelSize: 12
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    text: panel.player ? (panel.player.trackArtist || panel.player.identity || "") : ""
                    color: panel.theme.textMuted
                    font.family: panel.sans
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
            QuickRound { small: true; glyph: "\u{F04AE}"; tip: "Previous"; enabled: !!panel.player && panel.player.canGoPrevious; onClicked: panel.player.previous() }
            QuickRound {
                small: true
                glyph: panel.player && panel.player.playbackState === MprisPlaybackState.Playing ? "\u{F03E4}" : "\u{F040A}"
                tip: "Play or pause"
                enabled: !!panel.player && panel.player.canTogglePlaying
                onClicked: panel.player.togglePlaying()
            }
            QuickRound { small: true; glyph: "\u{F04AD}"; tip: "Next"; enabled: !!panel.player && panel.player.canGoNext; onClicked: panel.player.next() }
        }
    }

    // ---- quick actions: each one only while its plugin is on --------------------
    RowLayout {
        visible: panel.cfg.actions !== false
        Layout.fillWidth: true
        spacing: 6
        Item { Layout.fillWidth: true }
        QuickRound { small: true; glyph: "\u{F0104}"; tip: "Screenshot of an area"; onClicked: { panel.close(); panel.bar.takeScreenshot(); } }
        QuickRound {
            small: true; glyph: "\u{F044A}"; active: panel.bar.recordingActive
            tip: panel.bar.recordingActive ? "Stop recording" : "Record the screen"
            onClicked: { panel.close(); panel.bar.toggleRecording(); }
        }
        QuickRound { visible: panel.pluginOn("colorPicker"); small: true; glyph: "\u{F0485}"; tip: "Pick a colour"; onClicked: panel.ipc(["colorPicker", "pick"]) }
        QuickRound { visible: panel.pluginOn("clipscape"); small: true; glyph: "\u{F014C}"; tip: "Clipboard history"; onClicked: panel.ipc(["clipscape", "toggle"]) }
        QuickRound { visible: panel.pluginOn("calculator"); small: true; glyph: "\u{F00EC}"; tip: "Calculator"; onClicked: panel.ipc(["calculator", "toggle"]) }
        QuickRound { visible: panel.pluginOn("keyHints"); small: true; glyph: "\u{F030C}"; tip: "Keyboard shortcuts (Super + /)"; onClicked: panel.ipc(["keyHints", "toggle"]) }
        Item { Layout.fillWidth: true }
    }

    // ---- look, and everything else -------------------------------------------
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        QuickWide { glyph: "\u{F03D8}"; label: "Theme"; onClicked: panel.ipc(["atelier", "open", "themes"]) }
        QuickWide { glyph: "\u{F0E09}"; label: "Wallpaper"; onClicked: panel.ipc(["atelier", "open", "wallpapers"]) }
    }
    QuickWide {
        Layout.fillWidth: true
        accent: true
        label: "Open the control center"
        onClicked: panel.page("home")
    }
}
