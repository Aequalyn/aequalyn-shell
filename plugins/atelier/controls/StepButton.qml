// The small − / + button beside a slider reading, drawn like the desktop's settings.
import QtQuick

Rectangle {
    id: button
    property var theme
    property string glyph: ""
    signal clicked()

    implicitWidth: 26
    implicitHeight: 26
    radius: 6
    color: button.theme ? Qt.rgba(button.theme.textPrimary.r, button.theme.textPrimary.g,
                                 button.theme.textPrimary.b, area.containsMouse ? 0.16 : 0.08)
                        : "transparent"

    Text {
        anchors.centerIn: parent
        text: button.glyph
        color: button.theme ? button.theme.textPrimary : "white"
        font.family: "sans-serif"
        font.pixelSize: 13
        font.weight: Font.DemiBold
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }
}
