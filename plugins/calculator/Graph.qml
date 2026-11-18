// The graph: every function that is on, over the window, with its grid and axes.
// Drag to move, the wheel to zoom where the pointer is (Shift: only across, Ctrl: only
// up and down), a double click goes back to the standard window. Where each curve
// crosses zero, turns, and meets another is found and marked by itself; resting the
// pointer traces every curve at that x and names the point under it.
import QtQuick
import "Engine.js" as Engine

Item {
    id: g
    required property var kp
    property var fns: []              // [{ text, on, color }]
    property var win: ({ xmin: -10, xmax: 10, ymin: -10, ymax: 10 })
    property var points: []           // [[x, y]]: the lists, plotted
    property var env: ({ vars: {}, deg: false })
    property int selected: -1          // the function being written: drawn a bit thicker
    signal moved(var win)

    // ---- the functions, read once each time they change --------------------------------
    readonly property var curves: {
        const out = []
        for (let i = 0; i < g.fns.length; i++) {
            const fn = g.fns[i]
            if (!fn.on || String(fn.text).trim() === "") continue
            try { out.push({ i: i, f: Engine.compile(fn.text, g.env), color: fn.color }) } catch (e) { }
        }
        return out
    }

    function px(x) { return (x - win.xmin) / (win.xmax - win.xmin) * width }
    function py(y) { return height - (y - win.ymin) / (win.ymax - win.ymin) * height }
    function ux(p) { return win.xmin + p / Math.max(1, width) * (win.xmax - win.xmin) }
    function uy(p) { return win.ymin + (height - p) / Math.max(1, height) * (win.ymax - win.ymin) }

    // ---- the points worth knowing, found a moment after the view settles -----------------
    property var marks: []
    function findMarks() {
        const out = []
        const a = win.xmin, b = win.xmax, n = Math.max(200, Math.round(width))
        const inView = p => p.y >= win.ymin && p.y <= win.ymax
        for (const c of g.curves) {
            for (const x of Engine.roots(c.f, a, b, n, 40)) out.push({ x: x, y: 0, kind: "zero", color: c.color, of: c.i })
            for (const e of Engine.extrema(c.f, a, b, n)) if (inView(e)) out.push({ x: e.x, y: e.y, kind: e.kind, color: c.color, of: c.i })
            // where it crosses the y axis
            if (a < 0 && b > 0) { const y0 = c.f(0); if (isFinite(y0) && y0 >= win.ymin && y0 <= win.ymax) out.push({ x: 0, y: y0, kind: "y", color: c.color, of: c.i }) }
        }
        for (let i = 0; i < g.curves.length; i++) for (let j = i + 1; j < g.curves.length; j++) {
            const p = g.curves[i], q = g.curves[j]
            const d = x => p.f(x) - q.f(x)
            for (const x of Engine.roots(d, a, b, n, 20)) {
                const y = p.f(x)
                if (isFinite(y) && y >= win.ymin && y <= win.ymax) out.push({ x: x, y: y, kind: "meet", color: g.kp.c_text, of: p.i, with: q.i })
            }
        }
        g.marks = out.slice(0, 120)
    }
    Timer { id: markTimer; interval: 120; onTriggered: g.findMarks() }
    function refresh() { plot.requestPaint(); markTimer.restart() }
    onCurvesChanged: refresh()
    onWinChanged: refresh()
    onPointsChanged: refresh()
    onWidthChanged: refresh()
    onHeightChanged: refresh()
    onSelectedChanged: plot.requestPaint()

    function markName(m) {
        const n = i => "Y" + (i + 1)
        if (m.kind === "zero") return n(m.of) + " is zero"
        if (m.kind === "max") return n(m.of) + " peaks"
        if (m.kind === "min") return n(m.of) + " dips"
        if (m.kind === "y") return n(m.of) + " crosses the y axis"
        return n(m.of) + " meets " + n(m.with)
    }

    // ---- drawing --------------------------------------------------------------------------
    Canvas {
        id: plot
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        onPaint: {
            const ctx = getContext("2d")
            const W = width, H = height
            ctx.reset()
            ctx.clearRect(0, 0, W, H)
            if (W < 2 || H < 2) return
            const grid = g.kp.tint(g.kp.c_text, 0.06), axis = g.kp.tint(g.kp.c_text, 0.35), label = g.kp.tint(g.kp.c_text, 0.45)
            const xt = Engine.ticks(g.win.xmin, g.win.xmax, Math.max(2, Math.round(W / 90)))
            const yt = Engine.ticks(g.win.ymin, g.win.ymax, Math.max(2, Math.round(H / 70)))
            ctx.lineWidth = 1
            ctx.strokeStyle = grid
            ctx.beginPath()
            for (const x of xt) { const p = Math.round(g.px(x)) + 0.5; ctx.moveTo(p, 0); ctx.lineTo(p, H) }
            for (const y of yt) { const p = Math.round(g.py(y)) + 0.5; ctx.moveTo(0, p); ctx.lineTo(W, p) }
            ctx.stroke()
            // the axes, where they are in view, and their numbers along them
            const ax = Math.round(g.px(0)) + 0.5, ay = Math.round(g.py(0)) + 0.5
            ctx.strokeStyle = axis
            ctx.beginPath()
            if (ax > 0 && ax < W) { ctx.moveTo(ax, 0); ctx.lineTo(ax, H) }
            if (ay > 0 && ay < H) { ctx.moveTo(0, ay); ctx.lineTo(W, ay) }
            ctx.stroke()
            ctx.fillStyle = label
            ctx.font = "10px '" + g.kp.font + "'"
            const ly = Math.min(H - 4, Math.max(12, ay + 13)), lx = Math.min(W - 4, Math.max(4, ax + 4))
            ctx.textAlign = "center"
            for (const x of xt) if (x !== 0) ctx.fillText(Engine.format(x), g.px(x), ly)
            ctx.textAlign = ax + 40 > W ? "right" : "left"
            for (const y of yt) if (y !== 0) ctx.fillText(Engine.format(y), ax + 40 > W ? W - 4 : lx, g.py(y) + 3)

            // the curves: one step per pixel, broken where there is no value or it jumps
            // through a pole (tan x), so no line is drawn down the asymptote
            const clamp = v => Math.max(-4 * H, Math.min(5 * H, v))
            for (const c of g.curves) {
                ctx.strokeStyle = c.color
                ctx.lineWidth = c.i === g.selected ? 3 : 2
                ctx.lineJoin = "round"
                ctx.beginPath()
                let prev = null
                for (let i = 0; i <= W; i++) {
                    const y = c.f(g.ux(i))
                    if (!isFinite(y)) { prev = null; continue }
                    const p = g.py(y)
                    const out = p < -H || p > 2 * H
                    if (prev === null || (Math.abs(p - prev.p) > H && (out || prev.out))) ctx.moveTo(i, clamp(p))
                    else ctx.lineTo(i, clamp(p))
                    prev = { p: p, out: out }
                }
                ctx.stroke()
            }
            // the lists' points
            ctx.fillStyle = g.kp.c_text
            for (const pt of g.points) {
                const x = g.px(pt[0]), y = g.py(pt[1])
                if (x >= -4 && x <= W + 4 && y >= -4 && y <= H + 4) ctx.fillRect(x - 3, y - 3, 6, 6)
            }
        }
    }

    // the marks: small rings, the one under the pointer larger
    Repeater {
        model: g.marks
        delegate: Rectangle {
            required property var modelData
            readonly property bool hot: !!g.hotMark && g.hotMark.kind === modelData.kind
                                        && g.hotMark.x === modelData.x && g.hotMark.y === modelData.y
            x: g.px(modelData.x) - width / 2
            y: g.py(modelData.y) - height / 2
            width: hot ? 12 : 8
            height: width
            radius: width / 2
            color: hot ? modelData.color : g.kp.c_bg
            border.width: 2
            border.color: modelData.color
        }
    }

    // ---- moving, zooming, tracing ----------------------------------------------------------
    property real hoverX: NaN
    property real hoverY: NaN
    readonly property var hotMark: {
        if (!isFinite(g.hoverX)) return null
        let best = null, bestD = 10
        for (const m of g.marks) {
            const d = Math.hypot(g.px(m.x) - g.hoverX, g.py(m.y) - g.hoverY)
            if (d < bestD) { bestD = d; best = m }
        }
        return best
    }
    // the trace: a line down at the pointer and a dot on every curve there
    Rectangle {
        visible: isFinite(g.hoverX) && !drag.dragging
        x: g.hoverX
        width: 1
        height: parent.height
        color: g.kp.tint(g.kp.c_text, 0.25)
    }
    Repeater {
        model: isFinite(g.hoverX) && !drag.dragging ? g.curves.length : 0
        delegate: Rectangle {
            required property int index
            readonly property var c: g.curves[index]
            readonly property real v: c ? c.f(g.ux(g.hoverX)) : NaN
            visible: isFinite(v) && g.py(v) >= 0 && g.py(v) <= g.height
            x: g.hoverX - 4
            y: g.py(v) - 4
            width: 8; height: 8; radius: 4
            color: c ? c.color : "transparent"
        }
    }
    // what the trace reads, in the corner
    Rectangle {
        visible: isFinite(g.hoverX) && !drag.dragging
        x: 8
        y: 8
        width: readout.implicitWidth + 16
        height: readout.implicitHeight + 12
        radius: 8
        color: g.kp.tint(g.kp.c_bg, 0.9)
        border.width: 1
        border.color: g.kp.c_border
        Column {
            id: readout
            x: 8
            y: 6
            spacing: 2
            Text {
                visible: !!g.hotMark
                text: g.hotMark ? g.markName(g.hotMark) + "   (" + Engine.format(g.hotMark.x) + ", " + Engine.format(g.hotMark.y) + ")" : ""
                textFormat: Text.PlainText
                color: g.hotMark ? g.hotMark.color : g.kp.c_text
                font.family: g.kp.font
                font.pixelSize: 11
                font.bold: true
            }
            Text {
                text: "x = " + Engine.format(isFinite(g.hoverX) ? g.ux(g.hoverX) : 0)
                textFormat: Text.PlainText
                color: g.kp.c_text2
                font.family: g.kp.font
                font.pixelSize: 11
            }
            Repeater {
                model: isFinite(g.hoverX) ? g.curves.length : 0
                delegate: Text {
                    required property int index
                    readonly property var c: g.curves[index]
                    text: c ? "Y" + (c.i + 1) + " = " + Engine.format(c.f(g.ux(g.hoverX))) : ""
                    textFormat: Text.PlainText
                    color: c ? c.color : g.kp.c_text
                    font.family: g.kp.font
                    font.pixelSize: 11
                }
            }
        }
    }

    MouseArea {
        id: drag
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: dragging ? Qt.ClosedHandCursor : Qt.CrossCursor
        property bool dragging: false
        property point from
        property var start
        onPressed: mouse => { from = Qt.point(mouse.x, mouse.y); start = g.win; dragging = false }
        onPositionChanged: mouse => {
            g.hoverX = mouse.x; g.hoverY = mouse.y
            if (!pressed) return
            if (!dragging && Math.hypot(mouse.x - from.x, mouse.y - from.y) < 3) return
            dragging = true
            const sx = (start.xmax - start.xmin) / Math.max(1, g.width), sy = (start.ymax - start.ymin) / Math.max(1, g.height)
            const dx = (mouse.x - from.x) * sx, dy = (mouse.y - from.y) * sy
            g.moved({ xmin: start.xmin - dx, xmax: start.xmax - dx, ymin: start.ymin + dy, ymax: start.ymax + dy })
        }
        onReleased: dragging = false
        onExited: { g.hoverX = NaN; g.hoverY = NaN }
        onDoubleClicked: g.moved({ xmin: -10, xmax: 10, ymin: -10, ymax: 10 })
        onWheel: wheel => {
            const d = Math.abs(wheel.angleDelta.y) >= Math.abs(wheel.angleDelta.x) ? wheel.angleDelta.y : wheel.angleDelta.x
            if (d === 0) return
            const k = Math.pow(0.85, d / 120)
            const cx = g.ux(wheel.x), cy = g.uy(wheel.y)
            const onlyX = wheel.modifiers & Qt.ShiftModifier, onlyY = wheel.modifiers & Qt.ControlModifier
            const w = g.win
            const kx = onlyY ? 1 : k, ky = onlyX ? 1 : k
            const nw = { xmin: cx - (cx - w.xmin) * kx, xmax: cx + (w.xmax - cx) * kx,
                         ymin: cy - (cy - w.ymin) * ky, ymax: cy + (w.ymax - cy) * ky }
            // not so far in that the numbers run out, nor so far out that nothing is left
            if (nw.xmax - nw.xmin < 1e-9 || nw.ymax - nw.ymin < 1e-9 || nw.xmax - nw.xmin > 1e9 || nw.ymax - nw.ymin > 1e9) return
            g.moved(nw)
        }
    }

    // a window that shows every curve's interesting part: y from what the curves reach
    // across, leaving out the far tails (poles), with a little room
    function fitted() {
        const ys = []
        for (const c of g.curves) for (let i = 0; i <= 200; i++) {
            const y = c.f(win.xmin + i / 200 * (win.xmax - win.xmin))
            if (isFinite(y)) ys.push(y)
        }
        for (const p of g.points) ys.push(p[1])
        if (ys.length < 2) return null
        ys.sort((a, b) => a - b)
        let lo = ys[Math.floor(ys.length * 0.03)], hi = ys[Math.ceil(ys.length * 0.97) - 1]
        if (hi - lo < 1e-9) { lo -= 1; hi += 1 }
        const pad = (hi - lo) * 0.1
        return { xmin: win.xmin, xmax: win.xmax, ymin: lo - pad, ymax: hi + pad }
    }
}
