// A small card that opens a page: an icon, what it is and how it is right now.
// The card itself is a quiet tile; live previews are never drawn here.
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
    implicitHeight: 62
    radius: 6
    color: lit ? Cc.alpha(Cc.theme.accentPrimary, 0.12)
         : (area.containsMouse ? Cc.alpha(Cc.theme.textPrimary, 0.10) : Cc.alpha(Cc.theme.textPrimary, 0.04))
    border.width: 1
    border.color: lit ? Cc.theme.accentPrimary : Cc.alpha(Cc.theme.textPrimary, 0.08)
    Behavior on color { ColorAnimation { duration: 90 } }
    Accessible.role: Accessible.Button
    Accessible.name: title + ": " + sub

    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8
        Text {
            text: card.icon
            color: Cc.theme.accentPrimary
            font.family: Cc.mono
            font.pixelSize: 16
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Text {
                text: card.title
                color: Cc.theme.textPrimary
                font.family: Cc.sans
                font.pixelSize: 11
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Text {
                text: card.sub
                color: card.lit ? Cc.theme.accentPrimary : Cc.theme.textMuted
                opacity: card.lit ? 1 : 0.55
                font.family: Cc.sans
                font.pixelSize: 9
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
