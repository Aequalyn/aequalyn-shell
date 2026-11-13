// A dock with a few icons, painted like the real one: the preview on the
// Docks tab.
import QtQuick
import  "../../style/Style.js" as Style
import  "../../style/Paint.js" as Paint

Item {
    id: mini
    property var look: ({})       // the dock as drawn (DocksService.effective)
    property var pal
    property int icons: 6
    property int size: 34

    readonly property int glow: Style.marginFor(look)
    readonly property int cell: size + 10
    readonly property int bodyW: icons * cell + 18
    readonly property int bodyH: size + 18
    implicitWidth: bodyW + 2 * glow
    implicitHeight: bodyH + 2 * glow

    Canvas {
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        readonly property string key: JSON.stringify([mini.look, mini.pal, width, height])
        onKeyChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            if (!mini.pal) return;
            Paint.paint(ctx, Style.params(mini.look, mini.pal, width, height, mini.glow, { edge: "bottom" }));
        }
    }
    Row {
        x: mini.glow + 9 + 5
        y: mini.glow + 9
        spacing: 10
        Repeater {
            model: mini.icons
            delegate: Rectangle {
                required property int index
                readonly property var spectrum: mini.pal && mini.pal.spectrum.length ? mini.pal.spectrum : ["#7aa2f7", "#a7c080", "#fabd2f"]
                width: mini.size; height: mini.size
                radius: mini.size * 0.28
                color: spectrum[index % spectrum.length]
                opacity: 0.85
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.42; height: width; radius: width / 2
                    color: "white"; opacity: 0.55
                }
            }
        }
    }
}
