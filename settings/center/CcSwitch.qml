// An on / off switch, kept small and quiet.
import QtQuick

Rectangle {
    id: sw
    property bool checked: false
    signal toggled(bool value)

    implicitWidth: 34
    implicitHeight: 18
    radius: height / 2
    opacity: enabled ? 1 : 0.45
    color: checked ? Cc.theme.accentPrimary : Cc.alpha(Cc.theme.textPrimary, 0.18)
    Behavior on color { ColorAnimation { duration: 100 } }

    Accessible.role: Accessible.CheckBox
    Accessible.checked: checked

    Rectangle {
        readonly property real m: 3
        width: sw.height - 2 * m
        height: width
        radius: width / 2
        y: m
        x: sw.checked ? sw.width - width - m : m
        color: sw.checked ? Cc.theme.bgBase : Cc.theme.textPrimary
        opacity: sw.checked ? 1 : 0.7
        Behavior on x { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
    }
    MouseArea {
        anchors.fill: parent
        enabled: sw.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: sw.toggled(!sw.checked)
    }
}
