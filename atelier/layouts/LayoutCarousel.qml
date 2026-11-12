// Carousel: the current item large in the middle, neighbours fan out
// smaller and dimmer on both sides. Scroll or arrows to move.
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
    // PathView rewrites its own currentIndex when dragged, which breaks a
    // plain binding; push changes in explicitly instead.
    onCurrentIndexChanged: if (view.currentIndex !== currentIndex) view.currentIndex = currentIndex

    readonly property real cardW: Math.min(width * 0.46, (height - 70) * 1.6)
    readonly property real cardH: cardW / 1.6

    PathView {
        id: view
        anchors.fill: parent
        anchors.bottomMargin: 60
        model: root.items
        pathItemCount: Math.min(7, root.items.length)
        preferredHighlightBegin: 0.5
        preferredHighlightEnd: 0.5
        highlightRangeMode: PathView.StrictlyEnforceRange
        highlightMoveDuration: 260
        currentIndex: root.currentIndex
        interactive: true
        onCurrentIndexChanged: if (currentIndex !== root.currentIndex) root.hovered(currentIndex)

        path: Path {
            startX: -root.cardW * 0.2; startY: view.height / 2
            PathAttribute { name: "itemScale"; value: 0.5 }
            PathAttribute { name: "itemZ"; value: 0 }
            PathAttribute { name: "itemOpacity"; value: 0.25 }
            PathLine { x: view.width / 2; y: view.height / 2 }
            PathAttribute { name: "itemScale"; value: 1.0 }
            PathAttribute { name: "itemZ"; value: 10 }
            PathAttribute { name: "itemOpacity"; value: 1.0 }
            PathLine { x: view.width + root.cardW * 0.2; y: view.height / 2 }
            PathAttribute { name: "itemScale"; value: 0.5 }
            PathAttribute { name: "itemZ"; value: 0 }
            PathAttribute { name: "itemOpacity"; value: 0.25 }
        }

        delegate: AtelierCard {
            id: card
            required property var modelData
            required property int index
            width: root.cardW
            height: root.cardH
            scale: PathView.itemScale || 0.5
            z: PathView.itemZ || 0
            opacity: PathView.itemOpacity || 0.25
            theme: root.theme
            font: root.font
            item: modelData
            selected: index === root.currentIndex
            showText: false
            imageWidth: 960
            onClicked: index === root.currentIndex ? root.picked(index) : root.hovered(index)
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                if (root.items.length === 0) return;
                const d = (event.angleDelta.y || event.angleDelta.x) < 0 ? 1 : -1;
                root.hovered((root.currentIndex + d + root.items.length) % root.items.length);
            }
        }
    }

    Column {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 4
        readonly property var cur: root.items[root.currentIndex] || ({})
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: parent.cur.title || ""
            color: root.theme.textPrimary
            font.family: root.font
            font.pixelSize: 16
            font.bold: true
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: (parent.cur.subtitle || "") + "   " + (root.items.length ? (root.currentIndex + 1) + " / " + root.items.length : "")
            color: root.theme.textMuted
            font.family: root.font
            font.pixelSize: 11
        }
    }
}
