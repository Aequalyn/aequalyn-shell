// A thing in a list (a network, a device, an app): an icon, its name and state, and
// up to two buttons. Anything else (a switch) goes inside, before the buttons.
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: r
    property string icon: ""
    property string title: ""
    property string sub: ""
    property string action: ""
    property bool primary: false
    property string action2: ""
    property bool danger2: false
    property bool busy: false
    property bool highlight: false
    property bool clickable: false
    default property alias trailing: tail.data
    signal activated()
    signal activated2()
    signal clicked()

    Layout.fillWidth: true
    implicitHeight: Math.max(58, texts.implicitHeight + 22)
    radius: 12
    color: clickable && area.containsMouse ? Cc.theme.bgHover : Cc.theme.bgSurface
    border.width: highlight ? 2 : 0
    border.color: Cc.theme.accentPrimary

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: r.clickable
        enabled: r.clickable
        cursorShape: Qt.PointingHandCursor
        onClicked: r.clicked()
    }
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 12
        spacing: 12
        Rectangle {
            visible: r.icon !== ""
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            radius: 10
            color: r.highlight ? Cc.theme.accentPrimary : Cc.theme.bgSelected
            Text {
                anchors.centerIn: parent
                text: r.icon
                color: r.highlight ? Cc.theme.bgBase : Cc.theme.accentPrimary
                font.family: Cc.mono
                font.pixelSize: 17
            }
        }
        ColumnLayout {
            id: texts
            Layout.fillWidth: true
            spacing: 1
            Text {
                text: r.title
                color: Cc.theme.textPrimary
                font.family: Cc.sans
                font.pixelSize: 13
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Text {
                visible: r.sub !== ""
                text: r.sub
                color: Cc.theme.textMuted
                font.family: Cc.sans
                font.pixelSize: 11
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
        RowLayout { id: tail; spacing: 8 }
        CcButton {
            visible: r.action2 !== ""
            text: r.action2
            danger: r.danger2
            onClicked: r.activated2()
        }
        CcButton {
            visible: r.action !== ""
            text: r.action
            primary: r.primary
            enabled: !r.busy
            onClicked: r.activated()
        }
    }
}
