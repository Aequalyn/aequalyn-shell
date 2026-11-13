// A ready made look (or an ensemble) as an Atelier card: the look on a bit
// of desktop, its name and one line about it.
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: card
    property var theme
    property string font: "JetBrainsMono Nerd Font"
    property string title: ""
    property string subtitle: ""
    property string badge: ""
    property bool selected: false
    property int previewHeight: 54
    default property alias preview: stageArea.data
    signal clicked()

    implicitHeight: previewHeight + 54
    radius: 12
    color: theme.bgSurface
    border.width: selected ? 2 : 1
    border.color: selected ? theme.accentPrimary : (area.containsMouse ? theme.textMuted : theme.bgBorder)
    Behavior on border.color { ColorAnimation { duration: 120 } }

    Item {
        id: stageArea
        x: 4; y: 4
        width: parent.width - 8
        height: card.previewHeight
        clip: true
    }
    ColumnLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 10
        spacing: 1
        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: card.title
                color: card.selected ? card.theme.accentPrimary : card.theme.textPrimary
                font.family: card.font
                font.pixelSize: 12
                font.bold: true
                elide: Text.ElideRight
            }
            Rectangle {
                visible: card.badge !== ""
                implicitWidth: badgeText.implicitWidth + 10
                implicitHeight: 15
                radius: 4
                color: card.selected ? card.theme.accentPrimary : card.theme.bgBase
                Text {
                    id: badgeText
                    anchors.centerIn: parent
                    text: card.badge
                    color: card.selected ? card.theme.bgBase : card.theme.textMuted
                    font.family: card.font
                    font.pixelSize: 8
                    font.bold: true
                    font.letterSpacing: 0.8
                }
            }
        }
        Text {
            Layout.fillWidth: true
            text: card.subtitle
            color: card.theme.textMuted
            font.family: card.font
            font.pixelSize: 10
            elide: Text.ElideRight
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
