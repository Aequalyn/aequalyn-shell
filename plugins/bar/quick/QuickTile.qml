// A setting that is on or off, or one of a few to pick from: a click turns it on or
// off; its arrow (when it has a page) opens that page.
import QtQuick
import QtQuick.Layouts
import Quickshell

Rectangle {
    id: tile
    property string glyph: ""
    property string title: ""
    property string sub: ""
    property bool on: false
    property bool hasMore: false        // it has a page in the control center
    signal toggled()
    signal more()
    Layout.fillWidth: true
    implicitHeight: 62
    radius: 14
    color: on ? Quick.theme.accentPrimary : (tileArea.containsMouse && enabled ? Quick.theme.bgHover : Quick.theme.bgSurface)
    opacity: enabled ? 1 : 0.45
    Behavior on color { ColorAnimation { duration: 140 } }
    Accessible.role: Accessible.CheckBox
    Accessible.name: title
    Accessible.checked: on
    readonly property color ink: on ? Quick.theme.bgBase : Quick.theme.textPrimary

    MouseArea {
        id: tileArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: tile.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: tile.toggled()
    }
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 4
        spacing: 10
        Text {
            text: tile.glyph
            color: tile.on ? Quick.theme.bgBase : Quick.theme.accentPrimary
            font.family: Quick.mono
            font.pixelSize: 18
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text {
                text: tile.title
                color: tile.ink
                font.family: Quick.sans
                font.pixelSize: 12
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Text {
                visible: tile.sub !== ""
                text: tile.sub
                color: tile.on ? Quick.alpha(Quick.theme.bgBase, 0.75) : Quick.theme.textMuted
                font.family: Quick.sans
                font.pixelSize: 10
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
        Rectangle {
            visible: tile.hasMore
            Layout.preferredWidth: 26
            Layout.preferredHeight: 40
            radius: 9
            color: moreArea.containsMouse ? Qt.rgba(0, 0, 0, 0.12) : "transparent"
            Accessible.role: Accessible.Button
            Accessible.name: tile.title + " settings"
            Text {
                anchors.centerIn: parent
                text: "\u{F0142}"
                color: tile.ink
                font.family: Quick.mono
                font.pixelSize: 15
            }
            MouseArea {
                id: moreArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: tile.more()
            }
        }
    }
}
