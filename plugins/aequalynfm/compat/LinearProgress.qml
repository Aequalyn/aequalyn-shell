import QtQuick

// Spartan progress bar: 4px track, accent fill, no wave. Keeps the LinearProgress
// API (value/thickness/color/trackColor).
Item {
    id: lp

    property real value: 0
    property real thickness: 4
    property bool wavy: false
    property bool animated: true
    property bool flowing: true
    property bool valueAnimated: true
    property real amplitude: 0
    property real wavelength: 0
    property color color: Theme.primary
    property color trackColor: Theme.bgSelected

    readonly property real _v: Math.max(0, Math.min(1, lp.value))

    implicitHeight: lp.thickness
    height: lp.thickness

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: lp.trackColor

        Rectangle {
            width: parent.width * lp._v
            height: parent.height
            radius: height / 2
            color: lp.color
            Behavior on width { NumberAnimation { duration: 160 } }
        }
    }
}
