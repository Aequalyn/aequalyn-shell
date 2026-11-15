// The theme and wallpaper picker: the chosen item large in the middle, every other one
// a slanted slice beside it, overlapping the next like cards fanned on a table. Over
// the desktop, dimmed in the theme's background colour.
//
//   ← → / Tab / Shift+Tab  move (the host handles the keys)
//   a click on a slice     choose it        a click on the large one   apply it
//   a click outside        close
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

Item {
    id: root
    property var theme
    property var items: []
    property int currentIndex: 0
    property string filterText: ""
    property bool showLabels: true
    signal picked(int index)        // the large one was clicked: apply it
    signal hovered(int index)       // a slice was clicked: it becomes the large one
    signal cancelled()

    readonly property color accent: theme ? theme.accentPrimary : "#798186"
    readonly property color background: theme ? theme.bgBase : "#101315"
    readonly property color foreground: theme ? theme.textPrimary : "#cacccc"

    // the sizes everything is laid out from
    readonly property real expandedWidth: 768
    readonly property real expandedHeight: 475
    readonly property real sliceWidth: 108
    readonly property real sliceHeight: 432
    readonly property real sliceSpacing: -30          // slices overlap the next
    readonly property real skewOffset: 28             // how far the slant leans
    readonly property real itemStep: sliceWidth + sliceSpacing
    readonly property real bottomChromeHeight: showLabels ? 104 : 60

    function labelOf(it) {
        if (!it) return "";
        const raw = String(it.title || it.name || "");
        return raw.replace(/[-_]+/g, " ").replace(/\b\w/g, c => c.toUpperCase());
    }

    // ---- the backdrop: a click closes ---------------------------------------------------
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(root.background.r, root.background.g, root.background.b, 0.72)
        MouseArea { anchors.fill: parent; onClicked: root.cancelled() }
    }

    Item {
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, root.expandedWidth + 13 * root.itemStep + 40)
        height: root.expandedHeight + 30 + root.bottomChromeHeight

        Item {
            id: carousel
            anchors.top: parent.top
            anchors.topMargin: 30
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(parent.width, root.expandedWidth + 13 * root.itemStep)
            height: root.expandedHeight
            clip: true

            Repeater {
                model: root.items
                delegate: Item {
                    id: slice
                    required property var modelData
                    required property int index
                    readonly property int rel: index - root.currentIndex
                    readonly property bool chosen: rel === 0
                    readonly property real centre: carousel.width / 2

                    visible: Math.abs(rel) <= 16
                    z: chosen ? 100 : 50 - Math.min(Math.abs(rel), 40)
                    width: chosen ? root.expandedWidth : root.sliceWidth
                    height: chosen ? root.expandedHeight : root.sliceHeight
                    y: chosen ? 0 : (root.expandedHeight - root.sliceHeight) / 2
                    x: chosen ? centre - root.expandedWidth / 2
                       : rel > 0 ? centre + root.expandedWidth / 2 + root.sliceSpacing + (rel - 1) * root.itemStep
                       : centre - root.expandedWidth / 2 - root.sliceSpacing - root.sliceWidth + (rel + 1) * root.itemStep
                    Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                    // the picture, cut to the slant
                    Rectangle {
                        id: plain
                        anchors.fill: parent
                        visible: false
                        color: slice.modelData && slice.modelData.palette ? slice.modelData.palette.bgBase : root.background
                    }
                    Image {
                        id: pic
                        anchors.fill: parent
                        visible: false
                        source: slice.modelData && slice.modelData.image ? "file://" + slice.modelData.image : ""
                        sourceSize: Qt.size(root.expandedWidth, root.expandedHeight)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                    Shape {
                        id: mask
                        anchors.fill: parent
                        visible: false
                        layer.enabled: true
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            fillColor: "white"
                            strokeWidth: -1
                            startX: root.skewOffset; startY: 0
                            PathLine { x: slice.width; y: 0 }
                            PathLine { x: slice.width - root.skewOffset; y: slice.height }
                            PathLine { x: 0; y: slice.height }
                            PathLine { x: root.skewOffset; y: 0 }
                        }
                    }
                    MultiEffect {
                        anchors.fill: parent
                        source: pic.status === Image.Ready ? pic : plain
                        maskEnabled: true
                        maskSource: mask
                        maskThresholdMin: 0.3
                        maskSpreadAtMin: 0.3
                    }
                    // the others are dimmed; the chosen one has an accent edge
                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            fillColor: Qt.rgba(root.background.r, root.background.g, root.background.b, slice.chosen ? 0 : 0.42)
                            strokeColor: slice.chosen ? root.accent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.28)
                            strokeWidth: slice.chosen ? 3 : 1
                            joinStyle: ShapePath.MiterJoin
                            startX: root.skewOffset; startY: 0
                            PathLine { x: slice.width; y: 0 }
                            PathLine { x: slice.width - root.skewOffset; y: slice.height }
                            PathLine { x: 0; y: slice.height }
                            PathLine { x: root.skewOffset; y: 0 }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: slice.chosen ? root.picked(slice.index) : root.hovered(slice.index)
                    }
                }
            }
        }

        // the chosen one's name, and what you typed to filter
        Text {
            id: label
            visible: root.showLabels
            anchors.top: carousel.bottom
            anchors.topMargin: 16
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.expandedWidth
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: root.items.length > 0 ? root.labelOf(root.items[root.currentIndex]) : "Nothing matches"
            color: root.foreground
            font.pixelSize: 24
            font.weight: Font.DemiBold
            style: Text.Outline
            styleColor: Qt.rgba(root.background.r, root.background.g, root.background.b, 0.7)
        }
        Text {
            anchors.top: root.showLabels ? label.bottom : carousel.bottom
            anchors.topMargin: root.showLabels ? 8 : 16
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.filterText !== ""
            text: root.filterText
            color: root.foreground
            opacity: 0.85
            font.pixelSize: 14
        }
    }
}
