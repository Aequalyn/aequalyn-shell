// Filmstrip: a large preview of the current item over a strip of thumbnails.
import QtQuick
import ".."

Item {
    id: root
    property var theme
    property string font
    property var items: []
    property int currentIndex: 0
    readonly property int columns: 0
    signal picked(int index)
    signal hovered(int index)

    readonly property var cur: items[currentIndex] || ({})

    AtelierCard {
        id: hero
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        height: parent.height - strip.height - 16
        width: Math.min(parent.width, height * 16 / 9)
        theme: root.theme
        font: root.font
        item: root.cur
        selected: true
        imageWidth: 1600
        onClicked: root.picked(root.currentIndex)
    }

    ListView {
        id: strip
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 96
        orientation: ListView.Horizontal
        spacing: 8
        clip: true
        model: root.items
        currentIndex: root.currentIndex
        highlightRangeMode: ListView.ApplyRange
        preferredHighlightBegin: width / 2 - 80
        preferredHighlightEnd: width / 2 + 80
        highlightMoveDuration: 200
        boundsBehavior: Flickable.StopAtBounds

        delegate: AtelierCard {
            required property var modelData
            required property int index
            width: 150
            height: strip.height
            theme: root.theme
            font: root.font
            item: modelData
            selected: index === root.currentIndex
            showText: false
            imageWidth: 300
            opacity: selected ? 1 : 0.7
            onEntered: root.hovered(index)
            onClicked: root.picked(index)
        }
    }
}
