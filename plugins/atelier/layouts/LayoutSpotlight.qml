// Spotlight: the current item fills the screen, a slim strip floats at the
// bottom. The closest thing to trying a wallpaper before applying it.
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

    Image {
        id: full
        anchors.fill: parent
        visible: !!root.cur.image
        source: root.cur.image ? "file://" + root.cur.image : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: 2560
        asynchronous: true
        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 220 } }
    }
    PaletteMock {
        anchors.fill: parent
        visible: !root.cur.image && !!root.cur.palette
        colors: root.cur.palette || ({})
    }
    MouseArea {
        anchors.fill: parent
        onClicked: root.picked(root.currentIndex)
    }

    // Floating strip
    Rectangle {
        id: dock
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 28
        width: Math.min(parent.width - 80, 1100)
        height: 136
        radius: 18
        color: Qt.rgba(0, 0, 0, 0.55)
        border.color: Qt.rgba(1, 1, 1, 0.12)

        Text {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: 12
            text: (root.cur.title || "") + ((root.cur.subtitle || "") !== "" ? "   ·   " + root.cur.subtitle : "")
            color: "#ffffff"
            font.family: root.font
            font.pixelSize: 12
            font.bold: true
            elide: Text.ElideRight
            width: parent.width - 24
        }

        ListView {
            id: strip
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 12
            height: 82
            orientation: ListView.Horizontal
            spacing: 8
            clip: true
            model: root.items
            currentIndex: root.currentIndex
            highlightRangeMode: ListView.ApplyRange
            preferredHighlightBegin: width / 2 - 70
            preferredHighlightEnd: width / 2 + 70
            highlightMoveDuration: 180

            delegate: AtelierCard {
                required property var modelData
                required property int index
                width: 130
                height: strip.height
                theme: root.theme
                font: root.font
                item: modelData
                selected: index === root.currentIndex
                showText: false
                imageWidth: 260
                onEntered: root.hovered(index)
                onClicked: index === root.currentIndex ? root.picked(index) : root.hovered(index)
            }
        }
    }
}
