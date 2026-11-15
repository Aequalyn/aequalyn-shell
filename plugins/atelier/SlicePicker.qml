// The theme and wallpaper picker: the chosen item large, every other one a slanted
// slice beside it, overlapping the next like cards fanned on a table. Over the desktop,
// dimmed in the theme's background colour.
//
//   shape     "original" (the plain slant), "bar" or any end shape (style/parts/Ends.js)
//   position  "center", "top", "bottom": a row there; "left", "right": a column there
//   size      60 to 140 (%), the whole picker
//
//   ← → / Tab / Shift+Tab  move (the host handles the keys)
//   a click on a slice     choose it        a click on the large one   apply it
//   a click outside        close
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "root:/settings"
import  "../../style/Paint.js" as Paint

Item {
    id: root
    property var theme
    property var items: []
    property int currentIndex: 0
    property string filterText: ""
    property bool showLabels: true
    property string shape: "original"
    property string position: "center"
    property real size: 100
    signal picked(int index)        // the large one was clicked: apply it
    signal hovered(int index)       // a slice was clicked: it becomes the large one
    signal cancelled()

    readonly property color accent: theme ? theme.accentPrimary : "#798186"
    readonly property color background: theme ? theme.bgBase : "#101315"
    readonly property color foreground: theme ? theme.textPrimary : "#cacccc"

    // ---- the sizes everything is laid out from ----------------------------------------
    readonly property bool vertical: position === "left" || position === "right"
    readonly property real zoom: Math.max(0.6, Math.min(1.4, (Number(size) || 100) / 100))
    // the large card
    readonly property real expandedWidth: (vertical ? 640 : 768) * zoom
    readonly property real expandedHeight: (vertical ? 400 : 475) * zoom
    // a slice: across the row (or column) and along it
    readonly property real sliceWidth: (vertical ? 576 : 108) * zoom
    readonly property real sliceHeight: (vertical ? 90 : 432) * zoom
    readonly property real sliceSpacing: (vertical ? -24 : -30) * zoom     // slices overlap the next
    readonly property real skewOffset: (vertical ? 22 : 28) * zoom         // how far the slant leans
    readonly property real itemStep: (vertical ? sliceHeight : sliceWidth) + sliceSpacing
    readonly property real bottomChromeHeight: showLabels ? 104 : 60

    // ---- a shape other than the plain slant: the bar's painter cuts the cards ------------
    readonly property bool custom: shape !== "" && shape !== "original"
    readonly property var barLook: AequalynSettings.barStyleCfg || ({})
    readonly property string ends: shape === "bar" ? (barLook.ends || "slant") : shape
    readonly property string dir: shape === "bar" && ["left", "both"].indexOf(barLook.pointingBar) >= 0 ? barLook.pointingBar : "right"
    readonly property real cornerR: Math.max(4, Math.min(40, Number(barLook.radius) || 12))
    // The bar's ends are as deep as the shape is thick, made for a bar some 30 px tall:
    // drawn that thin and stretched to the card, they cut in by a few dozen px. In a
    // column the cards are turned, so their ends face up and down.
    function outlineOn(ctx, w, h, small) {
        let L = w, T = h;
        ctx.save();
        if (vertical) { ctx.translate(w, 0); ctx.rotate(Math.PI / 2); L = h; T = w; }
        const t = Math.max(12, Math.min(T, small ? 18 : 56));
        ctx.scale(1, T / t);
        Paint.outline(ctx, 0, 0, L, t, Math.min(small ? 6 : cornerR, t / 2), ends, "", "", dir, "");
        ctx.restore();
    }

    function labelOf(it) {
        if (!it) return "";
        const raw = String(it.title || it.name || "");
        return raw.replace(/[-_]+/g, " ").replace(/\b\w/g, c => c.toUpperCase());
    }

    // ---- the backdrop (drawn by the switcher window): a click closes ----------------------
    MouseArea { anchors.fill: parent; onClicked: root.cancelled() }

    // The cards show once the pictures near the chosen one have loaded (or after a moment,
    // whichever comes first), so they never flash empty; and they only glide once shown, so
    // their first layout does not slide in.
    property bool settled: false
    property int loadedNear: 0
    readonly property int wantNear: Math.max(0, Math.min(items.length, currentIndex + 4) - Math.max(0, currentIndex - 3))
    function checkSettled() { if (loadedNear >= wantNear) settled = true; }
    onLoadedNearChanged: checkSettled()
    onWantNearChanged: checkSettled()
    Component.onCompleted: checkSettled()
    Timer { interval: 350; running: !root.settled; onTriggered: root.settled = true }

    Item {
        id: card
        opacity: root.settled ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        readonly property real carouselLength: root.vertical
            ? Math.min(root.height - 80 - 30 - root.bottomChromeHeight, root.expandedHeight + 13 * root.itemStep)
            : Math.min(root.width - 80, root.expandedWidth + 13 * root.itemStep)
        width: root.vertical ? root.expandedWidth + 40 : Math.min(root.width - 80, root.expandedWidth + 13 * root.itemStep + 40)
        height: (root.vertical ? carouselLength : root.expandedHeight) + 30 + root.bottomChromeHeight
        x: root.position === "left" ? 60
           : root.position === "right" ? root.width - width - 60
           : (root.width - width) / 2
        y: root.position === "top" ? 40
           : root.position === "bottom" ? root.height - height - 40
           : (root.height - height) / 2

        Item {
            id: carousel
            anchors.top: parent.top
            anchors.topMargin: 30
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.vertical ? root.expandedWidth : card.carouselLength
            height: root.vertical ? card.carouselLength : root.expandedHeight
            clip: true

            Repeater {
                model: root.items
                delegate: Item {
                    id: slice
                    required property var modelData
                    required property int index
                    readonly property int rel: index - root.currentIndex
                    readonly property bool chosen: rel === 0
                    // along the row (x) or the column (y)
                    readonly property real centre: (root.vertical ? carousel.height : carousel.width) / 2
                    readonly property real along: chosen ? centre - (root.vertical ? root.expandedHeight : root.expandedWidth) / 2
                        : rel > 0 ? centre + (root.vertical ? root.expandedHeight : root.expandedWidth) / 2 + root.sliceSpacing + (rel - 1) * root.itemStep
                        : centre - (root.vertical ? root.expandedHeight : root.expandedWidth) / 2 - root.sliceSpacing
                                 - (root.vertical ? root.sliceHeight : root.sliceWidth) + (rel + 1) * root.itemStep

                    visible: Math.abs(rel) <= 16
                    z: chosen ? 100 : 50 - Math.min(Math.abs(rel), 40)
                    width: chosen ? root.expandedWidth : root.sliceWidth
                    height: chosen ? root.expandedHeight : root.sliceHeight
                    x: root.vertical ? (carousel.width - width) / 2 : along
                    y: root.vertical ? along : (root.expandedHeight - height) / 2
                    Behavior on x { enabled: root.settled; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    Behavior on y { enabled: root.settled; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    Behavior on width { enabled: root.settled; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    Behavior on height { enabled: root.settled; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                    // counted once, when its picture is in (or has none, or failed)
                    readonly property bool near: Math.abs(rel) <= 3
                    readonly property bool loaded: pic.status === Image.Ready || pic.status === Image.Error || pic.source == ""
                    property bool counted: false
                    function count() { if (near && loaded && !counted) { counted = true; root.loadedNear++; } }
                    onLoadedChanged: count()
                    onNearChanged: count()
                    Component.onCompleted: count()

                    // the plain slant: the top and bottom edges shifted in a row, the left
                    // and right ones in a column
                    readonly property real k: root.skewOffset
                    readonly property real x0: root.vertical ? 0 : k
                    readonly property real y0: root.vertical ? k : 0
                    readonly property real x2: root.vertical ? width : width - k
                    readonly property real y2: root.vertical ? height - k : height

                    // the picture, cut to the shape
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
                    Canvas {
                        id: shapedMask
                        anchors.fill: parent
                        visible: false
                        layer.enabled: true
                        readonly property var key: [width, height, root.ends, root.dir, root.cornerR, root.custom, root.vertical, slice.chosen]
                        onKeyChanged: requestPaint()
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.reset();
                            if (!root.custom || width <= 0 || height <= 0) return;
                            ctx.fillStyle = "#ffffff";
                            root.outlineOn(ctx, width, height, !slice.chosen);
                            ctx.fill();
                        }
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
                            startX: slice.x0; startY: slice.y0
                            PathLine { x: slice.width; y: 0 }
                            PathLine { x: slice.x2; y: slice.y2 }
                            PathLine { x: 0; y: slice.height }
                            PathLine { x: slice.x0; y: slice.y0 }
                        }
                    }
                    MultiEffect {
                        anchors.fill: parent
                        source: pic.status === Image.Ready ? pic : plain
                        maskEnabled: true
                        maskSource: root.custom ? shapedMask : mask
                        maskThresholdMin: 0.3
                        maskSpreadAtMin: 0.3
                    }
                    // the others are dimmed; the chosen one has an accent edge
                    Canvas {
                        anchors.fill: parent
                        visible: root.custom
                        readonly property var key: [width, height, root.ends, root.dir, root.cornerR, root.custom, root.vertical, slice.chosen,
                                                    String(root.accent), String(root.background), String(root.foreground)]
                        onKeyChanged: requestPaint()
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.reset();
                            if (!root.custom || width <= 0 || height <= 0) return;
                            const rgba = (c, a) => "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + a + ")";
                            root.outlineOn(ctx, width, height, !slice.chosen);
                            if (!slice.chosen) { ctx.fillStyle = rgba(root.background, 0.42); ctx.fill(); }
                            ctx.strokeStyle = slice.chosen ? rgba(root.accent, 1) : rgba(root.foreground, 0.28);
                            ctx.lineWidth = slice.chosen ? 3 : 1;
                            ctx.stroke();
                        }
                    }
                    Shape {
                        visible: !root.custom
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            fillColor: Qt.rgba(root.background.r, root.background.g, root.background.b, slice.chosen ? 0 : 0.42)
                            strokeColor: slice.chosen ? root.accent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.28)
                            strokeWidth: slice.chosen ? 3 : 1
                            joinStyle: ShapePath.MiterJoin
                            startX: slice.x0; startY: slice.y0
                            PathLine { x: slice.width; y: 0 }
                            PathLine { x: slice.x2; y: slice.y2 }
                            PathLine { x: 0; y: slice.height }
                            PathLine { x: slice.x0; y: slice.y0 }
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

        // the chosen one's name, and what you typed to filter: under the row, or in a
        // column on the large card's lower edge (under it, the next slices sit)
        Text {
            id: label
            visible: root.showLabels
            z: 1
            y: root.vertical ? carousel.y + carousel.height / 2 + root.expandedHeight / 2 - height - 14
                             : carousel.y + carousel.height + 16
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
            z: 1
            y: root.showLabels ? (root.vertical ? label.y - height - 6 : label.y + label.height + 8)
                               : carousel.y + carousel.height + 16
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.filterText !== ""
            style: Text.Outline
            styleColor: Qt.rgba(root.background.r, root.background.g, root.background.b, 0.7)
            text: root.filterText
            color: root.foreground
            opacity: 0.85
            font.pixelSize: 14
        }
    }
}
