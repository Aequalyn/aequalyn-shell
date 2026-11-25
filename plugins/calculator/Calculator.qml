// Calculator (Super + Alt + C): a graphing calculator with the keys of one, and the answer
// as you type. Four views, Tab between them:
//   Calc    sums, equations (solved for their unknown), letters to store in, the answer
//           as a fraction or a multiple of π too, and every sum so far to reuse
//   Graph   up to six functions of x, drawn as you write them; zeros, peaks, dips and
//           where curves meet are found and marked; drag, zoom and trace with the mouse
//   Table   the functions' values, a row per step, ↑ ↓ to move along
//   Lists   two lists of numbers: their statistics, and the line and parabola that fit
// The engine (Engine.js) reads every sum into a tree and works it out from there; no
// text is ever run as code.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "root:/plugins/kit"
import "Engine.js" as Engine

Scope {
    id: root
    property var theme: null

    KitStore {
        id: store
        pluginId: "calculator"
        defaults: ({ history: [], vars: {}, deg: false, mode: "calc",
                     fns: [{ text: "", on: true }, { text: "", on: true }, { text: "", on: true },
                           { text: "", on: true }, { text: "", on: true }, { text: "", on: true }],
                     win: { xmin: -10, xmax: 10, ymin: -10, ymax: 10 },
                     table: { start: 0, step: 1 }, l1: "", l2: "", plot: true })
    }

    // ---- what is kept ---------------------------------------------------------------------
    readonly property var history: Array.isArray(store.get("history")) ? store.get("history") : []
    readonly property var vars: { const v = store.get("vars"); return v && typeof v === "object" ? v : {} }
    readonly property bool deg: store.get("deg") === true
    readonly property string mode: ["calc", "graph", "table", "stats"].indexOf(store.get("mode")) >= 0 ? store.get("mode") : "calc"
    readonly property var fns: {
        const f = store.get("fns")
        const out = []
        for (let i = 0; i < 6; i++) {
            const x = Array.isArray(f) && f[i] ? f[i] : {}
            out.push({ text: typeof x.text === "string" ? x.text : "", on: x.on !== false, color: root.colours[i] })
        }
        return out
    }
    readonly property var win: { const w = store.get("win"); return w && w.xmax > w.xmin && w.ymax > w.ymin ? w : { xmin: -10, xmax: 10, ymin: -10, ymax: 10 } }
    readonly property var table: { const t = store.get("table"); return t && isFinite(t.start) && t.step > 0 ? t : { start: 0, step: 1 } }
    // the last answer: what ans stands for
    readonly property var ans: root.history.length && typeof root.history[0].num === "number" ? root.history[0].num : null
    readonly property var env: ({ vars: root.vars, ans: root.ans, deg: root.deg })

    // a colour for each function, from the theme
    readonly property var colours: root.theme
        ? [root.theme.accentPrimary, root.theme.accentCyan, root.theme.accentGreen, root.theme.accentOrange, root.theme.accentRed, root.theme.textSecondary]
        : ["#7aa2f7", "#7dcfff", "#9ece6a", "#e0af68", "#f7768e", "#c0caf5"]

    // ---- the line ---------------------------------------------------------------------------
    // one line to type in; what it writes to follows the view: a sum (Calc), the chosen
    // function (Graph), where the table starts and its step (Table), the chosen list (Lists)
    property int sel: 0                 // the function, or the list (0, 1), being written
    property string calcLine: ""        // the sum, kept while another view is open
    property int recall: -1             // ↑ in Calc: which earlier sum is in the line
    property var preview: null          // the answer to the line, as you type
    property string error: ""           // why the last Enter didn't work

    function lineFor(m) {
        if (m === "calc") return root.calcLine
        if (m === "graph") return root.fns[root.sel].text
        if (m === "table") return Engine.format(root.table.start) + ", " + Engine.format(root.table.step)
        return store.get(root.sel === 0 ? "l1" : "l2") || ""
    }
    function setMode(m) {
        if (m === root.mode) return
        if (m === "stats" || m === "graph") root.sel = 0
        root.error = ""
        store.set("mode", m)
    }
    // whatever changes the view (a chip, Tab, the saved state read back), the line follows
    onModeChanged: root.loadLine()
    signal lineLoaded(string text)
    function loadLine() { root.lineLoaded(root.lineFor(root.mode)) }

    // the line changed (typed, or a key put something in): it goes where the view says
    function edited(t) {
        root.error = ""
        if (root.mode === "calc") { root.calcLine = t; root.recall = -1; previewTimer.restart() }
        else if (root.mode === "graph") root.setFn(root.sel, { text: t })
        else if (root.mode === "stats") store.set(root.sel === 0 ? "l1" : "l2", t)
    }
    Timer { id: previewTimer; interval: 60; onTriggered: root.preview = root.calcLine.trim() === "" ? null : Engine.run(root.calcLine, root.env) }
    onEnvChanged: previewTimer.restart()

    function setFn(i, change) {
        const f = root.fns.map(x => ({ text: x.text, on: x.on }))
        Object.assign(f[i], change)
        store.set("fns", f)
    }
    function setWin(w) { store.set("win", { xmin: w.xmin, xmax: w.xmax, ymin: w.ymin, ymax: w.ymax }) }

    // Enter
    function commit(line) {
        root.error = ""
        if (root.mode === "calc") {
            // an empty line works out the last sum again (ans + 1, Enter, Enter, ...)
            const sum = line.trim() !== "" ? line : (root.history.length ? root.history[0].sum : "")
            if (sum.trim() === "") return
            const r = Engine.run(sum, root.env)
            if (r.error) { root.error = r.error; return }
            const entry = { sum: sum, value: r.text, num: r.value, exact: r.exact || "" }
            store.set("history", [entry].concat(root.history).slice(0, 60))
            if (r.store) { const v = Object.assign({}, root.vars); v[r.store] = r.value; store.set("vars", v) }
            root.calcLine = ""
            root.recall = -1
            root.preview = null
            root.lineLoaded("")
        } else if (root.mode === "graph") {
            // the next function, as Y= does
            if (line.trim() !== "") { try { Engine.compile(line, root.env) } catch (e) { root.error = e.message; return } }
            root.sel = (root.sel + 1) % 6
            root.loadLine()
        } else if (root.mode === "table") {
            try {
                const v = Engine.parseList(line, root.env)
                if (v.length < 1 || v.length > 2) throw new Error("Write where it starts, and the step: 0, 1")
                const step = v.length === 2 ? v[1] : root.table.step
                if (!(step > 0)) throw new Error("The step has to be above zero")
                store.set("table", { start: v[0], step: step })
                root.loadLine()
            } catch (e) { root.error = e.message }
        } else {
            try { Engine.parseList(line, root.env); root.sel = 1 - root.sel; root.loadLine() } catch (e) { root.error = e.message }
        }
    }

    // ↑ ↓
    function step(d) {
        if (root.mode === "calc") {
            const n = root.history.length
            if (!n) return
            const next = Math.max(-1, Math.min(n - 1, root.recall + (d < 0 ? 1 : -1)))
            root.recall = next
            root.lineLoaded(next < 0 ? root.calcLine : root.history[next].sum)
        } else if (root.mode === "graph") {
            root.sel = (root.sel + (d < 0 ? 5 : 1)) % 6
            root.loadLine()
        } else if (root.mode === "table") {
            store.set("table", { start: root.table.start + (d < 0 ? -1 : 1) * root.table.step, step: root.table.step })
            root.loadLine()
        } else {
            root.sel = 1 - root.sel
            root.loadLine()
        }
    }

    // the answer to copy: the one shown, or the last one
    function copyAnswer() {
        const p = root.preview
        const v = p && !p.error ? p.value : root.ans
        if (v === null || v === undefined) return
        const s = String(parseFloat(Number(v).toPrecision(15)))
        KitHost.copy(s)
        panel.status = "Copied " + s
    }
    // a number as it goes back into a sum, in full
    function literal(v) {
        const s = String(v)
        const t = s.indexOf("e") >= 0 ? s.replace("e", "×10^(") + ")" : s
        return v < 0 || s.indexOf("e") >= 0 ? "(" + t + ")" : t
    }

    // ---- the functions, for the table ---------------------------------------------------
    readonly property var compiled: {
        const out = []
        for (let i = 0; i < 6; i++) {
            const f = root.fns[i]
            if (!f.on || f.text.trim() === "") continue
            try { out.push({ i: i, f: Engine.compile(f.text, root.env), color: f.color }) } catch (e) { }
        }
        return out
    }

    // ---- the lists ------------------------------------------------------------------------
    function listOf(key) { try { return { v: Engine.parseList(store.get(key) || "", root.env) } } catch (e) { return { v: [], error: e.message } } }
    readonly property var l1: root.listOf("l1")
    readonly property var l2: root.listOf("l2")
    readonly property var s1: Engine.stats(root.l1.v)
    readonly property var fit: root.l1.v.length === root.l2.v.length ? Engine.regress(root.l1.v, root.l2.v) : null
    readonly property var points: store.get("plot") && root.l1.v.length && root.l1.v.length === root.l2.v.length
        ? root.l1.v.map((x, i) => [x, root.l2.v[i]]) : []
    // a fit goes to the first empty function, and the graph shows it
    function graphFit(text) {
        let i = root.fns.findIndex(f => f.text.trim() === "")
        if (i < 0) i = 5
        root.setFn(i, { text: text, on: true })
        store.set("mode", "graph")
        root.sel = i
        root.loadLine()
    }

    readonly property var modes: [{ key: "calc", label: "Calc" }, { key: "graph", label: "Graph" },
                                  { key: "table", label: "Table" }, { key: "stats", label: "Lists" }]
    readonly property var hintsFor: ({
        calc: [["Enter", "work it out"], ["↑ ↓", "earlier sums"], ["Tab", "next view"], ["Ctrl + C", "copy"], ["Esc", "clear, close"]],
        graph: [["Enter", "next function"], ["↑ ↓", "choose one"], ["drag, wheel", "move, zoom"], ["Tab", "next view"], ["Esc", "close"]],
        table: [["Enter", "start, step"], ["↑ ↓", "move along"], ["Tab", "next view"], ["Esc", "close"]],
        stats: [["Enter", "next list"], ["↑ ↓", "choose one"], ["Tab", "next view"], ["Esc", "close"]]
    })

    KitPanel {
        id: panel
        theme: root.theme
        name: "calculator"
        icon: "\u{F00EC}"
        input: false
        panelWidth: 1220
        panelHeight: 760
        chips: root.modes
        chip: root.mode
        onChipChosen: key => root.setMode(key)
        hints: root.hintsFor[root.mode]
        onOpenChanged: if (open) { status = ""; root.error = "" }
        body: Component {
            Item {
                id: bodyRoot
                readonly property var kp: panel
                // ---- keys ------------------------------------------------------------------
                function key(event) {
                    const ctrl = event.modifiers & Qt.ControlModifier
                    if (event.key === Qt.Key_Escape) {
                        if (root.mode === "calc" && entry.text !== "") { entry.text = ""; root.edited("") }
                        else panel.open = false
                        event.accepted = true
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.commit(entry.text); event.accepted = true
                    } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                        panel.stepChip(event.key === Qt.Key_Tab ? 1 : -1); event.accepted = true
                    } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
                        root.step(event.key === Qt.Key_Up ? -1 : 1); event.accepted = true
                    } else if (ctrl && event.key === Qt.Key_C && entry.selectedText === "") {
                        root.copyAnswer(); event.accepted = true
                    }
                }
                // a key of the keypad, or text from a click: in at the cursor (over a selection)
                function put(text, back) {
                    let t = text
                    // as on a TI-84: an operator first in an empty line works on the last answer
                    if (root.mode === "calc" && entry.text === "" && root.ans !== null && /^[+×÷*/^²³!%⁻]/.test(t.trim())) t = "ans" + t
                    const a = entry.selectionStart, b = entry.selectionEnd, s = entry.text
                    entry.text = s.slice(0, a) + t + s.slice(b)
                    entry.cursorPosition = a + t.length - (back || 0)
                    root.edited(entry.text)
                    entry.forceActiveFocus()
                }
                function act(a) {
                    const c = entry.cursorPosition
                    if (a === "left") entry.cursorPosition = Math.max(0, c - 1)
                    else if (a === "right") entry.cursorPosition = Math.min(entry.text.length, c + 1)
                    else if (a === "home") entry.cursorPosition = 0
                    else if (a === "end") entry.cursorPosition = entry.text.length
                    else if (a === "del") {
                        const s = entry.text, x = entry.selectionStart, y = entry.selectionEnd
                        if (x !== y) { entry.text = s.slice(0, x) + s.slice(y); entry.cursorPosition = x }
                        else if (c > 0) { entry.text = s.slice(0, c - 1) + s.slice(c); entry.cursorPosition = c - 1 }
                        root.edited(entry.text)
                    } else if (a === "clear") { entry.text = ""; root.edited("") }
                    else if (a === "angle") store.set("deg", !root.deg)
                    else if (a === "enter") root.commit(entry.text)
                    else if (a === "copy") root.copyAnswer()
                    else if (a === "vars") {
                        const names = Object.keys(root.vars).sort()
                        panel.status = names.length ? names.map(n => n + " = " + Engine.format(root.vars[n])).join("    ")
                                                    : "No letters stored yet: 5 → a stores 5 in a"
                    }
                    entry.forceActiveFocus()
                }
                Connections {
                    target: root
                    function onLineLoaded(text) { entry.text = text; entry.cursorPosition = text.length; Qt.callLater(bodyRoot.refocus) }
                }
                Component.onCompleted: { root.loadLine(); entry.forceActiveFocus() }
                // the typing always goes to the line: the panel itself gives the focus to its
                // own (hidden) search line when its chips or title are clicked
                function refocus() { if (panel.open && !entry.activeFocus) entry.forceActiveFocus() }
                // a click anywhere else keeps the typing in the line
                MouseArea { anchors.fill: parent; onPressed: mouse => { entry.forceActiveFocus(); mouse.accepted = false } }

                RowLayout {
                    anchors.fill: parent
                    spacing: 14

                    // ---- the screen, the line and the answer -----------------------------------
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 10

                        Rectangle {
                            id: screen
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 12
                            color: panel.c_surface
                            border.width: 1
                            border.color: panel.c_border
                            clip: true

                            // Calc: every sum so far, the newest at the bottom
                            Item {
                                anchors.fill: parent
                                anchors.margins: 12
                                visible: root.mode === "calc"
                                ListView {
                                    id: tape
                                    anchors.fill: parent
                                    anchors.bottomMargin: varsRow.visible ? varsRow.height + 8 : 0
                                    clip: true
                                    spacing: 4
                                    verticalLayoutDirection: ListView.BottomToTop
                                    boundsBehavior: Flickable.StopAtBounds
                                    model: root.history
                                    delegate: Rectangle {
                                        id: rowItem
                                        required property var modelData
                                        required property int index
                                        readonly property bool recalled: root.recall === index
                                        width: ListView.view.width
                                        height: rowCol.implicitHeight + 12
                                        radius: 8
                                        color: recalled ? panel.c_selected : rowArea.containsMouse ? panel.c_hover : "transparent"
                                        ColumnLayout {
                                            id: rowCol
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            spacing: 2
                                            Text {
                                                Layout.fillWidth: true
                                                text: rowItem.modelData.sum
                                                textFormat: Text.PlainText
                                                color: panel.c_muted
                                                font.family: panel.font
                                                font.pixelSize: 13
                                                elide: Text.ElideRight
                                            }
                                            RowLayout {
                                                Layout.fillWidth: true
                                                Text {
                                                    visible: !!rowItem.modelData.exact
                                                    text: rowItem.modelData.exact ? "= " + rowItem.modelData.exact : ""
                                                    textFormat: Text.PlainText
                                                    color: panel.c_accent
                                                    font.family: panel.font
                                                    font.pixelSize: 13
                                                }
                                                Item { Layout.fillWidth: true }
                                                Text {
                                                    Layout.maximumWidth: rowCol.width * 0.85
                                                    text: rowItem.modelData.value
                                                    textFormat: Text.PlainText
                                                    horizontalAlignment: Text.AlignRight
                                                    color: panel.c_text
                                                    font.family: panel.font
                                                    font.pixelSize: 19
                                                    font.bold: true
                                                    elide: Text.ElideLeft
                                                }
                                            }
                                        }
                                        // a click puts the answer in the line; Shift + click, the sum
                                        MouseArea {
                                            id: rowArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: mouse => {
                                                if (mouse.modifiers & Qt.ShiftModifier) bodyRoot.put(rowItem.modelData.sum, 0)
                                                else if (typeof rowItem.modelData.num === "number") bodyRoot.put(root.literal(rowItem.modelData.num), 0)
                                            }
                                        }
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        visible: root.history.length === 0
                                        width: parent.width * 0.8
                                        horizontalAlignment: Text.AlignHCenter
                                        wrapMode: Text.WordWrap
                                        text: "Type a sum, or use the keys.\n\n12 × (3 + 4)     x² − 5x + 6 = 0     sin(30) in DEG\n"
                                              + "integral(x², x, 0, 3)     deriv(sin(x), x, 0)     5 → a, then 2a"
                                        textFormat: Text.PlainText
                                        color: panel.c_muted
                                        font.family: panel.font
                                        font.pixelSize: 12
                                        lineHeight: 1.3
                                    }
                                }
                                // the letters stored: a click puts the letter in the line
                                Flow {
                                    id: varsRow
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    visible: Object.keys(root.vars).length > 0
                                    spacing: 6
                                    Repeater {
                                        model: Object.keys(root.vars).sort()
                                        delegate: Rectangle {
                                            required property string modelData
                                            width: varText.implicitWidth + 16
                                            height: 24
                                            radius: 7
                                            color: varArea.containsMouse ? panel.c_hover : panel.c_bg
                                            border.width: 1
                                            border.color: panel.c_border
                                            Text {
                                                id: varText
                                                anchors.centerIn: parent
                                                text: parent.modelData + " = " + Engine.format(root.vars[parent.modelData])
                                                textFormat: Text.PlainText
                                                color: panel.c_text2
                                                font.family: panel.font
                                                font.pixelSize: 11
                                            }
                                            MouseArea { id: varArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: bodyRoot.put(parent.modelData, 0) }
                                        }
                                    }
                                }
                            }

                            // Graph: the functions on the left, the graph beside them
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                visible: root.mode === "graph"
                                spacing: 10
                                ColumnLayout {
                                    Layout.preferredWidth: 214
                                    Layout.maximumWidth: 214
                                    Layout.fillWidth: false
                                    Layout.fillHeight: true
                                    spacing: 4
                                    Repeater {
                                        model: 6
                                        delegate: Rectangle {
                                            id: fnRow
                                            required property int index
                                            readonly property var fn: root.fns[index]
                                            readonly property bool chosen: root.sel === index
                                            Layout.fillWidth: true
                                            implicitHeight: 34
                                            radius: 8
                                            color: chosen ? panel.c_selected : fnArea.containsMouse ? panel.c_hover : "transparent"
                                            border.width: chosen ? 1 : 0
                                            border.color: panel.c_accent
                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 8
                                                anchors.rightMargin: 8
                                                spacing: 8
                                                // its colour, filled when it is drawn: a click turns it on or off
                                                Rectangle {
                                                    implicitWidth: 14
                                                    implicitHeight: 14
                                                    radius: 4
                                                    color: fnRow.fn.on ? fnRow.fn.color : "transparent"
                                                    border.width: 2
                                                    border.color: fnRow.fn.color
                                                    MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: root.setFn(fnRow.index, { on: !fnRow.fn.on }) }
                                                }
                                                Text {
                                                    text: "Y" + (fnRow.index + 1) + " ="
                                                    textFormat: Text.PlainText
                                                    color: panel.c_muted
                                                    font.family: panel.font
                                                    font.pixelSize: 12
                                                }
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: fnRow.fn.text
                                                    textFormat: Text.PlainText
                                                    color: fnRow.fn.on ? panel.c_text : panel.c_muted
                                                    font.family: panel.font
                                                    font.pixelSize: 12
                                                    elide: Text.ElideRight
                                                }
                                            }
                                            MouseArea {
                                                id: fnArea
                                                anchors.fill: parent
                                                anchors.leftMargin: 30
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: { root.sel = fnRow.index; root.loadLine(); entry.forceActiveFocus() }
                                            }
                                        }
                                    }
                                    Item { Layout.fillHeight: true }
                                    // the window: its numbers, and ready-made ones
                                    Text {
                                        Layout.fillWidth: true
                                        text: "x  " + Engine.format(root.win.xmin) + " … " + Engine.format(root.win.xmax)
                                              + "\ny  " + Engine.format(root.win.ymin) + " … " + Engine.format(root.win.ymax)
                                        textFormat: Text.PlainText
                                        color: panel.c_muted
                                        font.family: panel.font
                                        font.pixelSize: 11
                                        lineHeight: 1.3
                                    }
                                    Flow {
                                        Layout.preferredWidth: 214
                                        Layout.maximumWidth: 214
                                        spacing: 6
                                        Repeater {
                                            model: [
                                                { l: "Standard", w: { xmin: -10, xmax: 10, ymin: -10, ymax: 10 } },
                                                { l: "Trig", w: { xmin: -2 * Math.PI, xmax: 2 * Math.PI, ymin: -4, ymax: 4 } },
                                                { l: "Fit y", fit: true },
                                                { l: "Square", square: true },
                                                { l: "Zoom in", k: 0.5 },
                                                { l: "Zoom out", k: 2 }
                                            ]
                                            delegate: Rectangle {
                                                required property var modelData
                                                width: zText.implicitWidth + 16
                                                height: 26
                                                radius: 7
                                                color: zArea.containsMouse ? panel.c_hover : panel.c_bg
                                                border.width: 1
                                                border.color: panel.c_border
                                                Text { id: zText; anchors.centerIn: parent; text: parent.modelData.l; color: panel.c_text2; font.family: panel.font; font.pixelSize: 11 }
                                                MouseArea {
                                                    id: zArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        const m = parent.modelData, w = root.win
                                                        if (m.w) root.setWin(m.w)
                                                        else if (m.fit) { const f = graph.fitted(); if (f) root.setWin(f) }
                                                        else if (m.square) {
                                                            // the same scale both ways, around the middle
                                                            const cy = (w.ymin + w.ymax) / 2, hy = (w.xmax - w.xmin) * graph.height / Math.max(1, graph.width) / 2
                                                            root.setWin({ xmin: w.xmin, xmax: w.xmax, ymin: cy - hy, ymax: cy + hy })
                                                        } else {
                                                            const cx = (w.xmin + w.xmax) / 2, cy2 = (w.ymin + w.ymax) / 2
                                                            const hx = (w.xmax - w.xmin) / 2 * m.k, hy2 = (w.ymax - w.ymin) / 2 * m.k
                                                            root.setWin({ xmin: cx - hx, xmax: cx + hx, ymin: cy2 - hy2, ymax: cy2 + hy2 })
                                                        }
                                                        entry.forceActiveFocus()
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 8
                                    color: panel.c_bg
                                    border.width: 1
                                    border.color: panel.c_border
                                    clip: true
                                    Graph {
                                        id: graph
                                        anchors.fill: parent
                                        anchors.margins: 1
                                        kp: panel
                                        fns: root.fns
                                        win: root.win
                                        env: root.env
                                        points: root.points
                                        selected: root.sel
                                        onMoved: w => root.setWin(w)
                                    }
                                }
                            }

                            // Table: a row per step, a column per function
                            Item {
                                id: tableView
                                anchors.fill: parent
                                anchors.margins: 12
                                visible: root.mode === "table"
                                readonly property int rows: Math.max(1, Math.floor((height - 34) / 28))
                                readonly property real colW: width / (1 + Math.max(1, root.compiled.length))
                                Row {
                                    id: tableHead
                                    Text { width: tableView.colW; text: "x"; color: panel.c_muted; font.family: panel.font; font.pixelSize: 12; font.bold: true }
                                    Repeater {
                                        model: root.compiled.length
                                        delegate: Text {
                                            required property int index
                                            width: tableView.colW
                                            text: "Y" + (root.compiled[index].i + 1)
                                            color: root.compiled[index].color
                                            font.family: panel.font
                                            font.pixelSize: 12
                                            font.bold: true
                                        }
                                    }
                                }
                                Rectangle { y: 24; width: parent.width; height: 1; color: panel.c_border }
                                Column {
                                    y: 32
                                    Repeater {
                                        model: tableView.rows
                                        delegate: Row {
                                            id: tableRow
                                            required property int index
                                            readonly property real at: root.table.start + index * root.table.step
                                            height: 28
                                            Text { width: tableView.colW; height: 28; verticalAlignment: Text.AlignVCenter; text: Engine.format(tableRow.at); color: panel.c_text2; font.family: panel.font; font.pixelSize: 13 }
                                            Repeater {
                                                model: root.compiled.length
                                                delegate: Text {
                                                    required property int index
                                                    width: tableView.colW
                                                    height: 28
                                                    verticalAlignment: Text.AlignVCenter
                                                    readonly property var c: root.compiled[index]
                                                    text: c ? Engine.format(c.f(tableRow.at)) : ""
                                                    textFormat: Text.PlainText
                                                    color: panel.c_text
                                                    font.family: panel.font
                                                    font.pixelSize: 13
                                                    elide: Text.ElideRight
                                                }
                                            }
                                        }
                                    }
                                }
                                Text {
                                    anchors.centerIn: parent
                                    visible: root.compiled.length === 0
                                    text: "Write a function in Graph first (Tab)"
                                    color: panel.c_muted
                                    font.family: panel.font
                                    font.pixelSize: 12
                                }
                                // the wheel moves along, a step at a time
                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.NoButton
                                    onWheel: wheel => { const d = wheel.angleDelta.y; if (d !== 0) root.step(d > 0 ? -1 : 1) }
                                }
                            }

                            // Lists: the two lists, what one says, and what fits both
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                visible: root.mode === "stats"
                                spacing: 16
                                ColumnLayout {
                                    Layout.preferredWidth: 260
                                    Layout.maximumWidth: 260
                                    Layout.fillWidth: false
                                    Layout.fillHeight: true
                                    spacing: 8
                                    Repeater {
                                        model: [{ key: "l1", name: "L1  (x)", list: root.l1 }, { key: "l2", name: "L2  (y)", list: root.l2 }]
                                        delegate: Rectangle {
                                            id: listBox
                                            required property var modelData
                                            required property int index
                                            readonly property bool chosen: root.sel === index
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            radius: 8
                                            color: chosen ? panel.c_selected : panel.c_bg
                                            border.width: 1
                                            border.color: chosen ? panel.c_accent : panel.c_border
                                            Column {
                                                anchors.fill: parent
                                                anchors.margins: 10
                                                spacing: 6
                                                Text {
                                                    text: listBox.modelData.name + "   " + listBox.modelData.list.v.length + " numbers"
                                                    color: listBox.chosen ? panel.c_accent : panel.c_muted
                                                    font.family: panel.font
                                                    font.pixelSize: 11
                                                    font.bold: true
                                                }
                                                Text {
                                                    width: parent.width
                                                    text: listBox.modelData.list.error ? listBox.modelData.list.error
                                                        : listBox.modelData.list.v.length ? listBox.modelData.list.v.map(Engine.format).join(",  ") : "Empty: type numbers, like 1, 2, 3"
                                                    textFormat: Text.PlainText
                                                    color: listBox.modelData.list.error ? (root.theme ? root.theme.accentRed : "#f7768e") : panel.c_text
                                                    font.family: panel.font
                                                    font.pixelSize: 12
                                                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                                    maximumLineCount: 8
                                                    elide: Text.ElideRight
                                                }
                                            }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.sel = listBox.index; root.loadLine(); entry.forceActiveFocus() } }
                                        }
                                    }
                                }
                                Flickable {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    contentHeight: statsCol.implicitHeight
                                    clip: true
                                    boundsBehavior: Flickable.StopAtBounds
                                    ColumnLayout {
                                        id: statsCol
                                        width: parent.width
                                        spacing: 6
                                        Text { text: "One list (L1)"; color: panel.c_accent; font.family: panel.font; font.pixelSize: 12; font.bold: true }
                                        GridLayout {
                                            visible: !!root.s1
                                            columns: 4
                                            columnSpacing: 18
                                            rowSpacing: 4
                                            Repeater {
                                                model: root.s1 ? [["n", root.s1.n], ["x̄  mean", root.s1.mean], ["Σx", root.s1.sum], ["Σx²", root.s1.sum2],
                                                                  ["Sx", root.s1.sx], ["σx", root.s1.sigma], ["min", root.s1.min], ["Q1", root.s1.q1],
                                                                  ["median", root.s1.median], ["Q3", root.s1.q3], ["max", root.s1.max], ["range", root.s1.max - root.s1.min]] : []
                                                delegate: Column {
                                                    required property var modelData
                                                    Text { text: parent.modelData[0]; color: panel.c_muted; font.family: panel.font; font.pixelSize: 10 }
                                                    Text { text: Engine.format(parent.modelData[1]); color: panel.c_text; font.family: panel.font; font.pixelSize: 14 }
                                                }
                                            }
                                        }
                                        Text { visible: !root.s1; text: "Numbers in L1 show their statistics here."; color: panel.c_muted; font.family: panel.font; font.pixelSize: 12 }
                                        Item { implicitHeight: 6 }
                                        Text { text: "What fits L1 and L2"; color: panel.c_accent; font.family: panel.font; font.pixelSize: 12; font.bold: true }
                                        Text {
                                            visible: !root.fit
                                            Layout.fillWidth: true
                                            text: root.l2.v.length && root.l1.v.length !== root.l2.v.length
                                                  ? "L1 and L2 need as many numbers each (" + root.l1.v.length + " and " + root.l2.v.length + ")"
                                                  : "Two lists of the same length show the line and the parabola through them."
                                            wrapMode: Text.WordWrap
                                            color: panel.c_muted
                                            font.family: panel.font
                                            font.pixelSize: 12
                                        }
                                        Repeater {
                                            model: root.fit ? [
                                                { t: "Line   y = ax + b", v: "a = " + Engine.format(root.fit.a) + "    b = " + Engine.format(root.fit.b)
                                                      + "\nr = " + Engine.format(root.fit.r) + "    r² = " + Engine.format(root.fit.r2),
                                                  g: Engine.plain(root.fit.a) + "x + " + Engine.plain(root.fit.b) },
                                                root.fit.quad ? { t: "Parabola   y = ax² + bx + c", v: "a = " + Engine.format(root.fit.quad.a) + "    b = " + Engine.format(root.fit.quad.b)
                                                      + "    c = " + Engine.format(root.fit.quad.c) + "\nR² = " + Engine.format(root.fit.quad.r2),
                                                  g: Engine.plain(root.fit.quad.a) + "x² + " + Engine.plain(root.fit.quad.b) + "x + " + Engine.plain(root.fit.quad.c) } : null
                                            ].filter(x => x) : []
                                            delegate: Rectangle {
                                                required property var modelData
                                                Layout.fillWidth: true
                                                implicitHeight: fitCol.implicitHeight + 16
                                                radius: 8
                                                color: panel.c_bg
                                                border.width: 1
                                                border.color: panel.c_border
                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.margins: 8
                                                    ColumnLayout {
                                                        id: fitCol
                                                        Layout.fillWidth: true
                                                        spacing: 2
                                                        Text { text: modelData.t; color: panel.c_text2; font.family: panel.font; font.pixelSize: 11; font.bold: true }
                                                        Text { text: modelData.v; color: panel.c_text; font.family: panel.font; font.pixelSize: 13; lineHeight: 1.2 }
                                                    }
                                                    Rectangle {
                                                        implicitWidth: gText.implicitWidth + 16
                                                        implicitHeight: 26
                                                        radius: 7
                                                        color: gArea.containsMouse ? panel.c_hover : panel.c_surface
                                                        border.width: 1
                                                        border.color: panel.c_accent
                                                        Text { id: gText; anchors.centerIn: parent; text: "Graph it"; color: panel.c_accent; font.family: panel.font; font.pixelSize: 11 }
                                                        MouseArea { id: gArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.graphFit(modelData.g) }
                                                    }
                                                }
                                            }
                                        }
                                        // the points on the graph, or not
                                        Rectangle {
                                            Layout.topMargin: 4
                                            implicitWidth: pText.implicitWidth + 16
                                            implicitHeight: 26
                                            radius: 7
                                            readonly property bool on: store.get("plot") === true
                                            color: on ? panel.c_selected : pArea.containsMouse ? panel.c_hover : panel.c_bg
                                            border.width: 1
                                            border.color: on ? panel.c_accent : panel.c_border
                                            Text { id: pText; anchors.centerIn: parent; text: (parent.on ? "✓ " : "") + "The points on the graph"; color: parent.on ? panel.c_accent : panel.c_text2; font.family: panel.font; font.pixelSize: 11 }
                                            MouseArea { id: pArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: store.set("plot", !parent.on) }
                                        }
                                    }
                                }
                            }
                        }

                        // the line
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 50
                            radius: 10
                            color: panel.c_surface
                            border.width: 1
                            border.color: root.error !== "" ? (root.theme ? root.theme.accentRed : "#f7768e") : entry.activeFocus ? panel.c_accent : panel.c_border
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                spacing: 10
                                Text {
                                    text: root.mode === "graph" ? "Y" + (root.sel + 1) + " =" : root.mode === "table" ? "start, step" : root.mode === "stats" ? (root.sel === 0 ? "L1" : "L2") : "›"
                                    color: root.mode === "graph" ? root.fns[root.sel].color : panel.c_accent
                                    font.family: panel.font
                                    font.pixelSize: 15
                                    font.bold: true
                                }
                                TextInput {
                                    id: entry
                                    Layout.fillWidth: true
                                    color: panel.c_text
                                    selectionColor: panel.tint(panel.c_accent, 0.4)
                                    selectByMouse: true
                                    font.family: panel.font
                                    font.pixelSize: 18
                                    clip: true
                                    focus: true
                                    onTextEdited: {
                                        // as on a TI-84: an operator typed first works on the last answer
                                        if (root.mode === "calc" && root.calcLine === "" && root.ans !== null && /^[+*/^%!×÷²³]$/.test(text)) {
                                            text = "ans" + text
                                            cursorPosition = text.length
                                        }
                                        root.edited(text)
                                    }
                                    onActiveFocusChanged: if (!activeFocus) Qt.callLater(bodyRoot.refocus)
                                    Keys.onPressed: event => bodyRoot.key(event)
                                    Accessible.role: Accessible.EditableText
                                    Accessible.name: "Calculator line"
                                    Text {
                                        anchors.fill: parent
                                        verticalAlignment: Text.AlignVCenter
                                        visible: entry.text === ""
                                        text: root.mode === "graph" ? "a function of x, like x² − 2x or sin(x)/x"
                                            : root.mode === "table" ? "where the table starts, and its step: 0, 0.5"
                                            : root.mode === "stats" ? "numbers, like 1, 2, 3.5, 4"
                                            : root.history.length ? "a sum, or Enter to work out the last one again" : "a sum, like 12 × (3 + 4)"
                                        textFormat: Text.PlainText
                                        color: panel.c_muted
                                        font.family: panel.font
                                        font.pixelSize: 14
                                    }
                                }
                                Text {
                                    text: root.deg ? "DEG" : "RAD"
                                    color: panel.c_muted
                                    font.family: panel.font
                                    font.pixelSize: 10
                                }
                            }
                        }

                        // the answer, as you type: the number, and what else it is
                        RowLayout {
                            Layout.fillWidth: true
                            implicitHeight: 34
                            spacing: 14
                            readonly property var p: root.mode === "calc" ? root.preview : null
                            readonly property var b: p && !p.error ? Engine.bases(p.value) : null
                            Text {
                                Layout.fillWidth: true
                                text: root.error !== "" ? root.error
                                    : parent.p ? (parent.p.error ? parent.p.error : (parent.p.solvedFor ? parent.p.text : "= " + parent.p.text)) : ""
                                textFormat: Text.PlainText
                                color: root.error !== "" ? (root.theme ? root.theme.accentRed : "#f7768e")
                                     : parent.p && !parent.p.error ? panel.c_text : panel.c_muted
                                font.family: panel.font
                                font.pixelSize: parent.p && !parent.p.error && root.error === "" ? 22 : 13
                                font.bold: !!parent.p && !parent.p.error && root.error === ""
                                elide: Text.ElideRight
                            }
                            Text {
                                visible: !!parent.p && !parent.p.error && !!parent.p.exact && root.error === ""
                                text: parent.p && parent.p.exact ? "= " + parent.p.exact : ""
                                textFormat: Text.PlainText
                                color: panel.c_accent
                                font.family: panel.font
                                font.pixelSize: 15
                            }
                            Text {
                                visible: !!parent.b && root.error === "" && Math.abs(parent.p.value) >= 2
                                text: parent.b ? parent.b.hex + "   " + parent.b.bin : ""
                                textFormat: Text.PlainText
                                color: panel.c_muted
                                font.family: panel.font
                                font.pixelSize: 11
                                elide: Text.ElideLeft
                                Layout.maximumWidth: 260
                            }
                        }
                    }

                    // ---- the keys ---------------------------------------------------------------
                    Keypad {
                        Layout.preferredWidth: 350
                        Layout.fillHeight: true
                        kp: panel
                        deg: root.deg
                        onTyped: (text, back) => bodyRoot.put(text, back)
                        onActed: a => bodyRoot.act(a)
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "calculator"
        function toggle(): void { panel.status = ""; panel.toggle() }
        function calc(sum: string): string {
            const r = Engine.run(sum, root.env)
            return r.error ? "not a sum: " + r.error : r.text
        }
    }
    Component.onCompleted: KitHost.register("calculator", root)
    Component.onDestruction: KitHost.unregister("calculator", root)
}
