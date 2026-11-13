// A window layout as a small picture: a screen outline and its windows as
// boxes, the main window in the accent colour. `boxes` are [x, y, w, h] in 0..1.
import QtQuick

Canvas {
    id: art
    property var theme
    property var boxes: []
    property bool on: false

    readonly property color ink: theme ? theme.textSecondary : "white"
    readonly property color accent: theme ? theme.accentPrimary : "white"

    onBoxesChanged: requestPaint()
    onOnChanged: requestPaint()
    onInkChanged: requestPaint()
    onAccentChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Component.onCompleted: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        if (width < 8 || height < 8) return;
        ctx.strokeStyle = Qt.rgba(ink.r, ink.g, ink.b, 0.25);
        ctx.lineWidth = 1;
        ctx.strokeRect(0.5, 0.5, width - 1, height - 1);
        ctx.save();
        ctx.beginPath();
        ctx.rect(1, 1, width - 2, height - 2);
        ctx.clip();
        const pad = Math.max(2, width * 0.035), gap = Math.max(1.5, width * 0.018);
        const w = width - 2 * pad, h = height - 2 * pad;
        const list = boxes || [];
        // back to front: the main window (index 0) is drawn last, on top
        for (let i = list.length - 1; i >= 0; i--) {
            const b = list[i];
            const x = pad + b[0] * w + gap / 2, y = pad + b[1] * h + gap / 2;
            const bw = Math.max(1, b[2] * w - gap), bh = Math.max(1, b[3] * h - gap);
            const main = i === 0;
            const c = main ? (on ? accent : ink) : ink;
            ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, main ? (on ? 0.6 : 0.34) : 0.13);
            ctx.fillRect(x, y, bw, bh);
            ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, main ? 0.95 : 0.45);
            ctx.strokeRect(x + 0.5, y + 0.5, bw - 1, bh - 1);
        }
        ctx.restore();
    }
}
