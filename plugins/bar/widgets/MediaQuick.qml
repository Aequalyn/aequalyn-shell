// Media's quick panel: the click you choose on the bar's media widget (a right click
// unless you change it). What is playing (the cover, the song, how far in), the
// buttons, the player's own volume, which player the bar follows, and the visualizer
// and how it looks on the bar: the visualizer, its colours, the cover's place and shape
// and its turning, and the ready-made looks. The cover here is drawn as on the bar, live:
// it takes the shape and turns as chosen. Last, Media's page in the control center.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import "root:/plugins/bar/quick"
import "root:/plugins/media"
import "root:/plugins/media/qml/js/Visuals.js" as Visuals
import "root:/plugins/media/qml/js/Schema.js" as Schema
import "root:/plugins/media/qml/js/Colors.js" as Colors
import "root:/plugins/media/qml/bar" as MediaBar

QuickPopup {
    id: q
    required property var bar
    readonly property var svc: MediaHost.svc
    readonly property var player: svc ? svc.player : bar.activePlayer
    readonly property bool playing: !!player && player.playbackState === MprisPlaybackState.Playing

    glyph: "\u{F075A}"
    title: "Media"
    sub: !player ? "Nothing playing" : (svc ? svc.nameOf(player) : (player.identity || "")) + (playing ? " · playing" : " · paused")
    settingsLabel: "Media settings"
    onSettingsClicked: { q.dismissed(); q.bar.openPage("media") }

    function safe(f, fallback) { try { const v = f(); return v === undefined ? fallback : v } catch (e) { return fallback } }
    function clock(s) {
        s = Math.max(0, Math.floor(s));
        const m = Math.floor(s / 60), r = s % 60;
        return (m >= 60 ? Math.floor(m / 60) + ":" + String(m % 60).padStart(2, "0") : m) + ":" + String(r).padStart(2, "0");
    }

    // ---- how far in: the player says only when asked ------------------------------
    property real position: 0
    // a live stream reports an endless length: no length then, and no seek bar
    readonly property real length: safe(() => player && player.lengthSupported !== false && Number(player.length) > 0
        && Number(player.length) < 7 * 86400 ? Number(player.length) : 0, 0)
    function readPosition() {
        if (!player) { q.position = 0; return }
        try {
            if (typeof player.positionChanged === "function") player.positionChanged()
            q.position = Number(player.position) || 0
        } catch (e) { q.position = 0 }
    }
    Timer { interval: 1000; repeat: true; triggeredOnStart: true; running: q.visible && !!q.player; onTriggered: q.readPosition() }

    // ---- the visualizer, when Media is on ------------------------------------------
    readonly property var cfg: svc ? Schema.resolve(null, svc.store.values) : null
    readonly property string vizStyle: svc ? (svc.styleOverride !== "" ? svc.styleOverride : cfg.vizStyle) : ""
    function stepStyle(step) {
        const list = Visuals.keys;
        let i = list.indexOf(q.vizStyle);
        if (i < 0) i = 0;
        svc.setSetting("vizStyle", list[(i + (step < 0 ? list.length - 1 : 1)) % list.length]);
    }
    readonly property string lookNow: cfg ? Schema.lookNow(cfg) || "" : ""

    // ---- what is playing ------------------------------------------------------------
    QuickCard {
        visible: !q.player
        Text {
            Layout.fillWidth: true
            text: "Nothing is playing. Start a song or a video and it shows here."
            color: Quick.theme.textMuted
            font.family: Quick.sans
            font.pixelSize: 11
            wrapMode: Text.WordWrap
        }
    }
    QuickCard {
        visible: !!q.player
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            // the cover as the bar draws it: its shape, and turning while it plays
            Item {
                Layout.preferredWidth: 72
                Layout.preferredHeight: 72
                MediaBar.Cover {
                    anchors.fill: parent
                    source: q.svc && q.svc.coverOrLogo !== "" ? q.svc.coverOrLogo
                          : q.player && q.player.trackArtUrl ? q.player.trackArtUrl : ""
                    ink: Quick.theme.textPrimary
                    shape: q.cfg ? q.cfg.coverShape : "square"
                    spin: q.cfg ? q.cfg.coverSpin : "off"
                    spinTime: q.cfg ? q.cfg.spinTime : 8
                    playing: q.playing
                    corner: 12
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    Layout.fillWidth: true
                    text: q.player ? (q.player.trackTitle || "Playing") : ""
                    color: Quick.theme.textPrimary
                    font.family: Quick.sans
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: q.player ? (q.player.trackArtist || "") : ""
                    color: Quick.theme.textSecondary
                    font.family: Quick.sans
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: q.player ? (q.player.trackAlbum || "") : ""
                    color: Quick.theme.textMuted
                    font.family: Quick.sans
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }
        }
        QuickLevel {
            visible: q.length > 0
            tip: "How far into it"
            value: q.length > 0 ? Math.min(1, q.position / q.length) : 0
            textWidth: 82
            format: v => q.clock(v * q.length) + " / " + q.clock(q.length)
            enabled: q.safe(() => q.player.canSeek, false)
            onMoved: v => { try { q.player.position = v * q.length; q.position = v * q.length } catch (e) { } }
        }
    }

    // ---- the buttons ------------------------------------------------------------------
    RowLayout {
        visible: !!q.player
        Layout.alignment: Qt.AlignHCenter
        spacing: 10
        QuickRound {
            visible: q.safe(() => q.player.shuffleSupported, false)
            small: true; glyph: "\u{F049D}"; tip: "Shuffle"
            active: q.safe(() => q.player.shuffle, false)
            onClicked: { try { q.player.shuffle = !q.player.shuffle } catch (e) { } }
        }
        QuickRound { glyph: "\u{F04AE}"; tip: "Previous"; enabled: q.safe(() => q.player.canGoPrevious, false); onClicked: q.player.previous() }
        QuickRound {
            accent: true
            implicitWidth: 44
            glyph: q.playing ? "\u{F03E4}" : "\u{F040A}"
            tip: "Play or pause"
            enabled: q.safe(() => q.player.canTogglePlaying, false)
            onClicked: q.player.togglePlaying()
        }
        QuickRound { glyph: "\u{F04AD}"; tip: "Next"; enabled: q.safe(() => q.player.canGoNext, false); onClicked: q.player.next() }
        QuickRound {
            visible: q.safe(() => q.player.loopSupported, false)
            small: true
            readonly property int loop: q.safe(() => q.player.loopState, MprisLoopState.None)
            glyph: loop === MprisLoopState.Track ? "\u{F0458}" : "\u{F0456}"
            tip: loop === MprisLoopState.Track ? "Repeat this one" : loop === MprisLoopState.Playlist ? "Repeat all" : "Repeat"
            active: loop !== MprisLoopState.None
            onClicked: {
                try {
                    q.player.loopState = loop === MprisLoopState.None ? MprisLoopState.Playlist
                                       : loop === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None
                } catch (e) { }
            }
        }
    }

    // ---- the player's own volume ------------------------------------------------------
    QuickLevel {
        visible: q.safe(() => q.player.volumeSupported && q.player.canControl, false)
        glyph: "\u{F057E}"
        tip: "This player's volume"
        value: q.safe(() => Math.min(1, Number(q.player.volume) || 0), 0)
        onMoved: v => { try { q.player.volume = v } catch (e) { } }
    }

    // ---- which player the bar follows -------------------------------------------------
    QuickLabel { visible: !!q.svc && q.svc.playerList.length > 1; text: "Players" }
    Repeater {
        model: q.svc && q.svc.playerList.length > 1 ? q.svc.playerList : []
        delegate: QuickTile {
            required property var modelData
            glyph: modelData.playing ? "\u{F040A}" : "\u{F03E4}"
            title: modelData.name
            sub: modelData.track || (modelData.playing ? "Playing" : "Paused")
            on: modelData.id === q.svc.activeId
            onToggled: q.svc.switchTo(modelData.id)
        }
    }

    // ---- how it looks on the bar: each change shows on the bar at once ---------------
    function set(key, value) { if (q.svc) q.svc.setSetting(key, value) }
    // sample music for the previews, moving while the panel is open: bands (0..1) for
    // the bar-like styles, a wave (-1..1) for the scope-like ones
    property real phase: 0
    Timer { interval: 80; repeat: true; running: q.visible && !!q.svc; onTriggered: q.phase += 0.18 }
    readonly property var demoBands: {
        const out = [];
        for (let i = 0; i < 10; i++)
            out.push(0.18 + 0.72 * Math.abs(Math.sin(q.phase * (0.7 + i * 0.13) + i * 0.9)) * (1 - i * 0.05));
        return out;
    }
    readonly property var demoWave: {
        const out = [];
        for (let i = 0; i < 48; i++)
            out.push(0.8 * Math.sin(i * 0.4 + q.phase * 1.6) * Math.cos(i * 0.09 + q.phase * 0.5));
        return out;
    }

    QuickLabel { visible: !!q.svc; text: "Visualizer · " + (Visuals.labels[q.vizStyle] || q.vizStyle) }
    PreviewRow {
        visible: !!q.svc
        options: Visuals.keys
        current: q.vizStyle
        styleOf: k => k
        colorOf: k => q.cfg ? q.cfg.colorMode : "theme"
        labelOf: k => Visuals.labels[k] || k
        onChosen: key => { q.svc.styleOverride = ""; q.set("vizStyle", key) }
    }
    QuickLabel { visible: !!q.svc; text: "Colours · " + (q.cfg ? (Colors.labels[q.cfg.colorMode] || q.cfg.colorMode) : "") }
    PreviewRow {
        visible: !!q.svc
        options: Colors.keys
        current: q.cfg ? q.cfg.colorMode : ""
        styleOf: k => Visuals.isSquare(q.vizStyle) ? "bars" : q.vizStyle
        colorOf: k => k
        labelOf: k => Colors.labels[k] || k
        onChosen: key => q.set("colorMode", key)
    }
    QuickLabel { visible: !!q.svc; text: "Cover on the bar" }
    QuickChips {
        visible: !!q.svc
        options: [{ key: "hidden", label: "Hidden" }, { key: "left", label: "Left" },
                  { key: "center", label: "Before the title" }, { key: "right", label: "Right" }]
        current: q.cfg ? q.cfg.coverSide : ""
        onChosen: key => q.set("coverSide", key)
    }
    RowLayout {
        visible: !!q.svc
        Layout.fillWidth: true
        spacing: 12
        QuickChips {
            Layout.fillWidth: false
            Layout.preferredWidth: contentWidth
            options: [{ key: "square", label: "Square" }, { key: "circle", label: "Round" }]
            current: q.cfg ? q.cfg.coverShape : ""
            onChosen: key => q.set("coverShape", key)
        }
        QuickChips {
            enabled: !!q.cfg && q.cfg.coverShape === "circle"
            opacity: enabled ? 1 : 0.4
            options: [{ key: "off", label: "Still" }, { key: "left", label: "\u{F0453} Left" }, { key: "right", label: "Right \u{F0450}" }]
            current: q.cfg ? q.cfg.coverSpin : ""
            onChosen: key => q.set("coverSpin", key)
        }
    }
    QuickLevel {
        visible: !!q.cfg && q.cfg.coverShape === "circle" && q.cfg.coverSpin !== "off"
        glyph: "\u{F0450}"
        tip: "How fast it turns"
        textWidth: 70
        // left is slow, right is fast: 30 to 2 seconds a turn
        value: q.cfg ? (30 - q.cfg.spinTime) / 28 : 0
        format: v => Math.round(30 - v * 28) + " s/turn"
        onMoved: v => q.set("spinTime", Math.round(30 - v * 28))
    }
    QuickLabel { visible: !!q.svc; text: "Ready-made looks" }
    RowLayout {
        visible: !!q.svc
        Layout.fillWidth: true
        spacing: 8
        QuickWide {
            glyph: "\u{F0E09}"
            label: q.lookNow !== "" && Schema.lookByKey[q.lookNow] ? "Look: " + Schema.lookByKey[q.lookNow].label : "Wear a look"
            onClicked: q.svc.nextLook()
        }
        QuickWide {
            Layout.fillWidth: false
            visible: !!q.svc && q.svc.canUndo
            glyph: "\u{F054C}"
            label: "Undo"
            onClicked: q.svc.undoLook()
        }
    }

    // ---- a row of choices, each drawn as it looks (the visualizer itself, on sample
    // music), scrolling sideways; the chosen one is lifted with an accent edge ----------
    component PreviewRow: Flickable {
        id: pr
        property var options: []
        property string current: ""
        property var styleOf: k => "bars"
        property var colorOf: k => "theme"
        property var labelOf: k => k
        signal chosen(string key)
        Layout.fillWidth: true
        implicitHeight: 62
        contentWidth: tiles.implicitWidth
        contentHeight: 62
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalFlick
        function show(item) {
            if (!item) return
            if (item.x < contentX) contentX = item.x
            else if (item.x + item.width > contentX + width) contentX = Math.min(contentWidth - width, item.x + item.width - width)
        }
        WheelHandler {
            onWheel: e => {
                const d = Math.abs(e.angleDelta.x) > Math.abs(e.angleDelta.y) ? e.angleDelta.x : e.angleDelta.y
                pr.contentX = Math.max(0, Math.min(pr.contentWidth - pr.width, pr.contentX - d / 2))
            }
        }
        Row {
            id: tiles
            spacing: 6
            Repeater {
                model: pr.options
                delegate: Rectangle {
                    id: tile
                    required property string modelData
                    readonly property bool on: modelData === pr.current
                    readonly property string vs: pr.styleOf(modelData)
                    width: 84
                    height: 62
                    radius: 8
                    color: on ? Quick.theme.bgSelected : tileArea.containsMouse ? Quick.theme.bgHover : Quick.theme.bgSurface
                    border.width: 1
                    border.color: on ? Quick.theme.accentPrimary : Quick.theme.bgBorder
                    onOnChanged: if (on) Qt.callLater(pr.show, tile)
                    Component.onCompleted: if (on) Qt.callLater(pr.show, tile)
                    MediaBar.Visualizer {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 9
                        width: Visuals.isSquare(tile.vs) ? 26 : parent.width - 18
                        height: 26
                        levels: Visuals.isScope(tile.vs) ? q.demoWave : q.demoBands
                        vizStyle: tile.vs
                        colorMode: pr.colorOf(tile.modelData)
                        customColor: q.cfg ? q.cfg.customColor : "#7aa2f7"
                        customColor2: q.cfg ? q.cfg.customColor2 : "#f7768e"
                        accent: Quick.theme.accentPrimary
                        themeColors: q.svc ? q.svc.themePalette : []
                        borderColors: q.svc ? q.svc.borderColors : []
                        coverColors: q.svc ? q.svc.coverColors : []
                        foreground: Quick.theme.textPrimary
                        count: 10
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 6
                        width: parent.width - 8
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: pr.labelOf(tile.modelData)
                        color: tile.on ? Quick.theme.accentPrimary : Quick.theme.textSecondary
                        font.family: Quick.mono
                        font.pixelSize: 9
                        font.bold: tile.on
                    }
                    MouseArea {
                        id: tileArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pr.chosen(tile.modelData)
                    }
                }
            }
        }
    }
}
