// Label and hint with the small on/off switch beside them, like the desktop's settings.
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

    function tint(a) {
        return theme ? Qt.rgba(theme.textPrimary.r, theme.textPrimary.g, theme.textPrimary.b, a) : "transparent";
    }

    Layout.fillWidth: true
    spacing: 12

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2
        Text {
            text: toggle.label
            color: toggle.theme ? toggle.theme.textPrimary : "white"
            font.family: "sans-serif"
            font.pixelSize: 13
            font.weight: Font.DemiBold
            Layout.fillWidth: true
        }
        Text {
            visible: toggle.sublabel !== ""
            text: toggle.sublabel
            color: toggle.theme ? toggle.theme.textMuted : "white"
            opacity: 0.55
            font.family: "sans-serif"
            font.pixelSize: 10
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }

    Rectangle {
        implicitWidth: 34
        implicitHeight: 18
        radius: height / 2
        color: toggle.checked ? (toggle.theme ? toggle.theme.accentPrimary : "white") : toggle.tint(0.18)
        Behavior on color { ColorAnimation { duration: 100 } }

        Rectangle {
            readonly property real m: 3
            width: parent.height - 2 * m
            height: width
            radius: width / 2
            y: m
            x: toggle.checked ? parent.width - width - m : m
            color: toggle.checked ? (toggle.theme ? toggle.theme.bgBase : "black")
                                  : (toggle.theme ? toggle.theme.textPrimary : "white")
            opacity: toggle.checked ? 1 : 0.7
            Behavior on x { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: toggle.toggled(!toggle.checked)
        }
    }
}
