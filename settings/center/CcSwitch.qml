// An on / off switch.
import QtQuick

Rectangle {
    id: sw
    property bool checked: false
    signal toggled(bool value)

    implicitWidth: 44
    implicitHeight: 26
    radius: 13
    color: checked ? Cc.theme.accentPrimary : Cc.theme.bgSelected
    opacity: enabled ? 1 : 0.4
    Behavior on color { ColorAnimation { duration: 140 } }

    Accessible.role: Accessible.CheckBox
    Accessible.checked: checked

    Rectangle {
        width: 18; height: 18; radius: 9
        y: 4
        x: sw.checked ? sw.width - width - 4 : 4
        color: sw.checked ? Cc.theme.bgBase : Cc.theme.textMuted
        Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    }
    MouseArea {
        anchors.fill: parent
        enabled: sw.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: sw.toggled(!sw.checked)
    }
}
