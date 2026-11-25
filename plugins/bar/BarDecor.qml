// The bar's shapes, painted behind its widgets: where they go comes from
// Shapes.layout() (a band, a pill, an island per group or a pill per widget),
// what they look like from Style.params() + Paint.paint(), the same painter the
// docks use. The widgets are measured a few times a second; shapes only move
// (and only repaint) when something actually changed.
import QtQuick
import  "../../style/Shapes.js" as Shapes
import  "../../style/Style.js" as Style
import  "../../style/Paint.js" as Paint
import  "../../style/BarLooks.js" as BarLooks
import  "../../style/Colors.js" as Colors
import "root:/settings"

Item {
    id: deco
    property var theme
    property var look
    property int barSize: 32
    property var sections: []          // the three Rows of widgets
    property var regionNames: []
    // optional, one per section: the item the section's widgets are seen through (a region
    // that scrolls). Widgets outside it get no shape, and ones half out are cut at its edge.
    property var viewports: []
    // previews (Atelier): made up widgets instead of measured ones,
    // [{ a, len, region, hovered }]
    property var fakeSlots: null
    onFakeSlotsChanged: refresh()
    onHeightChanged: refresh()

    readonly property int margin: 16
    // the screen edge is at the start (top bar) or the end (bottom bar) of the band
    property bool edgeAtStart: true
    onEdgeAtStartChanged: { lastKey = ""; refresh(); }
    // a side bar: the shapes run top to bottom ("along" is y, "across" is x)
    property bool vertical: false
    onVerticalChanged: { lastKey = ""; refresh(); }
    readonly property string screenEdge: vertical ? (edgeAtStart ? "left" : "right") : (edgeAtStart ? "top" : "bottom")

    // the bar fades back when nothing is under the mouse, if you asked for that
    HoverHandler { id: barHover; acceptedButtons: Qt.NoButton }
    opacity: deco.look && !barHover.hovered ? deco.look.idleOpacity / 100 : 1
    Behavior on opacity { NumberAnimation { duration: deco.look ? deco.look.fadeTime : 300; easing.type: Easing.InOutQuad } }
    // one place for the motion settings in the Motion group
    readonly property int speed: deco.look ? deco.look.speed : 180
    readonly property int easing: !deco.look ? Easing.OutCubic
        : deco.look.easing === "springy" ? Easing.OutBack
        : (deco.look.easing === "linear" ? Easing.Linear : Easing.OutCubic)

    // ---- colors ---------------------------------------------------------------
    readonly property var pal: look ? Colors.forMode(deco.theme, look.colorMode, look) : Colors.mono
    // Palette colors: the shapes take the theme's colors in the pattern the widgets'
    // colours use (Bar page), every color in turn unless another is chosen. A color
    // per group can be set for the left, middle and right separately.
    function toneFor(index, region) {
        if (!look) return "";
        if (look.groupColors && region)
            return region === "left" ? look.leftColor : (region === "center" ? look.centerColor : look.rightColor);
        if (look.colorMode !== "palette" || index < 0 || pal.spectrum.length === 0) return "";
        return Colors.inkAt(pal.spectrum, AequalynSettings.barInkPattern, index);
    }

    // everything one shape's canvas needs
    function paramsFor(index, region, w, h, r, attached) {
        if (!look) return { width: 0, height: 0 };
        const d = Object.assign({}, look);
        if (region === "center" && look.centerStyle === "accent") {
            d.border = "accent";
            if (d.lines === "none") d.lines = "solid";
        }
        const tone = toneFor(index, region);
        const p = Style.params(d, pal, w, h, deco.margin, { edge: deco.screenEdge, tone: tone !== "" ? tone : undefined,
            blur: AequalynSettings.softened, blurEnabled: AequalynSettings.softened,
            floating: Shapes.floating(look), edgeAtStart: deco.edgeAtStart,
            tinted: region === "center" && look.centerStyle === "tinted" });
        p.dir = BarLooks.dirFor(look, region);
        p.r = r;
        p.ends = look.shape === "full" ? "square" : look.ends;
        p.edge = attached ? (deco.edgeAtStart ? "start" : "end") : "";
        p.concave = attached && look.concave;
        if (look.shape === "full") p.flat = "";
        // floating shapes cast a shadow; a full band against the edge doesn't
        if (!Shapes.floating(look) && look.floatGap === 0) { p.shadow = ""; p.shadowBlur = 0; }
        return p;
    }

    // ---- measuring the widgets ----------------------------------------------------
    function measure() {
        if (deco.fakeSlots) return deco.fakeSlots.map(f => Object.assign({ open: false, hovered: false }, f));
        const out = [];
        for (let s = 0; s < deco.sections.length; s++) {
            const row = deco.sections[s];
            if (!row) continue;
            const view = deco.viewports[s];
            // along the bar: x, or y on a side bar
            const vp = view ? view.mapToItem(deco, 0, 0) : null;
            const v0 = vp ? (deco.vertical ? vp.y : vp.x) : -Infinity;
            const v1 = vp ? v0 + (deco.vertical ? view.height : view.width) : Infinity;
            for (let i = 0; i < row.children.length; i++) {
                const it = row.children[i];
                if (!it || !it.visible || it.width < 2 || it.hovered === undefined) continue;
                const p = it.mapToItem(deco, 0, 0);
                const start = deco.vertical ? p.y : p.x, size = deco.vertical ? it.height : it.width;
                const a = Math.max(start, v0), b = Math.min(start + size, v1);
                if (b - a < 2) continue;
                out.push({ a: Math.round(a), len: Math.round(b - a), region: deco.regionNames[s],
                           hovered: it.hovered === true, open: it.open === true });
            }
        }
        return out;
    }

    property string lastKey: ""
    function refresh() {
        if (!look || !visible || width <= 0) return;
        const view = { length: vertical ? height : width, thickness: vertical ? width : height,
                       barSize: deco.barSize, edgeAtStart: deco.edgeAtStart };
        const out = Shapes.layout(view, measure(), look);
        const key = JSON.stringify(out);
        if (key === lastKey) return;
        lastKey = key;
        sync(baseModel, out.shapes.filter(s => s.role === "base"));
        sync(markModel, out.shapes.filter(s => s.role !== "base"));
        sync(sepModel, out.separators);
        sync(divModel, out.dividers);
    }
    onLookChanged: { lastKey = ""; refresh(); }
    onWidthChanged: refresh()
    // A picture of the bar (fakeSlots) has no timer to catch up: one made while hidden
    // (a tab not shown yet, a page made in the background) draws when it is shown.
    onVisibleChanged: if (visible) { lastKey = ""; refresh(); }
    // what the shapes depend on: read here, so a widget that moves, grows, hides or is
    // hovered redraws them at once and a resting bar costs nothing. The timer is for what
    // no property tells.
    readonly property string watched: {
        if (!deco.visible || deco.fakeSlots) return "";
        let out = "";
        for (let s = 0; s < deco.sections.length; s++) {
            const row = deco.sections[s], view = deco.viewports[s];
            if (!row) continue;
            out += "|" + row.x + "," + row.y + "," + row.width + "," + row.height;
            if (view) out += ";" + view.x + "," + view.y + "," + view.width + "," + view.height + "," + (view.contentX || 0) + "," + (view.contentY || 0);
            for (let i = 0; i < row.children.length; i++) {
                const it = row.children[i];
                if (!it) continue;
                out += ":" + it.x + "," + it.y + "," + it.width + "," + it.height + "," + it.visible + "," + it.hovered + "," + it.open;
            }
        }
        return out;
    }
    onWatchedChanged: Qt.callLater(deco.refresh)
    Timer { interval: 1000; repeat: true; running: deco.visible && !deco.fakeSlots; onTriggered: deco.refresh() }
    Component.onCompleted: refresh()

    // models are updated in place so shapes glide instead of jumping
    function sync(model, list) {
        for (let i = 0; i < list.length; i++) {
            const it = list[i];
            const row = { a: it.a, len: it.len || 0, c: it.c, w: it.w, r: it.r || 0, role: it.role || "",
                          region: it.region || "", pidx: it.index === undefined ? -1 : it.index, attached: !!it.attached };
            if (i < model.count) model.set(i, row); else model.append(row);
        }
        while (model.count > list.length) model.remove(model.count - 1);
    }
    ListModel { id: baseModel }
    ListModel { id: markModel }
    ListModel { id: sepModel }
    ListModel { id: divModel }

    // ---- drawing ------------------------------------------------------------------
    Repeater {
        model: baseModel
        delegate: Item {
            id: shapeItem
            required property real a
            required property real len
            required property real c
            required property real w
            required property real r
            required property string region
            required property int pidx
            required property bool attached
            readonly property real m: deco.margin
            // an attached shape has no margin on the screen edge's side
            readonly property real mStart: attached && deco.edgeAtStart ? 0 : m
            readonly property real mEnd: attached && !deco.edgeAtStart ? 0 : m
            x: deco.vertical ? c - mStart : a - m
            y: deco.vertical ? a - m : c - mStart
            width: deco.vertical ? w + mStart + mEnd : len + 2 * m
            height: deco.vertical ? len + 2 * m : w + mStart + mEnd
            Behavior on x { NumberAnimation { duration: deco.speed; easing.type: deco.easing } }
            Behavior on y { NumberAnimation { duration: deco.speed; easing.type: deco.easing } }

            Canvas {
                anchors.fill: parent
                renderStrategy: Canvas.Cooperative
                readonly property var params: deco.paramsFor(shapeItem.pidx, shapeItem.region,
                    Math.round(width), Math.round(height), shapeItem.r, shapeItem.attached)
                onParamsChanged: requestPaint()
                onPaint: Paint.paint(getContext("2d"), params)
            }
        }
    }

    // a line along the side facing the windows (full band only)
    Rectangle {
        visible: deco.look && deco.look.shape === "full" && deco.look.edgeLine
        x: deco.vertical ? (deco.edgeAtStart ? parent.width - width : 0) : 0
        y: deco.vertical ? 0 : (deco.edgeAtStart ? parent.height - height : 0)
        width: deco.vertical ? 2 : parent.width
        height: deco.vertical ? parent.height : 2
        color: deco.theme ? deco.theme.accentPrimary : "white"
    }

    Repeater {
        model: divModel
        delegate: Rectangle {
            required property real a
            required property real c
            required property real w
            x: deco.vertical ? c : a; y: deco.vertical ? a : c
            width: deco.vertical ? w : 1; height: deco.vertical ? 1 : w
            color: deco.theme ? Qt.rgba(deco.theme.textPrimary.r, deco.theme.textPrimary.g, deco.theme.textPrimary.b, 0.22) : "white"
        }
    }

    Repeater {
        model: sepModel
        delegate: Item {
            required property real a
            required property real c
            required property real w
            readonly property string kind: deco.look ? deco.look.separators : "none"
            // drawn across the bar, then turned a quarter on a side bar
            x: deco.vertical ? c + (w - 8) / 2 : a - 4
            y: deco.vertical ? a - w / 2 : c
            width: 8; height: w
            rotation: deco.vertical ? 90 : 0
            Rectangle {
                visible: parent.kind === "line" || parent.kind === "slash"
                anchors.centerIn: parent
                width: 1; height: parent.height
                rotation: parent.kind === "slash" ? 20 : 0
                antialiasing: true
                color: deco.theme ? Qt.rgba(deco.theme.textPrimary.r, deco.theme.textPrimary.g, deco.theme.textPrimary.b,
                    deco.look ? deco.look.sepOpacity / 100 : 0.3) : "white"
            }
            Rectangle {
                visible: parent.kind === "dot"
                anchors.centerIn: parent
                width: 3; height: 3; radius: 1.5
                color: deco.theme ? Qt.rgba(deco.theme.textPrimary.r, deco.theme.textPrimary.g, deco.theme.textPrimary.b,
                    deco.look ? Math.min(1, deco.look.sepOpacity / 100 + 0.1) : 0.4) : "white"
            }
        }
    }

    // hover marks
    Repeater {
        model: markModel
        delegate: Item {
            id: mark
            required property real a
            required property real len
            required property real c
            required property real w
            required property real r
            required property string role
            required property string region
            readonly property string style: deco.look ? (mark.role === "open" ? deco.look.openMark : deco.look.hover) : "none"
            readonly property color tone: deco.look && (mark.role === "open" || deco.look.hoverColor === "accent") && deco.theme
                ? (deco.look.groupColors ? (mark.region === "left" ? deco.look.leftColor
                    : (mark.region === "center" ? deco.look.centerColor : deco.look.rightColor)) : deco.theme.accentPrimary)
                : (deco.theme ? deco.theme.textPrimary : "white")
            x: deco.vertical ? c : a; y: deco.vertical ? a : c
            width: deco.vertical ? w : len; height: deco.vertical ? len : w
            Behavior on x { NumberAnimation { duration: Math.round(deco.speed * 0.7); easing.type: deco.easing } }
            Behavior on y { NumberAnimation { duration: Math.round(deco.speed * 0.7); easing.type: deco.easing } }
            Behavior on width { NumberAnimation { duration: Math.round(deco.speed * 0.7); easing.type: deco.easing } }
            Behavior on height { NumberAnimation { duration: Math.round(deco.speed * 0.7); easing.type: deco.easing } }
            Rectangle {
                anchors.fill: parent
                visible: mark.style === "fill"
                radius: Math.min(mark.r, height / 2)
                color: Qt.rgba(mark.tone.r, mark.tone.g, mark.tone.b, 0.09)
            }
            Rectangle {
                anchors.fill: parent
                visible: mark.style === "glow"
                radius: Math.min(mark.r, height / 2)
                color: Qt.rgba(mark.tone.r, mark.tone.g, mark.tone.b, 0.1)
                border.width: 1
                border.color: Qt.rgba(mark.tone.r, mark.tone.g, mark.tone.b, 0.4)
            }
            Rectangle {
                visible: mark.style === "underline" || mark.style === "line"
                // on the windows' side: under the widget, or beside it on a side bar
                width: deco.vertical ? 2 : parent.width * 0.5; height: deco.vertical ? parent.height * 0.5 : 2; radius: 1
                x: deco.vertical ? (deco.edgeAtStart ? parent.width - 3 : 1) : (parent.width - width) / 2
                y: deco.vertical ? (parent.height - height) / 2 : parent.height - 3
                color: Qt.rgba(mark.tone.r, mark.tone.g, mark.tone.b, 0.7)
            }
            Rectangle {
                visible: mark.style === "dot"
                width: 4; height: 4; radius: 2
                x: deco.vertical ? (deco.edgeAtStart ? parent.width - 6 : 2) : (parent.width - 4) / 2
                y: deco.vertical ? (parent.height - 4) / 2 : parent.height - 6
                color: mark.tone
            }
        }
    }
}
