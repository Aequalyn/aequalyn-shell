import QtQuick
import "../js/Motion.js" as Motion
import "../js/Paint.js" as Paint

// The effects on one screen: a canvas the size of the screen, painted from the
// service's frames. It is cleared and left alone once there is nothing to show.
Item {
    id: root

    property var svc: null
    property real originX: 0            // where this screen starts in layout coordinates
    property real originY: 0

    readonly property var cfg: svc ? svc.worn : null
    property var mem: ({})              // what the trail keeps between frames (particles)
    property bool painted: false        // something is on the canvas right now

    // A frame is painted only when it would look different from the one before: a resting
    // pointer costs nothing, however big the screen.
    property string lastKey: ""         // what the last frame showed
    property double lastPaint: 0
    Connections {
        target: root.svc
        function onFrameChanged() { if (root.due()) root.repaint() }
    }
    function due() {
        const s = root.svc
        if (!s || !root.cfg) return root.painted
        const still = Motion.stillFor(s.motion, s.now)
        // colors that drift by themselves do so slowly on a resting pointer
        if ((root.cfg.colorMode === "rainbow" || root.cfg.colorMode === "fade") && s.now - root.lastPaint > 500) return true
        return Paint.alive(root.cfg, still, (s.now - s.findAt) / 1000, s.motion.pts.length, root.moving)
            || root.lastKey !== root.keyNow()
    }
    property bool moving: false         // the last frame had a trail, or something moving on its own
    function keyNow() { return root.svc.motion.x + "," + root.svc.motion.y }
    onCfgChanged: repaint()
    onWidthChanged: repaint()
    onHeightChanged: repaint()
    onVisibleChanged: if (visible) repaint()
    readonly property var paints: svc ? svc.wornColors : null
    onPaintsChanged: repaint()

    function repaint() { cv.requestPaint() }

    Canvas {
        id: cv
        anchors.fill: parent
        // On a GPU the canvas lives in a texture; the software renderer gets an image.
        renderTarget: GraphicsInfo.api === GraphicsInfo.Software ? Canvas.Image : Canvas.FramebufferObject
        renderStrategy: Canvas.Cooperative
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d")
            const s = root.svc
            if (!s || !root.cfg) { ctx.reset(); return }
            const st = s.motion
            const life = s.life
            const pts = Motion.pointsFor(st, s.now, life, root.originX, root.originY)
            const px = st.x - root.originX, py = st.y - root.originY
            const W = root.width, H = root.height
            const here = isFinite(px) && px >= -1 && py >= -1 && px <= W + 1 && py <= H + 1
            const near = here || pts.some((p) => p.x >= -50 && p.y >= -50 && p.x <= W + 50 && p.y <= H + 50)
            if (!near && !root.painted && !(root.mem.parts && root.mem.parts.length) && !(root.mem.bubbles && root.mem.bubbles.length)) { root.moving = false; root.lastKey = root.keyNow(); return }
            ctx.reset()
            const busy = Paint.frame(ctx, {
                cfg: root.cfg, pts: pts, x: px, y: py, here: here, w: W, h: H,
                colors: s.wornColors, time: s.now / 1000, dt: s.dt, moved: here ? s.moved : 0,
                speed: Motion.speed01(st), still: Motion.stillFor(st, s.now), findAge: (s.now - s.findAt) / 1000,
                mem: root.mem
            })
            root.painted = busy || pts.length > 0 || here
            root.moving = busy || pts.length > 0
            root.lastKey = root.keyNow()
            root.lastPaint = s.now
            if (here) s.overlayBusy = busy
        }
    }
}
