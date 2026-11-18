// A button, as everywhere in Aequalyn: quiet, with a hairline edge; `primary` (the main
// one) in the accent's edge and words on a lifted fill, `danger` red when you point at it,
// `warning` red already.
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

    implicitWidth: row.implicitWidth + 26
    implicitHeight: 32
    radius: 8
    color: primary ? (area.containsMouse ? Cc.theme.bgHover : Cc.theme.bgSelected)
         : area.containsMouse ? Cc.theme.bgHover : (grouped ? Cc.theme.bgBase : Cc.theme.bgSurface)
    border.width: 1
    border.color: warning || (danger && area.containsMouse) ? Cc.theme.accentRed
                : primary ? Cc.theme.accentPrimary : Cc.theme.bgBorder
    // in a section's group: room of its own beside the rows
    readonly property bool grouped: Cc.inGroup(b)
    readonly property bool roomy: Cc.inGroupBody(b)
    Layout.leftMargin: roomy ? 12 : 0
    Layout.topMargin: roomy ? 8 : 0
    Layout.bottomMargin: roomy ? 8 : 0

    opacity: enabled ? 1 : 0.45
    Behavior on color { ColorAnimation { duration: 120 } }

    Accessible.role: Accessible.Button
    Accessible.name: text

    readonly property color ink: warning || (danger && area.containsMouse) ? Cc.theme.accentRed
                               : primary ? Cc.theme.accentPrimary : Cc.theme.textPrimary
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
