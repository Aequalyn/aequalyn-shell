// A wide button: an icon and a word or two. `accent`: filled (the panel's last button,
// to its settings); `on`: one of a few, the one chosen.
import QtQuick
import QtQuick.Layouts
import Quickshell

Rectangle {
    id: wb
    property string glyph: ""
    property string label: ""
    property bool accent: false
    property bool on: false
    signal clicked()
    Layout.fillWidth: true
    implicitHeight: 40
    implicitWidth: row.implicitWidth + 24
    radius: 12
    readonly property bool filled: accent || on
    color: filled ? (wbArea.containsMouse && enabled ? Qt.lighter(Quick.theme.accentPrimary, 1.1) : Quick.theme.accentPrimary)
         : (wbArea.containsMouse && enabled ? Quick.theme.bgHover : Quick.theme.bgSurface)
    opacity: enabled ? 1 : 0.4
    Accessible.role: Accessible.Button
    Accessible.name: label
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8
        Text {
            visible: wb.glyph !== ""
            text: wb.glyph
            color: wb.filled ? Quick.theme.bgBase : Quick.theme.accentPrimary
            font.family: Quick.mono
            font.pixelSize: 15
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            visible: wb.label !== ""
            text: wb.label
            color: wb.filled ? Quick.theme.bgBase : Quick.theme.textPrimary
            font.family: Quick.sans
            font.pixelSize: 12
            font.weight: Font.DemiBold
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    MouseArea {
        id: wbArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: wb.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: wb.clicked()
    }
}
