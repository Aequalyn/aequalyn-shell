// Sound's quick panel: the volume and the microphone, and where the sound goes; last,
// the Sound page.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import "root:/plugins/bar/quick"

QuickPopup {
    id: q
    required property var bar
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    PwObjectTracker { objects: [q.sink, q.source] }
    readonly property var nodes: Pipewire.nodes.values.filter(n => n.audio && !n.isStream)
    readonly property var outputs: nodes.filter(n => n.isSink)
    function name(n) { return n.description || n.nickname || n.name }

    glyph: "\u{F057E}"
    title: "Sound"
    sub: q.sink ? q.name(q.sink) : "No output"
    settingsLabel: "Sound settings"
    onSettingsClicked: { q.dismissed(); q.bar.openPage("sound") }

    QuickLevel {
        visible: !!(q.sink && q.sink.audio)
        glyph: q.sink && q.sink.audio && (q.sink.audio.muted || q.sink.audio.volume <= 0) ? "\u{F0581}" : "\u{F057E}"
        tip: "Volume (click the icon to mute)"
        muted: !!(q.sink && q.sink.audio && q.sink.audio.muted)
        value: q.sink && q.sink.audio ? Math.min(1, q.sink.audio.volume) : 0
        onMoved: v => { if (q.sink && q.sink.audio) q.sink.audio.volume = v }
        onIconClicked: if (q.sink && q.sink.audio) q.sink.audio.muted = !q.sink.audio.muted
    }
    QuickLevel {
        visible: !!(q.source && q.source.audio)
        glyph: q.source && q.source.audio && q.source.audio.muted ? "\u{F036D}" : "\u{F036C}"
        tip: "Microphone (click the icon to mute)"
        muted: !!(q.source && q.source.audio && q.source.audio.muted)
        value: q.source && q.source.audio ? Math.min(1, q.source.audio.volume) : 0
        onMoved: v => { if (q.source && q.source.audio) q.source.audio.volume = v }
        onIconClicked: if (q.source && q.source.audio) q.source.audio.muted = !q.source.audio.muted
    }

    QuickLabel { visible: q.outputs.length > 1; text: "Play through" }
    Repeater {
        model: q.outputs.length > 1 ? q.outputs : []
        delegate: QuickTile {
            required property var modelData
            glyph: String(modelData.name).indexOf("bluez") >= 0 ? "\u{F02CB}" : String(modelData.name).indexOf("hdmi") >= 0 ? "\u{F0379}" : "\u{F04C3}"
            title: q.name(modelData)
            on: !!q.sink && modelData.id === q.sink.id
            onToggled: Pipewire.preferredDefaultAudioSink = modelData
        }
    }
}
