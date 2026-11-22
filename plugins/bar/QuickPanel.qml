// The quick panel: what you change most, one click from the bar. It opens under the
// bar's gear (left click; a right click opens the whole control center). Made of the
// parts every quick panel shares (quick/), as the widgets' own quick panels are.
//
//   the time, and lock / power / control center
//   tiles: Wi-Fi, Bluetooth, Do not disturb, Keep awake (click: on / off; the arrow:
//          its page in the control center)
//   brightness and volume
//   what is playing
//   themes and wallpapers, and the control center
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import "root:/settings"
import "root:/plugins/wifi"
import "root:/plugins/bluetooth"
import "root:/plugins/idleInhibitor"
import "root:/plugins/notifications"
import "root:/plugins/bar/quick"

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
    PwObjectTracker { objects: [panel.sink] }
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
            glyph: "\u{F05A9}"; title: "Wi-Fi"; hasMore: true
            on: WifiService.wifiEnabled
            sub: !WifiService.available ? "Not here" : !WifiService.wifiEnabled ? "Off"
                : WifiService.connectedName !== "" ? WifiService.connectedName : "Not connected"
            enabled: WifiService.available
            onToggled: WifiService.toggleWifi()
            onMore: panel.page("wifi")
        }
        QuickTile {
            glyph: "\u{F00AF}"; title: "Bluetooth"; hasMore: true
            on: BluetoothService.powered
            sub: !BluetoothService.available ? "Not here" : !BluetoothService.powered ? "Off"
                : BluetoothService.connectedName !== "" ? BluetoothService.connectedName : "On"
            enabled: BluetoothService.available
            onToggled: BluetoothService.togglePower()
            onMore: panel.page("bluetooth")
        }
        QuickTile {
            glyph: "\u{F009B}"; title: "Do not disturb"
            on: panel.dnd
            sub: !panel.notesOn ? "Notifications are off" : panel.dnd ? "Notifications wait" : "Off"
            enabled: panel.notesOn
            onToggled: NotificationService.doNotDisturb = !NotificationService.doNotDisturb
        }
        QuickTile {
            glyph: "\u{F0176}"; title: "Keep awake"; hasMore: true
            on: CaffeineService.active
            sub: CaffeineService.active ? "Nothing locks or sleeps" : "Off"
            onToggled: CaffeineService.toggle()
            onMore: panel.page("sleep")
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

    // ---- what is playing ------------------------------------------------------
    Rectangle {
        visible: !!panel.player
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
