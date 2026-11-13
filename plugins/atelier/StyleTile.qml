// One look as a small painted sample: the same painter the docks and the bar
// use, so what you see here is what you get.
import QtQuick
import  "../../style/Style.js" as Style
import  "../../style/Paint.js" as Paint

Rectangle {
    id: tile
    property var theme
    property string font: "JetBrainsMono Nerd Font"
    property var look: ({})          // style keys (+ opacity, radius)
    property var pal                 // { bg, fg, ac, hot, spectrum }
    property string edge: "bottom"
    property string label: ""
    property bool selected: false
    property bool showLabel: true
    signal clicked()

    implicitWidth: 112
    implicitHeight: showLabel ? 74 : 54
    radius: 10
    color: theme ? (selected ? theme.bgSelected : (area.containsMouse ? theme.bgHover : theme.bgSurface)) : "transparent"
    border.width: selected ? 2 : 1
    border.color: theme ? (selected ? theme.accentPrimary : theme.bgBorder) : "transparent"

    Canvas {
        id: canvas
        readonly property int glow: Style.marginFor(tile.look)
        x: 8 - glow
        y: 9 - glow
        width: tile.width - 16 + 2 * glow
        height: (tile.showLabel ? 30 : tile.height - 18) + 2 * glow
        renderStrategy: Canvas.Cooperative
        readonly property string key: JSON.stringify([tile.look, tile.pal, width, height, tile.edge])
        onKeyChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            if (!tile.pal || width < 8 || height < 8) return;
            const d = Object.assign({ opacity: 92, radius: 10 }, tile.look);
            Paint.paint(ctx, Style.params(d, tile.pal, width, height, glow, { edge: tile.edge }));
        }
    }

    Text {
        visible: tile.showLabel
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - 12
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: tile.label
        color: tile.theme ? (tile.selected ? tile.theme.accentPrimary : tile.theme.textSecondary) : "white"
        font.family: tile.font
        font.pixelSize: 10
        font.bold: tile.selected
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: tile.clicked()
    }
}
