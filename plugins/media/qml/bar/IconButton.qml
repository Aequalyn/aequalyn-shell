import QtQuick
import "root:/settings"

Item {
    id: root
    property string iconText: ""
    property color foreground: "white"
    property string fontFamily: AequalynSettings.monoFont
    property real iconSize: 12
    property real horizontalPadding: 6
    property real verticalPadding: 3
    property bool enabled: true
    signal clicked()
    implicitWidth: label.implicitWidth + horizontalPadding * 2
    implicitHeight: label.implicitHeight + verticalPadding * 2
    opacity: enabled ? 1 : 0.4
    Text {
        id: label
        anchors.centerIn: parent
        text: root.iconText
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: root.iconSize
    }
    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
