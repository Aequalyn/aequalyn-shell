// Media's quick panel: the click you choose on the bar's media widget (a right click
// unless you change it). What is playing (the cover, the song, how far in), the
// buttons, the player's own volume, which player the bar follows, and the visualizer
// and its looks; last, Media's page in the control center.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import "root:/plugins/bar/quick"
import "root:/plugins/media"
import "root:/plugins/media/qml/js/Visuals.js" as Visuals
import "root:/plugins/media/qml/js/Schema.js" as Schema

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
    readonly property real length: safe(() => player && player.lengthSupported !== false && Number(player.length) > 0 ? Number(player.length) : 0, 0)
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
            Rectangle {
                Layout.preferredWidth: 72
                Layout.preferredHeight: 72
                radius: 12
                color: Quick.theme.bgSelected
                clip: true
                Text {
                    anchors.centerIn: parent
                    text: "\u{F075A}"
                    color: Quick.theme.accentPrimary
                    font.family: Quick.mono
                    font.pixelSize: 26
                }
                Image {
                    anchors.fill: parent
                    source: q.svc && q.svc.coverOrLogo !== "" ? q.svc.coverOrLogo
                          : q.player && q.player.trackArtUrl ? q.player.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
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

    // ---- the visualizer and its looks -------------------------------------------------
    QuickLabel { visible: !!q.svc; text: "On the bar" }
    RowLayout {
        visible: !!q.svc
        Layout.fillWidth: true
        spacing: 8
        QuickRound { glyph: "\u{F0141}"; tip: "The visualizer before"; onClicked: q.stepStyle(-1) }
        QuickWide {
            glyph: "\u{F0E70}"
            label: Visuals.labels[q.vizStyle] || "Visualizer"
            onClicked: q.stepStyle(1)
        }
        QuickRound { glyph: "\u{F0142}"; tip: "The next visualizer"; onClicked: q.stepStyle(1) }
    }
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
}
