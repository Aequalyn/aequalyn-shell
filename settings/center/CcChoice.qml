// One of a few answers, as chips (the Applications menu's categories): the chosen one
// lifted, its edge and words in the accent. `options` are strings or
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
    spacing: 6
    // in a section's group: room of its own beside the rows
    readonly property bool grouped: Cc.inGroup(c)
    readonly property bool roomy: Cc.inGroupBody(c)
    Layout.leftMargin: roomy ? 12 : 0
    Layout.rightMargin: roomy ? 12 : 0
    Layout.topMargin: roomy ? 8 : 0
    Layout.bottomMargin: roomy ? 8 : 0

    Repeater {
        model: c.options
        delegate: Rectangle {
            id: opt
            required property var modelData
            readonly property var key: typeof modelData === "object" ? modelData.key : modelData
            readonly property string label: typeof modelData === "object" ? modelData.label : String(modelData)
            readonly property bool on: key === c.value

            implicitWidth: lbl.implicitWidth + 24
            implicitHeight: 32
            radius: 8
            color: on ? Cc.theme.bgSelected : (area.containsMouse ? Cc.theme.bgHover : (c.grouped ? Cc.theme.bgBase : Cc.theme.bgSurface))
            border.width: 1
            border.color: on ? Cc.theme.accentPrimary : Cc.theme.bgBorder
            Behavior on color { ColorAnimation { duration: 120 } }
            Accessible.role: Accessible.RadioButton
            Accessible.name: label
            Accessible.checked: on

            Text {
                id: lbl
                anchors.centerIn: parent
                text: opt.label
                color: opt.on ? Cc.theme.accentPrimary : Cc.theme.textSecondary
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
