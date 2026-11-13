// Radial: thumbnails on a ring around a large round preview, like a dial.
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

    readonly property real ring: Math.min(width, height) / 2 - thumb / 2 - 8
    readonly property real thumb: Math.max(64, Math.min(width, height) * 0.15)
    readonly property var cur: items[currentIndex] || ({})

    PathView {
        id: view
        anchors.fill: parent
        model: root.items
        pathItemCount: Math.min(14, root.items.length)
        preferredHighlightBegin: 0
        preferredHighlightEnd: 0
        highlightRangeMode: PathView.StrictlyEnforceRange
        highlightMoveDuration: 280
        currentIndex: root.currentIndex
        onCurrentIndexChanged: if (currentIndex !== root.currentIndex) root.hovered(currentIndex)

        path: Path {
            startX: view.width / 2
            startY: view.height / 2 - root.ring
            PathAngleArc {
                centerX: view.width / 2
                centerY: view.height / 2
                radiusX: root.ring
                radiusY: root.ring
                startAngle: -90
                sweepAngle: 360
            }
        }

        delegate: AtelierCard {
            required property var modelData
            required property int index
            width: root.thumb
            height: root.thumb
            round: true
            showText: false
            theme: root.theme
            font: root.font
            item: modelData
            selected: index === root.currentIndex
            imageWidth: 220
            scale: selected ? 1.18 : 1.0
            Behavior on scale { NumberAnimation { duration: 160 } }
            onClicked: index === root.currentIndex ? root.picked(index) : root.hovered(index)
        }

        WheelHandler {
            onWheel: event => {
                if (root.items.length === 0) return;
                const d = (event.angleDelta.y || event.angleDelta.x) < 0 ? 1 : -1;
                root.hovered((root.currentIndex + d + root.items.length) % root.items.length);
            }
        }
    }

    // Centre dial
    AtelierCard {
        anchors.centerIn: parent
        width: (root.ring - root.thumb * 0.75) * 2
        height: width
        round: true
        showText: false
        theme: root.theme
        font: root.font
        item: root.cur
        selected: true
        imageWidth: 900
        onClicked: root.picked(root.currentIndex)
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: (root.ring - root.thumb * 0.75) * 0.62
        spacing: 2
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: label.implicitWidth + 18; height: 24; radius: 12
            color: Qt.rgba(0, 0, 0, 0.6)
            Text {
                id: label
                anchors.centerIn: parent
                text: root.cur.title || ""
                color: "#ffffff"
                font.family: root.font
                font.pixelSize: 12
                font.bold: true
            }
        }
    }
}
