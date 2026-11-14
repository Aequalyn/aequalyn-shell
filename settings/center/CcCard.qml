// A small card that opens a page: an icon, what it is and how it is right now.
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: card
    property string icon: ""
    property string title: ""
    property string sub: ""
    property bool lit: false
    signal clicked()

    Layout.fillWidth: true
    implicitHeight: 72
    radius: 14
    color: lit ? Cc.theme.accentPrimary : (area.containsMouse ? Cc.theme.bgHover : Cc.theme.bgSurface)
    Behavior on color { ColorAnimation { duration: 120 } }
    Accessible.role: Accessible.Button
    Accessible.name: title + ": " + sub

    RowLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12
        Text {
            text: card.icon
            color: card.lit ? Cc.theme.bgBase : Cc.theme.accentPrimary
            font.family: Cc.mono
            font.pixelSize: 20
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Text {
                text: card.title
                color: card.lit ? Cc.theme.bgBase : Cc.theme.textPrimary
                font.family: Cc.sans
                font.pixelSize: 13
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Text {
                text: card.sub
                color: card.lit ? Cc.alpha(Cc.theme.bgBase, 0.75) : Cc.theme.textMuted
                font.family: Cc.sans
                font.pixelSize: 11
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: card.clicked()
    }
}
