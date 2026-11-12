// The bar's shapes, painted behind its widgets: where they go comes from
// Shapes.layout() (a band, a pill, an island per group or a pill per widget),
// what they look like from Style.params() + Paint.paint(), the same painter the
// docks use. The widgets are measured a few times a second; shapes only move
// (and only repaint) when something actually changed.
import QtQuick
import "../style/Shapes.js" as Shapes
import "../style/Style.js" as Style
import "../style/Paint.js" as Paint
import "../style/BarLooks.js" as BarLooks
import "../style/Colors.js" as Colors

Item {
    id: deco
    property var theme
    property var look
    property int barSize: 32
    property var sections: []          // the three Rows of widgets
    property var regionNames: []
    // previews (Atelier): made up widgets instead of measured ones,
    // [{ a, len, region, hovered }]
    property var fakeSlots: null
    onFakeSlotsChanged: refresh()
    onHeightChanged: refresh()

    readonly property int margin: 16
    readonly property bool edgeAtStart: true      // the bar sits at the top

    // ---- colors ---------------------------------------------------------------
    readonly property var pal: look ? Colors.forMode(deco.theme, look.colorMode, look) : Colors.mono
    // Palette colors: every shape takes the next color of the theme
    function toneFor(index) {
        if (!look || look.colorMode !== "palette" || index < 0 || pal.spectrum.length === 0) return "";
        return pal.spectrum[index % pal.spectrum.length];
    }

    // everything one shape's canvas needs
    function paramsFor(index, region, w, h, r, attached) {
        if (!look) return { width: 0, height: 0 };
        const d = Object.assign({}, look);
        if (region === "center" && look.centerStyle === "accent") {
            d.border = "accent";
            if (d.lines === "none") d.lines = "solid";
        }
        if (region === "center" && look.centerStyle === "tinted") d.gradientTo = "accent";
        const tone = toneFor(index);
        const p = Style.params(d, pal, w, h, deco.margin, { edge: "top", tone: tone !== "" ? tone : undefined });
        p.dir = BarLooks.dirFor(look, region);
        p.r = r;
        p.ends = look.shape === "full" ? "square" : look.ends;
        p.edge = attached ? "start" : "";
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
            for (let i = 0; i < row.children.length; i++) {
                const it = row.children[i];
                if (!it || !it.visible || it.width < 2 || it.hovered === undefined) continue;
                const p = it.mapToItem(deco, 0, 0);
                out.push({ a: Math.round(p.x), len: Math.round(it.width), region: deco.regionNames[s],
                           hovered: it.hovered === true, open: false });
            }
        }
        return out;
    }

    property string lastKey: ""
    function refresh() {
        if (!look || !visible || width <= 0) return;
        const view = { length: width, thickness: height, barSize: deco.barSize, edgeAtStart: true };
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
    Timer { interval: 200; repeat: true; running: deco.visible && !deco.fakeSlots; onTriggered: deco.refresh() }
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
            x: a - m
            y: c - (attached ? 0 : m)
            width: len + 2 * m
            height: w + (attached ? 0 : m) + m
            Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

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
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 2
        color: deco.theme ? deco.theme.accentPrimary : "white"
    }

    Repeater {
        model: divModel
        delegate: Rectangle {
            required property real a
            required property real c
            required property real w
            x: a; y: c; width: 1; height: w
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
            x: a - 4; y: c; width: 8; height: w
            Rectangle {
                visible: parent.kind === "line" || parent.kind === "slash"
                anchors.centerIn: parent
                width: 1; height: parent.height
                rotation: parent.kind === "slash" ? 20 : 0
                antialiasing: true
                color: deco.theme ? Qt.rgba(deco.theme.textPrimary.r, deco.theme.textPrimary.g, deco.theme.textPrimary.b, 0.3) : "white"
            }
            Rectangle {
                visible: parent.kind === "dot"
                anchors.centerIn: parent
                width: 3; height: 3; radius: 1.5
                color: deco.theme ? Qt.rgba(deco.theme.textPrimary.r, deco.theme.textPrimary.g, deco.theme.textPrimary.b, 0.4) : "white"
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
            readonly property string style: deco.look ? deco.look.hover : "none"
            readonly property color tone: deco.look && deco.look.hoverColor === "accent" && deco.theme
                ? deco.theme.accentPrimary : (deco.theme ? deco.theme.textPrimary : "white")
            x: a; y: c; width: len; height: w
            Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
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
                visible: mark.style === "underline"
                width: parent.width * 0.5; height: 2; radius: 1
                x: (parent.width - width) / 2; y: parent.height - 3
                color: Qt.rgba(mark.tone.r, mark.tone.g, mark.tone.b, 0.7)
            }
            Rectangle {
                visible: mark.style === "dot"
                width: 4; height: 4; radius: 2
                x: (parent.width - 4) / 2; y: parent.height - 6
                color: mark.tone
            }
        }
    }
}
