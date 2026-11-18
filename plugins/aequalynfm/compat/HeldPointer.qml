import QtQuick
import Quickshell

// Aequalyn drew its own pointer during a drag so it stayed in the same frame as
// what moved. Aequalyn uses the compositor's pointer, so this keeps the shape
// and leaves the event to whatever is underneath.
Item {
    id: hp

    property bool held: false
    property int cursor: Qt.ArrowCursor
    property int surface: -1
    property Item stage: null

    anchors.fill: parent
    z: 1000
    visible: false

    PointHandler {
        acceptedButtons: Qt.AllButtons
    }

    onHeldChanged: {
        // FloatingWindow has no cursorShape property; nothing to set here.
    }
}
