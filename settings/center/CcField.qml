// A one-line text field, with a quiet frame.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Rectangle {
    id: f
    property alias text: input.text
    property string placeholder: ""
    property int inputWidth: 0
    property int echoMode: TextInput.Normal
    signal accepted()

    function forceInput() { input.forceActiveFocus(); }
    implicitHeight: 34
    implicitWidth: inputWidth > 0 ? inputWidth : 220
    radius: 6
    color: Cc.alpha(Cc.theme.textPrimary, 0.05)
    border.width: 1
    border.color: Cc.alpha(Cc.theme.textPrimary, input.activeFocus ? 0.28 : 0.08)
    Behavior on border.color { ColorAnimation { duration: 90 } }
    // in a section's group: room of its own beside the rows
    readonly property bool grouped: Cc.inGroup(f)
    readonly property bool roomy: Cc.inGroupBody(f)
    Layout.leftMargin: roomy ? 12 : 0
    Layout.topMargin: roomy ? 8 : 0
    Layout.bottomMargin: roomy ? 8 : 0


    MouseArea {
        anchors.fill: parent
        onClicked: input.forceActiveFocus()
    }
    TextInput {
        id: input
        echoMode: f.echoMode
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        color: Cc.theme.textPrimary
        selectionColor: Cc.theme.accentPrimary
        selectedTextColor: Cc.theme.bgBase
        font.family: Cc.sans
        font.pixelSize: 12
        clip: true
        selectByMouse: true
        Keys.onReturnPressed: f.accepted()
        Keys.onEnterPressed: f.accepted()

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text === "" && !input.activeFocus
            text: f.placeholder
            color: Cc.alpha(Cc.theme.textPrimary, 0.4)
            font: input.font
        }
    }
}
