// A button, kept compact: quiet and borderless in its
// normal state, a solid accent when `primary`, a red edge for danger and warning.
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: b
    property string text: ""
    property string icon: ""
    property bool primary: false
    property bool danger: false
    property bool warning: false
    signal clicked()

    implicitWidth: row.implicitWidth + 16
    implicitHeight: 24
    radius: 6
    color: primary ? Cc.theme.accentPrimary
         : warning || (danger && area.containsMouse) ? Cc.alpha(Cc.theme.accentRed, 0.10)
         : area.containsMouse ? Cc.alpha(Cc.theme.textPrimary, 0.12)
         : Cc.alpha(Cc.theme.textPrimary, grouped ? 0.06 : 0.04)
    border.width: !primary && (warning || danger) ? 1 : 0
    border.color: Cc.theme.accentRed
    // in a section's group: room of its own beside the rows
    readonly property bool grouped: Cc.inGroup(b)
    readonly property bool roomy: Cc.inGroupBody(b)
    Layout.leftMargin: roomy ? 12 : 0
    Layout.topMargin: roomy ? 8 : 0
    Layout.bottomMargin: roomy ? 8 : 0

    opacity: enabled ? 1 : 0.4
    Behavior on color { ColorAnimation { duration: 90 } }

    Accessible.role: Accessible.Button
    Accessible.name: text

    readonly property color ink: primary ? Cc.theme.bgBase
                                : warning || (danger && area.containsMouse) ? Cc.theme.accentRed
                                : Cc.theme.textPrimary
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5
        Text {
            visible: b.icon !== ""
            text: b.icon
            color: b.ink
            font.family: Cc.mono
            font.pixelSize: 12
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            visible: b.text !== ""
            text: b.text
            color: b.ink
            opacity: b.primary ? 1 : 0.85
            font.family: Cc.sans
            font.pixelSize: 11
            font.weight: b.primary ? Font.DemiBold : Font.Normal
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
