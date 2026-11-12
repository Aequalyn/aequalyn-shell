// A button in Atelier's header card: ‹ › Reset all, Pop out, Dock, ×.
import QtQuick

Rectangle {
    id: btn
    property var view
    property string text: ""
    property bool square: false
    property bool primary: false
    signal clicked()

    readonly property var theme: view.theme
    implicitWidth: square ? 28 : label.implicitWidth + 22
    implicitHeight: 28
    radius: 14
    color: primary ? theme.accentPrimary
        : area.containsMouse ? Qt.rgba(theme.textPrimary.r, theme.textPrimary.g, theme.textPrimary.b, 0.12)
        : Qt.rgba(theme.textPrimary.r, theme.textPrimary.g, theme.textPrimary.b, 0.06)
    Behavior on color { ColorAnimation { duration: 100 } }

    Text {
        id: label
        anchors.centerIn: parent
        text: btn.text
        color: btn.primary ? btn.theme.bgBase : btn.theme.textPrimary
        font.family: btn.view.font
        font.pixelSize: btn.square ? 13 : 11
    }
    MouseArea {
        id: area
        anchors.fill: parent
        enabled: btn.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}
