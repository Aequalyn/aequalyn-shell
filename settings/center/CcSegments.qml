// One row of joined buttons, with one chosen: the accent fills the picked button.
// Used for settings choices and for a page's sub-page tabs. `options` are strings
// or { key, label } objects; click emits `chosen(key)`.
import QtQuick
import QtQuick.Layouts
import "root:/settings"

Rectangle {
    id: s
    property var options: []
    property var current
    signal chosen(var key)
    property bool wrap: true
    property int role: Accessible.RadioButton

    function keyAt(i) {
        const o = s.options[i];
        return typeof o === "object" ? o.key : o;
    }
    function labelAt(i) {
        const o = s.options[i];
        if (typeof o !== "object") return String(o);
        return o.label !== undefined ? String(o.label) : String(o.key);
    }
    function widestLabel() {
        let label = "";
        for (let i = 0; i < s.options.length; i++)
            if (labelAt(i).length > label.length) label = labelAt(i);
        return label;
    }

    Layout.fillWidth: true
    implicitHeight: s.options.length === 0 ? 0 : grid.implicitHeight + 8
    radius: 6
    color: s.options.length === 0 ? "transparent" : Cc.alpha(Cc.theme.textPrimary, 0.04)
    border.width: s.options.length === 0 ? 0 : 1
    border.color: Cc.alpha(Cc.theme.textPrimary, 0.09)
    opacity: s.enabled ? 1 : 0.4

    TextMetrics {
        id: widest
        font.family: Cc.sans
        font.pixelSize: 11
        font.weight: Font.DemiBold
        text: s.widestLabel()
    }
    readonly property real cellWidth: Math.min(220, Math.max(96, widest.width + 26))
    readonly property int columns: s.options.length === 0 ? 1 : (!s.wrap ? s.options.length
        : Math.max(1, Math.min(s.options.length, Math.floor((s.width + 6) / (cellWidth + 6)))))

    GridLayout {
        id: grid
        anchors.fill: parent
        anchors.margins: 3
        columns: s.columns
        columnSpacing: 2
        rowSpacing: 2

        Repeater {
            model: s.options
            delegate: Rectangle {
                id: opt
                required property var modelData
                required property int index
                readonly property var key: s.keyAt(opt.index)
                readonly property string label: s.labelAt(opt.index)
                readonly property bool on: key === s.current

                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                Layout.preferredHeight: 36
                Layout.minimumWidth: 72
                radius: 4
                color: opt.on ? Cc.theme.accentPrimary
                              : (area.containsMouse ? Cc.alpha(Cc.theme.textPrimary, 0.08) : "transparent")
                Behavior on color { ColorAnimation { duration: 90 } }

                Accessible.role: s.role
                Accessible.name: opt.label
                Accessible.checked: opt.on

                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    text: opt.label
                    color: opt.on ? Cc.theme.bgBase : Cc.theme.textPrimary
                    opacity: opt.on ? 1 : 0.8
                    font.family: Cc.sans
                    font.pixelSize: 11
                    font.weight: opt.on ? Font.DemiBold : Font.Normal
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: s.enabled
                    cursorShape: Qt.PointingHandCursor
                    onClicked: s.chosen(opt.key)
                }
            }
        }
    }
}
