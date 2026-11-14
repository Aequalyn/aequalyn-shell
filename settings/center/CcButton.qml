// A button: plain, `primary` (filled with the accent) or `danger` (red on hover).
import QtQuick

Rectangle {
    id: b
    property string text: ""
    property string icon: ""
    property bool primary: false
    property bool danger: false
    signal clicked()

    implicitWidth: row.implicitWidth + 28
    implicitHeight: 34
    radius: 10
    color: primary ? (area.containsMouse ? Qt.lighter(Cc.theme.accentPrimary, 1.12) : Cc.theme.accentPrimary)
         : danger && area.containsMouse ? Cc.theme.accentRed
         : area.containsMouse ? Cc.theme.bgHover : Cc.theme.bgSelected
    opacity: enabled ? 1 : 0.45
    Behavior on color { ColorAnimation { duration: 120 } }

    Accessible.role: Accessible.Button
    Accessible.name: text

    readonly property color ink: primary || (danger && area.containsMouse) ? Cc.theme.bgBase : Cc.theme.textPrimary
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 7
        Text {
            visible: b.icon !== ""
            text: b.icon
            color: b.ink
            font.family: Cc.mono
            font.pixelSize: 14
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            visible: b.text !== ""
            text: b.text
            color: b.ink
            font.family: Cc.sans
            font.pixelSize: 12
            font.weight: Font.DemiBold
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: b.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: b.clicked()
    }
}
