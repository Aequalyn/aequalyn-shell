// Sound: how loud, what it plays through, and the microphone.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import ".."

CcPage {
    id: page
    title: "Sound"
    sub: "How loud, and what it plays through."

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var nodes: Pipewire.nodes.values.filter(n => n.audio && !n.isStream)
    PwObjectTracker { objects: [page.sink, page.source] }

    function name(n) { return n.description || n.nickname || n.name; }
    function setVolume(node, v) { if (node && node.audio) node.audio.volume = v / 100; }

    CcSlider {
        title: "Volume"
        enabled: !!(page.sink && page.sink.audio)
        value: page.sink && page.sink.audio ? Math.round(page.sink.audio.volume * 100) : 0
        from: 0; to: 150; step: 5; unit: "%"
        sub: "Above 100% can distort."
        onMoved: v => page.setVolume(page.sink, v)
        onCommitted: v => page.setVolume(page.sink, v)
    }
    CcToggle {
        title: "Mute"
        enabled: !!(page.sink && page.sink.audio)
        checked: !!(page.sink && page.sink.audio && page.sink.audio.muted)
        onToggled: v => { if (page.sink && page.sink.audio) page.sink.audio.muted = v; }
    }
    CcSection {
        title: "Play sound through"
        CcNote { visible: speakers.options.length === 0; text: "Nothing to play through was found." }
        CcChoice {
            id: speakers
            options: page.nodes.filter(n => n.isSink).map(n => ({ key: n.id, label: page.name(n) }))
            current: page.sink ? page.sink.id : -1
            onChosen: key => { const n = page.nodes.find(x => x.id === key); if (n) Pipewire.preferredDefaultAudioSink = n; }
        }
    }
    CcSection {
        title: "Microphone"
        CcNote { visible: mics.options.length === 0; text: "No microphone was found." }
        CcChoice {
            id: mics
            options: page.nodes.filter(n => !n.isSink).map(n => ({ key: n.id, label: page.name(n) }))
            current: page.source ? page.source.id : -1
            onChosen: key => { const n = page.nodes.find(x => x.id === key); if (n) Pipewire.preferredDefaultAudioSource = n; }
        }
        CcSlider {
            visible: !!(page.source && page.source.audio)
            title: "Microphone level"
            value: page.source && page.source.audio ? Math.round(page.source.audio.volume * 100) : 0
            from: 0; to: 150; step: 5; unit: "%"
            onMoved: v => page.setVolume(page.source, v)
            onCommitted: v => page.setVolume(page.source, v)
        }
    }
    CcToggle {
        setting: "showVolume"
        title: "Volume on the bar"
        sub: "Scroll on it to change the volume, click it to mute."
    }
}
