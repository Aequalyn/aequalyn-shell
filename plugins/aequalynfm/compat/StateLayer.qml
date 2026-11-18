import QtQuick

// Spartan interaction surface: hover/press tint only, no ripple, no spring.
// Keeps the StateLayer API (radius/tint/disabled/hoverOpacity/pressOpacity/
// ripple/active) so the ported QML keeps working.
MouseArea {
    id: sl

    property real radius: 0
    property color tint: Theme.text
    property bool ripple: true
    property bool disabled: false
    property real hoverOpacity: 0.06
    property real pressOpacity: 0.12
    readonly property bool active: sl.containsMouse && !sl.disabled

    anchors.fill: parent
    hoverEnabled: true
    enabled: !sl.disabled
    cursorShape: sl.disabled ? Qt.ArrowCursor : Qt.PointingHandCursor

    Rectangle {
        anchors.fill: parent
        radius: sl.radius
        color: sl.tint
        opacity: sl.disabled ? 0 : (sl.pressed ? sl.pressOpacity : (sl.containsMouse ? sl.hoverOpacity : 0))
        Behavior on opacity { ColorAnimation { duration: 120 } }
    }
}
