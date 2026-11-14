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
            font.family: "sans-serif"
            font.pixelSize: 13
            Layout.fillWidth: true
        }
        Text {
            visible: toggle.sublabel !== ""
            text: toggle.sublabel
            color: toggle.theme.textMuted
            font.family: "sans-serif"
            font.pixelSize: 11
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }

    Rectangle {
        implicitWidth: 44
        implicitHeight: 26
        radius: 13
        color: toggle.checked ? toggle.theme.accentPrimary : toggle.theme.bgHover
        border.color: toggle.theme.bgBorder
        Behavior on color { ColorAnimation { duration: 120 } }

        Rectangle {
            width: 18; height: 18; radius: 9
            y: 4
            x: toggle.checked ? parent.width - width - 4 : 4
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
