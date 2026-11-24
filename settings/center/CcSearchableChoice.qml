// A searchable choice list: filter field + selectable rows. Used for long option lists.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "root:/settings"

ColumnLayout {
    id: root
    property var options: [] // [{key,label}] or strings
    property var current
    property string setting: ""
    property string placeholder: "Search..."
    signal chosen(var key)

    readonly property var value: setting !== "" ? AequalynSettings[setting] : current
    Layout.fillWidth: true
    spacing: 6

    function norm(o) {
        if (o && typeof o === "object") return { key: o.key, label: String(o.label || o.key) }
        return { key: o, label: String(o) }
    }

    CcField {
        id: filter
        Layout.fillWidth: true
        placeholder: root.placeholder
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: Math.min(280, list.contentHeight + 8)
        radius: 8
        color: Cc.alpha(Cc.theme.textPrimary, 0.03)
        border.width: 1
        border.color: Cc.alpha(Cc.theme.textPrimary, 0.08)
        clip: true

        ListView {
            id: list
            anchors.fill: parent
            anchors.margins: 4
            model: {
                const q = filter.text.trim().toLowerCase()
                const out = []
                for (const o of root.options) {
                    const n = root.norm(o)
                    if (q === "" || n.label.toLowerCase().indexOf(q) >= 0 || String(n.key).toLowerCase().indexOf(q) >= 0)
                        out.push(n)
                }
                return out
            }
            delegate: Rectangle {
                required property var modelData
                width: ListView.view.width
                height: 32
                radius: 6
                readonly property bool selected: String(modelData.key) === String(root.value)
                color: selected ? Cc.alpha(Cc.theme.accentPrimary, 0.16) : (ma.containsMouse ? Cc.theme.bgHover : "transparent")
                border.width: selected ? 1 : 0
                border.color: Cc.theme.accentPrimary
                Text {
                    anchors.left: parent.left; anchors.leftMargin: 10
                    anchors.right: parent.right; anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.label
                    color: selected ? Cc.theme.textPrimary : Cc.theme.textSecondary
                    font.family: Cc.sans
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.setting !== "") AequalynSettings.apply(root.setting, modelData.key)
                        root.chosen(modelData.key)
                    }
                }
            }
            ScrollBar.vertical: ScrollBar { }
        }
    }
}
