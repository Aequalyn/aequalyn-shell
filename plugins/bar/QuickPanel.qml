// The quick panel: what you change most, one click from the bar. It opens under the
// bar's gear (left click; a right click opens the whole control center).
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

PopupWindow {
    id: panel
    required property var bar
    required property Item anchorItem
    readonly property var theme: bar.theme
    readonly property string sans: "sans-serif"
    readonly property string mono: bar.font

    implicitWidth: 360
    implicitHeight: content.implicitHeight + 28
    color: "transparent"

    anchor.item: anchorItem
    anchor.rect.x: 0
    anchor.rect.y: 0
    anchor.rect.width: anchorItem.width
    anchor.rect.height: anchorItem.height + 8
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.adjustment: PopupAdjustment.Slide

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

    Shortcut { sequence: "Escape"; onActivated: panel.close() }

    Rectangle {
        anchors.fill: parent
        radius: 18
        color: panel.theme.bgBase
        border.color: panel.theme.bgBorder
        border.width: 1

        ColumnLayout {
            id: content
            x: 14; y: 14
            width: parent.width - 28
            spacing: 12

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
                Round { glyph: "\u{F033E}"; tip: "Lock"; onClicked: { panel.close(); Quickshell.execDetached(["loginctl", "lock-session"]); } }
                Round { glyph: "\u{F0425}"; tip: "Power"; onClicked: { panel.close(); panel.bar.openPowerMenu(); } }
                Round { glyph: "\u{F0493}"; tip: "Control center"; onClicked: panel.page("home") }
            }

            // ---- tiles --------------------------------------------------------------
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 8
                rowSpacing: 8
                Tile {
                    glyph: "\u{F05A9}"; title: "Wi-Fi"; hasMore: true
                    on: WifiService.wifiEnabled
                    sub: !WifiService.available ? "Not here" : !WifiService.wifiEnabled ? "Off"
                        : WifiService.connectedName !== "" ? WifiService.connectedName : "Not connected"
                    enabled: WifiService.available
                    onToggled: WifiService.toggleWifi()
                    onMore: panel.page("wifi")
                }
                Tile {
                    glyph: "\u{F00AF}"; title: "Bluetooth"; hasMore: true
                    on: BluetoothService.powered
                    sub: !BluetoothService.available ? "Not here" : !BluetoothService.powered ? "Off"
                        : BluetoothService.connectedName !== "" ? BluetoothService.connectedName : "On"
                    enabled: BluetoothService.available
                    onToggled: BluetoothService.togglePower()
                    onMore: panel.page("bluetooth")
                }
                Tile {
                    glyph: "\u{F009B}"; title: "Do not disturb"
                    on: panel.dnd
                    sub: !panel.notesOn ? "Notifications are off" : panel.dnd ? "Notifications wait" : "Off"
                    enabled: panel.notesOn
                    onToggled: NotificationService.doNotDisturb = !NotificationService.doNotDisturb
                }
                Tile {
                    glyph: "\u{F0176}"; title: "Keep awake"; hasMore: true
                    on: CaffeineService.active
                    sub: CaffeineService.active ? "Nothing locks or sleeps" : "Off"
                    onToggled: CaffeineService.toggle()
                    onMore: panel.page("sleep")
                }
            }

            // ---- brightness and volume ---------------------------------------------------
            Level {
                visible: panel.bar.hasBacklight
                glyph: "\u{F00E0}"
                tip: "Brightness"
                value: panel.bar.brightnessValue
                onMoved: v => panel.bar.setBrightness(Math.max(1, Math.round(v * 100)))
            }
            Level {
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
                    Round { small: true; glyph: "\u{F04AE}"; tip: "Previous"; enabled: !!panel.player && panel.player.canGoPrevious; onClicked: panel.player.previous() }
                    Round {
                        small: true
                        glyph: panel.player && panel.player.playbackState === MprisPlaybackState.Playing ? "\u{F03E4}" : "\u{F040A}"
                        tip: "Play or pause"
                        enabled: !!panel.player && panel.player.canTogglePlaying
                        onClicked: panel.player.togglePlaying()
                    }
                    Round { small: true; glyph: "\u{F04AD}"; tip: "Next"; enabled: !!panel.player && panel.player.canGoNext; onClicked: panel.player.next() }
                }
            }

            // ---- look, and everything else -------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Wide { glyph: "\u{F03D8}"; label: "Theme"; onClicked: panel.ipc(["atelier", "open", "themes"]) }
                Wide { glyph: "\u{F0E09}"; label: "Wallpaper"; onClicked: panel.ipc(["atelier", "open", "wallpapers"]) }
            }
            Wide {
                Layout.fillWidth: true
                accent: true
                label: "Open the control center"
                onClicked: panel.page("home")
            }
        }
    }

    // ---- parts ------------------------------------------------------------------------
    // a round icon button
    component Round: Rectangle {
        id: rb
        property string glyph: ""
        property string tip: ""
        property bool small: false
        signal clicked()
        implicitWidth: small ? 30 : 36
        implicitHeight: implicitWidth
        radius: width / 2
        color: rbArea.containsMouse && enabled ? panel.theme.bgHover : (small ? "transparent" : panel.theme.bgSurface)
        opacity: enabled ? 1 : 0.35
        Accessible.role: Accessible.Button
        Accessible.name: tip
        Text {
            anchors.centerIn: parent
            text: rb.glyph
            color: panel.theme.textPrimary
            font.family: panel.mono
            font.pixelSize: rb.small ? 15 : 16
        }
        MouseArea {
            id: rbArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: rb.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: rb.clicked()
        }
    }

    // a setting that is on or off; its arrow (when it has a page) opens that page
    component Tile: Rectangle {
        id: tile
        property string glyph: ""
        property string title: ""
        property string sub: ""
        property bool on: false
        property bool hasMore: false        // it has a page in the control center
        signal toggled()
        signal more()
        Layout.fillWidth: true
        implicitHeight: 62
        radius: 14
        color: on ? panel.theme.accentPrimary : (tileArea.containsMouse && enabled ? panel.theme.bgHover : panel.theme.bgSurface)
        opacity: enabled ? 1 : 0.45
        Behavior on color { ColorAnimation { duration: 140 } }
        Accessible.role: Accessible.CheckBox
        Accessible.name: title
        Accessible.checked: on
        readonly property color ink: on ? panel.theme.bgBase : panel.theme.textPrimary

        MouseArea {
            id: tileArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: tile.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.toggled()
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 4
            spacing: 10
            Text {
                text: tile.glyph
                color: tile.on ? panel.theme.bgBase : panel.theme.accentPrimary
                font.family: panel.mono
                font.pixelSize: 18
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    text: tile.title
                    color: tile.ink
                    font.family: panel.sans
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    text: tile.sub
                    color: tile.on ? Qt.rgba(panel.theme.bgBase.r, panel.theme.bgBase.g, panel.theme.bgBase.b, 0.75) : panel.theme.textMuted
                    font.family: panel.sans
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
            Rectangle {
                visible: tile.hasMore
                Layout.preferredWidth: 26
                Layout.preferredHeight: 40
                radius: 9
                color: moreArea.containsMouse ? Qt.rgba(0, 0, 0, 0.12) : "transparent"
                Accessible.role: Accessible.Button
                Accessible.name: tile.title + " settings"
                Text {
                    anchors.centerIn: parent
                    text: "\u{F0142}"
                    color: tile.ink
                    font.family: panel.mono
                    font.pixelSize: 15
                }
                MouseArea {
                    id: moreArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: tile.more()
                }
            }
        }
    }

    // an amount you drag: brightness, volume
    component Level: RowLayout {
        id: lv
        property string glyph: ""
        property string tip: ""
        property real value: 0
        property bool muted: false
        signal moved(real value)
        signal iconClicked()
        property bool dragging: false
        property real dragValue: 0
        readonly property real shown: dragging ? dragValue : value
        Layout.fillWidth: true
        spacing: 10
        Round { glyph: lv.glyph; tip: lv.tip; small: true; onClicked: lv.iconClicked() }
        Item {
            id: track
            Layout.fillWidth: true
            implicitHeight: 28
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 8
                radius: 4
                color: panel.theme.bgSelected
                Rectangle {
                    width: Math.max(8, parent.width * lv.shown)
                    height: parent.height
                    radius: 4
                    color: lv.muted ? panel.theme.textMuted : panel.theme.accentPrimary
                }
            }
            Rectangle {
                width: 18; height: 18; radius: 9
                anchors.verticalCenter: parent.verticalCenter
                x: lv.shown * (track.width - width)
                color: panel.theme.textPrimary
                border.color: lv.muted ? panel.theme.textMuted : panel.theme.accentPrimary
                border.width: 4
            }
            MouseArea {
                anchors.fill: parent
                preventStealing: true
                cursorShape: Qt.PointingHandCursor
                function at(x) { return Math.max(0, Math.min(1, (x - 9) / Math.max(1, track.width - 18))); }
                onPressed: m => { lv.dragValue = at(m.x); lv.dragging = true; lv.moved(lv.dragValue); }
                onPositionChanged: m => { if (lv.dragging) { lv.dragValue = at(m.x); lv.moved(lv.dragValue); } }
                onReleased: lv.dragging = false
                onCanceled: lv.dragging = false
                onWheel: w => lv.moved(Math.max(0, Math.min(1, lv.value + (w.angleDelta.y > 0 ? 0.05 : -0.05))))
            }
        }
        Text {
            Layout.preferredWidth: 38
            horizontalAlignment: Text.AlignRight
            text: Math.round(lv.shown * 100) + "%"
            color: panel.theme.textSecondary
            font.family: panel.mono
            font.pixelSize: 11
        }
    }

    // a wide button
    component Wide: Rectangle {
        id: wb
        property string glyph: ""
        property string label: ""
        property bool accent: false
        signal clicked()
        Layout.fillWidth: true
        implicitHeight: 40
        radius: 12
        color: accent ? (wbArea.containsMouse ? Qt.lighter(panel.theme.accentPrimary, 1.1) : panel.theme.accentPrimary)
             : (wbArea.containsMouse ? panel.theme.bgHover : panel.theme.bgSurface)
        Accessible.role: Accessible.Button
        Accessible.name: label
        Row {
            anchors.centerIn: parent
            spacing: 8
            Text {
                visible: wb.glyph !== ""
                text: wb.glyph
                color: wb.accent ? panel.theme.bgBase : panel.theme.accentPrimary
                font.family: panel.mono
                font.pixelSize: 15
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: wb.label
                color: wb.accent ? panel.theme.bgBase : panel.theme.textPrimary
                font.family: panel.sans
                font.pixelSize: 12
                font.weight: Font.DemiBold
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        MouseArea {
            id: wbArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: wb.clicked()
        }
    }
}
