// A row of chips that scrolls sideways when they don't fit (the wheel scrolls it too),
// as the Applications menu's categories. `options` [{ key, label }], `current` the
// chosen key; `chosen(key)` when one is clicked. The chosen one is kept in view.
import QtQuick
import QtQuick.Layouts
import Quickshell

Flickable {
    id: row
    property var options: []
    property string current: ""
    signal chosen(string key)
    Layout.fillWidth: true
    implicitHeight: 28
    contentWidth: chipsRow.implicitWidth
    contentHeight: 28
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.HorizontalFlick
    function show(item) {
        if (!item) return
        if (item.x < contentX) contentX = item.x
        else if (item.x + item.width > contentX + width) contentX = Math.min(contentWidth - width, item.x + item.width - width)
    }
    WheelHandler {
        onWheel: e => {
            const d = Math.abs(e.angleDelta.x) > Math.abs(e.angleDelta.y) ? e.angleDelta.x : e.angleDelta.y
            row.contentX = Math.max(0, Math.min(row.contentWidth - row.width, row.contentX - d / 2))
        }
    }
    Row {
        id: chipsRow
        spacing: 6
        Repeater {
            model: row.options
            delegate: QuickChip {
                id: chipItem
                required property var modelData
                label: modelData.label
                on: modelData.key === row.current
                onOnChanged: if (on) Qt.callLater(row.show, chipItem)
                Component.onCompleted: if (on) Qt.callLater(row.show, chipItem)
                onClicked: row.chosen(modelData.key)
            }
        }
    }
}
