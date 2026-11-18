// A chip, as the Applications menu's categories: one of many to pick from. The chosen
// one is lifted, its edge and words in the accent.
import QtQuick
import Quickshell

Rectangle {
    id: chip
    property string label: ""
    property bool on: false
    signal clicked()
    implicitWidth: chipText.implicitWidth + 20
    implicitHeight: 28
    radius: 8
    color: on ? Quick.theme.bgSelected : chipArea.containsMouse && enabled ? Quick.theme.bgHover : Quick.theme.bgSurface
    border.width: 1
    border.color: on ? Quick.theme.accentPrimary : Quick.theme.bgBorder
    opacity: enabled ? 1 : 0.4
    Accessible.role: Accessible.RadioButton
    Accessible.name: label
    Accessible.checked: on
    Text {
        id: chipText
        anchors.centerIn: parent
        text: chip.label
        color: chip.on ? Quick.theme.accentPrimary : Quick.theme.textSecondary
        font.family: Quick.mono
        font.pixelSize: 11
    }
    MouseArea {
        id: chipArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: chip.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.clicked()
    }
}
