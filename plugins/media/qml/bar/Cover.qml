import QtQuick
import QtQuick.Effects

// The song's cover, square or round. A round one can turn like a record while the
// music plays, to the left or to the right, and stops where it is when it pauses.
// The cover may be the player's logo when the song has none. Shows a music note while
// there is neither; while a new one loads it keeps a quiet tinted tile instead of
// flashing the note.
// Only a cover that is on screen holds its picture: a hidden one lets it go, and a
// new song lets the old one go, so each cover keeps one small picture at most.
Item {
    id: root

    property string source: ""
    property color ink: "white"
    property string shape: "square"      // square | circle
    property string spin: "off"          // off | left | right (round covers only)
    property int spinTime: 8             // seconds per turn
    property bool playing: false
    property real corner: 3              // corner radius of a square cover

    readonly property bool round: shape === "circle"
    // only a real cover turns; the note that stands in for one stays upright
    readonly property bool spinning: round && spin !== "off" && source !== ""
    readonly property string shown: visible ? source : ""

    // the turning part: the picture and its tile, never the item's own box
    Item {
        id: disc
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            radius: root.round ? width / 2 : root.corner
            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.10)
        }

        // a square cover: a plain image
        Image {
            id: img
            anchors.fill: parent
            visible: !root.round && root.source !== "" && status === Image.Ready
            source: root.round ? "" : root.shown
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            sourceSize.width: 128
            sourceSize.height: 128
        }

        // a round cover: the image cut to a circle, with a small hole like a record
        Image {
            id: roundImg
            anchors.fill: parent
            visible: false
            source: root.round ? root.shown : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            sourceSize.width: 128
            sourceSize.height: 128
        }
        Rectangle {
            id: roundMask
            anchors.fill: parent
            radius: width / 2
            visible: false
            layer.enabled: true
        }
        MultiEffect {
            anchors.fill: parent
            visible: root.round && root.source !== "" && roundImg.status === Image.Ready
            source: roundImg
            maskEnabled: true
            maskSource: roundMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }
        Rectangle {
            visible: root.round && root.source !== "" && roundImg.status === Image.Ready && root.width >= 12
            anchors.centerIn: parent
            width: Math.max(2, root.width * 0.14)
            height: width
            radius: width / 2
            color: Qt.rgba(0, 0, 0, 0.55)
        }

        Text {
            textFormat: Text.PlainText  // metadata is untrusted: never auto-detect rich text
            anchors.centerIn: parent
            visible: root.source === ""
            text: "♫"
            color: root.ink
            opacity: 0.6
            font.pixelSize: Math.max(8, Math.round(root.height * 0.6))
        }
    }

    // The turn is set up by hand rather than through bindings: a restart from a change
    // handler used to run before the bindings had caught up, so the cover kept the
    // previous direction until the next change.
    RotationAnimation {
        id: turn
        target: disc
        property: "rotation"
        loops: Animation.Infinite
        direction: RotationAnimation.Numerical
        paused: running && !root.playing
    }

    function applySpin() {
        turn.stop()
        if (!root.spinning) { disc.rotation = 0; return }
        const way = root.spin === "left" ? -1 : 1
        // carry on from where the cover is, so a new direction or speed never jumps
        const at = ((disc.rotation % 360) + 360) % 360
        turn.from = at
        turn.to = at + 360 * way
        turn.duration = Math.max(2, root.spinTime) * 1000
        turn.start()
    }

    onSpinningChanged: Qt.callLater(applySpin)
    onSpinChanged: Qt.callLater(applySpin)
    onSpinTimeChanged: Qt.callLater(applySpin)
    Component.onCompleted: applySpin()
}
