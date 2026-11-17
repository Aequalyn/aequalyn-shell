// A round icon button. `accent`: filled (the main button of a row); `active`: a
// setting that is on (shuffle, repeat), its icon in the accent colour.
import QtQuick
import Quickshell

Rectangle {
    id: rb
    property string glyph: ""
    property string tip: ""
    property bool small: false
    property bool accent: false
    property bool active: false
    signal clicked()
    implicitWidth: small ? 30 : 36
    implicitHeight: implicitWidth
    radius: width / 2
    color: accent ? (rbArea.containsMouse && enabled ? Quick.theme.bgHover : Quick.theme.bgSelected)
         : rbArea.containsMouse && enabled ? Quick.theme.bgHover : (small ? "transparent" : Quick.theme.bgSurface)
    border.width: accent ? 1 : 0
    border.color: Quick.theme.accentPrimary
    opacity: enabled ? 1 : 0.35
    Accessible.role: Accessible.Button
    Accessible.name: tip
    Text {
        anchors.centerIn: parent
        text: rb.glyph
        color: rb.accent || rb.active ? Quick.theme.accentPrimary : Quick.theme.textPrimary
        font.family: Quick.mono
        font.pixelSize: rb.small ? 15 : 16
    }
    MouseArea {
        id: rbArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: rb.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: rb.clicked()
    }
}
