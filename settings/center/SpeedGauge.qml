// A half-dial gauge for one speed-test reading. The arc fills from the left,
// the number sits in the middle, and the label names the direction.
import QtQuick

Item {
    id: gauge
    property real value: 0
    property real maxValue: 100
    property string label: ""
    property string unit: "Mbps"
    property color color: Cc.theme.accentPrimary

    width: 126
    height: 96
    readonly property real ratio: Math.max(0, Math.min(1, value / Math.max(1, maxValue)))

    Canvas {
        id: dial
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const cx = width / 2
            const cy = height - 16
            const r = Math.min(width / 2 - 10, height - 26)
            ctx.lineWidth = 8
            ctx.lineCap = "round"
            ctx.strokeStyle = Cc.alpha(Cc.theme.textPrimary, 0.12)
            ctx.beginPath()
            ctx.arc(cx, cy, r, Math.PI, 2 * Math.PI)
            ctx.stroke()
            ctx.strokeStyle = gauge.color
            ctx.beginPath()
            ctx.arc(cx, cy, r, Math.PI, Math.PI + Math.PI * gauge.ratio)
            ctx.stroke()
        }
    }
    onRatioChanged: dial.requestPaint()
    onWidthChanged: dial.requestPaint()
    onHeightChanged: dial.requestPaint()

    Text {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        text: gauge.label
        color: Cc.theme.textSecondary
        font.family: Cc.sans
        font.pixelSize: 10
        font.weight: Font.DemiBold
    }
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        spacing: 0
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: gauge.value > 0 ? gauge.value.toFixed(1) : "—"
            color: Cc.theme.textPrimary
            font.family: Cc.sans
            font.pixelSize: 19
            font.weight: Font.DemiBold
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: gauge.unit
            color: Cc.theme.textMuted
            font.family: Cc.sans
            font.pixelSize: 9
        }
    }
}
