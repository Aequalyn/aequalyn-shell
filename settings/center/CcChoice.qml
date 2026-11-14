// One of a few answers, as buttons in a row. `options` are strings or
// { key, label } objects; `setting` binds the choice to an AequalynSettings key,
// otherwise use `current` and `chosen`.
import QtQuick
import QtQuick.Layouts
import "root:/settings"

Flow {
    id: c
    property var options: []
    property var current
    property string setting: ""
    signal chosen(var key)

    readonly property var value: setting !== "" ? AequalynSettings[setting] : current

    Layout.fillWidth: true
    spacing: 8

    Repeater {
        model: c.options
        delegate: Rectangle {
            id: opt
            required property var modelData
            readonly property var key: typeof modelData === "object" ? modelData.key : modelData
            readonly property string label: typeof modelData === "object" ? modelData.label : String(modelData)
            readonly property bool on: key === c.value

            implicitWidth: lbl.implicitWidth + 30
            implicitHeight: 36
            radius: 10
            color: on ? Cc.alpha(Cc.theme.accentPrimary, 0.16) : (area.containsMouse ? Cc.theme.bgHover : Cc.theme.bgSurface)
            border.width: 2
            border.color: on ? Cc.theme.accentPrimary : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }
            Accessible.role: Accessible.RadioButton
            Accessible.name: label
            Accessible.checked: on

            Text {
                id: lbl
                anchors.centerIn: parent
                text: opt.label
                color: opt.on ? Cc.theme.textPrimary : Cc.theme.textSecondary
                font.family: Cc.sans
                font.pixelSize: 12
                font.weight: opt.on ? Font.DemiBold : Font.Normal
            }
            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (c.setting !== "") AequalynSettings.apply(c.setting, opt.key);
                    c.chosen(opt.key);
                }
            }
        }
    }
}
