// Label + sublabel on the left, a switch on the right.
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: toggle
    property var theme
    property string font: "JetBrainsMono Nerd Font"
    property string label: ""
    property string sublabel: ""
    property bool checked: false
    signal toggled(bool value)

    Layout.fillWidth: true
    spacing: 12

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2
        Text {
            text: toggle.label
            color: toggle.theme.textPrimary
            font.family: toggle.font
            font.pixelSize: 12
            Layout.fillWidth: true
        }
        Text {
            visible: toggle.sublabel !== ""
            text: toggle.sublabel
            color: toggle.theme.textMuted
            font.family: toggle.font
            font.pixelSize: 10
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }

    Rectangle {
        implicitWidth: 40
        implicitHeight: 22
        radius: 11
        color: toggle.checked ? toggle.theme.accentPrimary : toggle.theme.bgHover
        border.color: toggle.theme.bgBorder
        Behavior on color { ColorAnimation { duration: 120 } }

        Rectangle {
            width: 16; height: 16; radius: 8
            y: 3
            x: toggle.checked ? parent.width - width - 3 : 3
            color: toggle.checked ? toggle.theme.bgBase : toggle.theme.textMuted
            Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: toggle.toggled(!toggle.checked)
        }
    }
}
