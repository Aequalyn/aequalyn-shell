import QtQuick

// The spring physics are gone: Aequalyn's settings app has none, and the jelly
// transforms were the source of the scene-graph segfaults on file windows.
Scale {
    id: jelly
    property Item target: null
    property real anchorX: 0.5
    property real anchorY: 0.5
    property real spread: 0
    readonly property real naturalSpread: 0
    property real frequency: 4
    property real damping: 0.22
    property real timeScale: 0
    property real stretch: 0
    property real _v: 0
    readonly property bool wobbling: false
    readonly property real shiftX: 0
    readonly property real shiftY: 0
    readonly property real gain: 0
    function kick(amp) {}
    function kickAfter(amp, ms) {}
    xScale: 1
    yScale: 1
}
