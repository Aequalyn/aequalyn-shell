// A one-line text field, looking like the rest of the control center.
import QtQuick
import QtQuick.Controls

Rectangle {
    id: f
    property alias text: input.text
    property string placeholder: ""
    property int inputWidth: 0
    property int echoMode: TextInput.Normal
    signal accepted()

    function forceInput() { input.forceActiveFocus(); }
    implicitHeight: 38
    implicitWidth: inputWidth > 0 ? inputWidth : 220
    radius: 10
    color: Cc.theme.bgSurface
    border.width: input.activeFocus ? 2 : 1
    border.color: input.activeFocus ? Cc.theme.accentPrimary : Cc.theme.bgBorder

    MouseArea {
        anchors.fill: parent
        onClicked: input.forceActiveFocus()
    }
    TextInput {
        id: input
        echoMode: f.echoMode
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        color: Cc.theme.textPrimary
        selectionColor: Cc.theme.accentPrimary
        selectedTextColor: Cc.theme.bgBase
        font.family: Cc.sans
        font.pixelSize: 13
        clip: true
        selectByMouse: true
        Keys.onReturnPressed: f.accepted()
        Keys.onEnterPressed: f.accepted()

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text === "" && !input.activeFocus
            text: f.placeholder
            color: Cc.theme.textMuted
            font: input.font
        }
    }
}
