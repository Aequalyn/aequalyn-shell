// Grid: every item at once, columns follow the width.
import QtQuick
import ".."

Item {
    id: root
    property var theme
    property string font
    property var items: []
    property int currentIndex: 0
    readonly property int columns: Math.max(2, Math.floor(width / 250))
    signal picked(int index)
    signal hovered(int index)

    GridView {
        id: view
        anchors.fill: parent
        model: root.items
        clip: true
        cellWidth: Math.floor(width / root.columns)
        cellHeight: Math.floor(cellWidth * 0.64)
        currentIndex: root.currentIndex
        boundsBehavior: Flickable.StopAtBounds
        highlightFollowsCurrentItem: false
        cacheBuffer: 600
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)

        delegate: Item {
            required property var modelData
            required property int index
            width: view.cellWidth
            height: view.cellHeight

            AtelierCard {
                anchors.fill: parent
                anchors.margins: 6
                theme: root.theme
                font: root.font
                item: modelData
                selected: index === root.currentIndex
                imageWidth: 420
                scale: selected ? 1.0 : 0.97
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                onEntered: root.hovered(index)
                onClicked: root.picked(index)
            }
        }
    }
}
