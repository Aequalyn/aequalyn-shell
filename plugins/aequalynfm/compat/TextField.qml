import QtQuick

// Spartan text field: 38px high, 10px radius, thin border, focus accent. Keeps
// the field API (variant/icon/clearable/containerColor/placeholder/
// onTextEdited/onAccepted/onEscaped/input alias).
Item {
    id: tf

    property string variant: "filled"
    property string text: ""
    property string placeholder: ""
    property string label: ""
    property string icon: ""
    property bool clearable: false
    property bool password: false
    property color containerColor: Theme.surfaceHigh
    property int inputWidth: 0
    property string supporting: ""
    property bool error: false
    property Item trailing: null

    signal textEdited()
    signal accepted()
    signal escaped()

    property alias input: input

    implicitHeight: 38 + (tf.supporting !== "" ? 16 : 0)
    implicitWidth: tf.inputWidth > 0 ? tf.inputWidth : 220

    Rectangle {
        id: box
        anchors.fill: parent
        radius: 10
        color: tf.containerColor.a > 0 ? tf.containerColor : Theme.bgSurface
        border.width: input.activeFocus ? 2 : 1
        border.color: input.activeFocus ? Theme.primary : Theme.outline

        Row {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 8

            Text {
                visible: tf.icon !== ""
                text: tf.icon
                color: Theme.subtext
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 16
                anchors.verticalCenter: parent.verticalCenter
            }

            TextInput {
                id: input
                width: parent.width - (tf.icon !== "" ? 26 : 0) - (tf.clearable && tf.text !== "" ? 26 : 0)
                text: tf.text
                onTextChanged: { tf.text = text; tf.textEdited(); }
                onAccepted: tf.accepted()
                Keys.onEscapePressed: tf.escaped()
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 13
                verticalAlignment: TextInput.AlignVCenter
                anchors.verticalCenter: parent.verticalCenter
                clip: true

                Text {
                    visible: input.text === ""
                    text: tf.placeholder !== "" ? tf.placeholder : tf.label
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Text {
                visible: tf.clearable && tf.text !== ""
                text: "close"
                color: Theme.subtext
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 16
                anchors.verticalCenter: parent.verticalCenter
                MouseArea {
                    anchors.fill: parent
                    onClicked: { input.text = ""; input.forceActiveFocus(); }
                }
            }

            Item {
                visible: tf.trailing !== null
                width: tf.trailing ? tf.trailing.implicitWidth || tf.trailing.width : 0
                height: parent.height
                Component.onCompleted: if (tf.trailing) tf.trailing.parent = this
            }
        }
    }

    Text {
        visible: tf.supporting !== ""
        anchors.top: parent.top
        anchors.topMargin: 40
        anchors.left: parent.left
        anchors.leftMargin: 12
        text: tf.supporting
        color: Theme.error
        font.family: Theme.fontFamily
        font.pixelSize: 11
    }
}
