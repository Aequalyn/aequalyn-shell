// Bar: the bar's shape and look, and the bar and docks dressed together.
//
//   Together   ensembles: the bar and every dock in one click
//   Shape      a band, a pill, isles or a pebble per widget
//   Looks      Aequalyn's catalogue, in five families
//   then placement, widgets, colors and every single part
//
// Docks set to "Same as the bar" change with it; the stage at the top always
// shows the two side by side.
import QtQuick
import QtQuick.Layouts
import "controls"
import  "../../style/BarLooks.js" as BarLooks
import  "../../style/AequalynLooks.js" as Looks
import  "../../style/Colors.js" as Colors
import "root:/settings"

Flickable {
    id: pane
    property var theme
    property string font: "JetBrainsMono Nerd Font"

    // The control center shows this pane in tabs: `section` picks the part to show
    // ("" shows all of it), and `showStage` hides the picture on top when the page
    // pins its own.
    property string section: ""
    property bool showStage: true
    function shows(s) { return section === "" || section === s; }

    readonly property var raw: AequalynSettings.barStyleCfg
    readonly property var look: BarLooks.clean(raw)
    readonly property string lookKey: BarLooks.lookOf(look)
    readonly property var pal: Colors.forMode(theme, look.colorMode, look)
    readonly property var svc: AtelierHost.docks
    readonly property var dockList: svc ? svc.docks : []
    readonly property int following: dockList.filter(d => d.followBar).length
    readonly property string ensembleKey: svc ? svc.ensembleOf() : ""
    property string family: "all"

    function set(key, value) { AequalynSettings.setIn("barStyle", key, value); }
    function setMany(changes) { AequalynSettings.setBarStyle(Object.assign({}, raw, changes)); }
    function useLook(key) {
        AequalynSettings.setBarStyle(Object.assign(BarLooks.withLook(look, key), { enabled: true, chips: raw.chips }));
    }
    function nextLook() {
        AequalynSettings.setBarStyle(Object.assign(BarLooks.withNextLook(look, 1), { enabled: true, chips: raw.chips }));
    }
    function undoLook() {
        AequalynSettings.setBarStyle(Object.assign(BarLooks.withUndo(look), { chips: raw.chips }));
    }
    function saveSlot(i) { AequalynSettings.setBarStyle(BarLooks.withSlot(look, "save", i)); }
    function loadSlot(i) { AequalynSettings.setBarStyle(BarLooks.withSlot(look, "load", i)); }
    function clearSlot(i) { AequalynSettings.setBarStyle(BarLooks.withSlot(look, "clear", i)); }
    function useEnsemble(key) {
        if (svc) { svc.applyEnsemble(key); return; }
        const e = Looks.byKey(Looks.ensembles, key);
        if (e) useLook(e.bar);
    }

    // the docks as the stage draws them
    readonly property var stageDocks: dockList.map((d, i) => {
        const e = svc.effective(i);
        return { look: e, pal: svc.palette(e), edge: d.edge, icons: Math.max(3, Math.min(6, d.apps.length)) };
    })
    // a dock dressed by an ensemble, for its card
    function ensembleDock(e, barLook) {
        const base = { opacity: 90, radius: 16, style: "theme" };
        const st = e.dock === "follow" ? BarLooks.styleOf(barLook) : Object.assign(base, Looks.dockSet(e.dock));
        return { look: st, pal: Colors.forMode(theme, barLook.colorMode, barLook), edge: "bottom", icons: 5 };
    }

    contentHeight: column.implicitHeight + 24
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    ColumnLayout {
        id: column
        width: pane.width
        spacing: 12

        Stage {
            visible: pane.showStage
            Layout.fillWidth: true
            Layout.preferredHeight: 170
            theme: pane.theme; font: pane.font
            barLook: pane.look
            docks: pane.stageDocks
            caption: (pane.lookKey !== "" ? BarLooks.lookByKey[pane.lookKey].label : "Your own look")
                + (pane.ensembleKey !== "" ? "  ·  " + Looks.byKey(Looks.ensembles, pane.ensembleKey).label + " ensemble" : "")
                + (pane.dockList.length > 0 ? "  ·  " + pane.following + " of " + pane.dockList.length + " docks follow the bar" : "")
        }

        // ---- together -------------------------------------------------------------
        Group {
            visible: pane.shows("looks")
            theme: pane.theme; font: pane.font
            icon: "󰕮"
            title: "Bar and docks together"
            sub: "An ensemble dresses the bar and every dock at once. Fine tune either afterwards; your colors stay yours."
            GridLayout {
                Layout.fillWidth: true
                columns: Math.max(2, Math.floor(pane.width / 260))
                columnSpacing: 8
                rowSpacing: 8
                Repeater {
                    model: Looks.ensembles
                    delegate: LookCard {
                        id: ens
                        required property var modelData
                        readonly property var barLook: BarLooks.applyLook(Object.assign({}, pane.look, { enabled: true }), modelData.bar)
                        Layout.fillWidth: true
                        theme: pane.theme; font: pane.font
                        previewHeight: 78
                        title: modelData.label
                        subtitle: modelData.about
                        badge: pane.ensembleKey === modelData.key ? "WEARING" : (modelData.dock === "follow" ? "ONE LOOK" : "PAIRED")
                        selected: pane.ensembleKey === modelData.key
                        onClicked: pane.useEnsemble(modelData.key)
                        Stage {
                            anchors.fill: parent
                            theme: pane.theme; font: pane.font
                            barLook: ens.barLook
                            barSize: 14
                            dockSize: 12
                            docks: [pane.ensembleDock(ens.modelData, ens.barLook)]
                        }
                    }
                }
            }
        }

        // ---- shape ----------------------------------------------------------------
        Group {
            visible: pane.shows("shape")
            theme: pane.theme; font: pane.font
            icon: "󰍜"
            title: "Shape"
            sub: "Where the bar is painted. Off leaves the plain bar."
            Toggle {
                theme: pane.theme; font: pane.font
                label: "Shaped bar"
                checked: pane.look.enabled
                onToggled: v => pane.set("enabled", v)
            }
            GridLayout {
                Layout.fillWidth: true
                columns: pane.width > 900 ? 4 : 2
                columnSpacing: 8
                rowSpacing: 8
                Repeater {
                    model: [
                        ["full", "󰍜", "Band", "Edge to edge"],
                        ["pill", "󰺕", "Pill", "One floating shape"],
                        ["islands", "󰕰", "Isles", "One per group"],
                        ["widgets", "󰝤", "Pebbles", "One per widget"]
                    ]
                    delegate: Rectangle {
                        id: shapeCard
                        required property var modelData
                        readonly property bool on: pane.look.shape === modelData[0]
                        Layout.fillWidth: true
                        Layout.preferredHeight: 104
                        radius: 12
                        opacity: pane.look.enabled ? 1 : 0.5
                        color: on ? pane.theme.bgSelected : (shapeArea.containsMouse ? pane.theme.bgHover : pane.theme.bgSurface)
                        border.width: on ? 2 : 1
                        border.color: on ? pane.theme.accentPrimary : pane.theme.bgBorder
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Desk {
                            theme: pane.theme
                            x: 6; y: 6
                            width: parent.width - 12; height: 40
                            BarMini {
                                x: 4; y: 4
                                width: parent.width - 8
                                theme: pane.theme
                                look: Object.assign({}, pane.look, { enabled: true, shape: shapeCard.modelData[0] })
                                barSize: 16
                            }
                        }
                        RowLayout {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 10
                            spacing: 10
                            Rectangle {
                                Layout.preferredWidth: 30
                                Layout.preferredHeight: 30
                                radius: 9
                                color: shapeCard.on ? pane.theme.accentPrimary : pane.theme.bgBase
                                Text {
                                    anchors.centerIn: parent
                                    text: shapeCard.modelData[1]
                                    color: shapeCard.on ? pane.theme.bgBase : pane.theme.accentPrimary
                                    font.family: pane.font
                                    font.pixelSize: 12
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text {
                                    Layout.fillWidth: true
                                    text: shapeCard.modelData[2]
                                    color: pane.theme.textPrimary
                                    font.family: "sans-serif"
                                    font.pixelSize: 13
                                    font.bold: true
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: shapeCard.modelData[3]
                                    color: pane.theme.textMuted
                                    font.family: "sans-serif"
                                    font.pixelSize: 11
                                }
                            }
                        }
                        MouseArea {
                            id: shapeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { if (!pane.look.enabled) pane.set("enabled", true); pane.set("shape", shapeCard.modelData[0]); }
                        }
                    }
                }
            }
        }

        // ---- looks ----------------------------------------------------------------
        Group {
            visible: pane.shows("looks")
            theme: pane.theme; font: pane.font
            icon: "󰏘"
            title: "Looks"
            sub: Looks.bar.length + " looks in five families. Picking one replaces the whole look except the colors."
            Flow {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: [{ key: "all", label: "All" }].concat(Looks.families)
                    delegate: Chip {
                        required property var modelData
                        theme: pane.theme; font: pane.font
                        compact: true
                        text: modelData.label
                        selected: pane.family === modelData.key
                        onClicked: pane.family = modelData.key
                    }
                }
            }
            GridLayout {
                Layout.fillWidth: true
                columns: Math.max(2, Math.floor(pane.width / 210))
                columnSpacing: 8
                rowSpacing: 8
                Repeater {
                    model: Looks.inFamily(Looks.bar, pane.family)
                    delegate: LookCard {
                        id: lc
                        required property var modelData
                        Layout.fillWidth: true
                        theme: pane.theme; font: pane.font
                        previewHeight: 40
                        title: modelData.label
                        subtitle: modelData.about
                        badge: Looks.byKey(Looks.families, modelData.family).label.toUpperCase()
                        selected: pane.lookKey === modelData.key
                        onClicked: pane.useLook(modelData.key)
                        Desk {
                            anchors.fill: parent
                            theme: pane.theme
                            BarMini {
                                x: 5; y: 6
                                width: parent.width - 10
                                theme: pane.theme
                                look: BarLooks.applyLook(Object.assign({}, pane.look, { enabled: true }), lc.modelData.key)
                                barSize: 16
                            }
                        }
                    }
                }
            }
        }

        // ---- fine tuning ------------------------------------------------------------
        GridLayout {
            visible: (pane.shows("place") || pane.shows("shape"))
            Layout.fillWidth: true
            columns: pane.section === "" && pane.width > 900 ? 2 : 1
            columnSpacing: 12
            rowSpacing: 12

            Group {
                visible: pane.shows("place")
                Layout.alignment: Qt.AlignTop
                theme: pane.theme; font: pane.font
                icon: "󰘞"
                title: "Placement"
                sub: "How far it floats and how it meets the edge"
                Stepper {
                    theme: pane.theme; font: pane.font
                    label: "Float"
                    value: pane.look.floatGap
                    from: 0; to: 40; step: 2
                    suffix: " px"
                    onStepped: v => pane.set("floatGap", v)
                }
                Stepper {
                    theme: pane.theme; font: pane.font
                    label: "Padding"
                    value: pane.look.padding
                    from: 0; to: 24
                    suffix: " px"
                    onStepped: v => pane.set("padding", v)
                }
                Stepper {
                    theme: pane.theme; font: pane.font
                    label: "Corners"
                    value: pane.look.radius
                    from: 0; to: 24
                    suffix: " px"
                    onStepped: v => pane.set("radius", v)
                }
                Stepper {
                    visible: pane.look.shape !== "full"
                    theme: pane.theme; font: pane.font
                    label: "Edge gap"
                    value: pane.look.edgeGap
                    from: 0; to: 24
                    suffix: " px"
                    onStepped: v => pane.set("edgeGap", v)
                }
                Stepper {
                    visible: pane.look.shape !== "full"
                    theme: pane.theme; font: pane.font
                    label: "Side gap"
                    value: pane.look.sideGap
                    from: 0; to: 80; step: 2
                    suffix: " px"
                    onStepped: v => pane.set("sideGap", v)
                }
                Stepper {
                    visible: pane.look.shape === "full"
                    theme: pane.theme; font: pane.font
                    label: "Thicker"
                    value: pane.look.fullExtra
                    from: 0; to: 16
                    suffix: " px"
                    onStepped: v => pane.set("fullExtra", v)
                }
                Stepper {
                    visible: pane.look.shape === "islands"
                    theme: pane.theme; font: pane.font
                    label: "Merge"
                    value: pane.look.mergeGap
                    from: 0; to: 60; step: 2
                    suffix: " px"
                    onStepped: v => pane.set("mergeGap", v)
                }
                Stepper {
                    visible: pane.look.shape === "islands"
                    theme: pane.theme; font: pane.font
                    label: "Middle"
                    value: pane.look.centerMin
                    from: 0; to: 600; step: 20
                    suffix: " px"
                    onStepped: v => pane.set("centerMin", v)
                }
                Stepper {
                    visible: pane.look.shape === "widgets"
                    theme: pane.theme; font: pane.font
                    label: "Spacing"
                    value: pane.look.pillGap
                    from: 0; to: 12
                    suffix: " px"
                    onStepped: v => pane.set("pillGap", v)
                }
                Toggle {
                    visible: pane.look.shape !== "full"
                    theme: pane.theme; font: pane.font
                    label: "Hang from the edge"
                    checked: pane.look.attach
                    onToggled: v => pane.set("attach", v)
                }
                Toggle {
                    visible: pane.look.shape !== "full" && pane.look.attach
                    theme: pane.theme; font: pane.font
                    label: "Curve into the edge"
                    checked: pane.look.concave
                    onToggled: v => pane.set("concave", v)
                }
                Toggle {
                    visible: pane.look.shape === "pill"
                    theme: pane.theme; font: pane.font
                    label: "Only as long as the widgets"
                    checked: pane.look.pillFit
                    onToggled: v => pane.set("pillFit", v)
                }
                Toggle {
                    visible: pane.look.shape === "islands"
                    theme: pane.theme; font: pane.font
                    label: "Sides the same width"
                    checked: pane.look.mirrorSides
                    onToggled: v => pane.set("mirrorSides", v)
                }
                ChoiceRow {
                    visible: pane.look.shape === "islands" || pane.look.shape === "widgets"
                    theme: pane.theme; font: pane.font
                    label: "Painted"
                    options: ["all", "sides", "center"]
                    labels: ({ all: "Everywhere", sides: "Sides", center: "Middle" })
                    value: pane.look.regions
                    onPicked: v => pane.set("regions", v)
                }
                ChoiceRow {
                    theme: pane.theme; font: pane.font
                    label: "Pointing"
                    options: ["right", "left", "both", "outward", "inward"]
                    labels: ({ right: "Right", left: "Left", both: "Both", outward: "Outward", inward: "Inward" })
                    value: pane.look.pointingBar
                    onPicked: v => pane.set("pointingBar", v)
                }
            }

            ColumnLayout {
                visible: pane.shows("shape")
                Layout.alignment: Qt.AlignTop
                Layout.fillWidth: true
                spacing: 12

                Group {
                    visible: pane.shows("shape")
                    theme: pane.theme; font: pane.font
                    icon: "󰳽"
                    title: "Widgets"
                    sub: "Hover marks and what sits between them"
                    ChoiceRow {
                        theme: pane.theme; font: pane.font
                        label: "Hover"
                        options: ["none", "fill", "underline", "glow", "dot"]
                        labels: ({ none: "Nothing", fill: "Fill", underline: "Underline", glow: "Glow", dot: "Dot" })
                        value: pane.look.hover
                        onPicked: v => pane.set("hover", v)
                    }
                    ChoiceRow {
                        theme: pane.theme; font: pane.font
                        label: "In"
                        options: ["text", "accent"]
                        labels: ({ text: "Text color", accent: "Accent" })
                        value: pane.look.hoverColor
                        enabled: pane.look.hover !== "none"
                        onPicked: v => pane.set("hoverColor", v)
                    }
                    ChoiceRow {
                        theme: pane.theme; font: pane.font
                        label: "Between"
                        options: ["none", "line", "dot", "slash"]
                        labels: ({ none: "Nothing", line: "Line", dot: "Dot", slash: "Slash" })
                        value: pane.look.separators
                        onPicked: v => pane.set("separators", v)
                    }
                    Stepper {
                        visible: pane.look.separators !== "none"
                        theme: pane.theme; font: pane.font
                        label: "Strength"
                        value: pane.look.sepOpacity
                        from: 10; to: 100; step: 5
                        suffix: "%"
                        onStepped: v => pane.set("sepOpacity", v)
                    }
                    ChoiceRow {
                        theme: pane.theme; font: pane.font
                        label: "Open"
                        options: ["line", "fill", "dot", "glow", "none"]
                        labels: ({ line: "Line", fill: "Fill", dot: "Dot", glow: "Glow", none: "Nothing" })
                        value: pane.look.openMark
                        onPicked: v => pane.set("openMark", v)
                    }
                    Toggle {
                        theme: pane.theme; font: pane.font
                        label: "Dividers between groups"
                        checked: pane.look.dividers
                        onToggled: v => pane.set("dividers", v)
                    }
                    Toggle {
                        visible: pane.look.shape === "full"
                        theme: pane.theme; font: pane.font
                        label: "Accent line underneath"
                        checked: pane.look.edgeLine
                        onToggled: v => pane.set("edgeLine", v)
                    }
                    Toggle {
                        visible: pane.look.shape !== "widgets"
                        theme: pane.theme; font: pane.font
                        label: "Widget backgrounds"
                        checked: pane.raw.chips !== false
                        onToggled: v => pane.set("chips", v)
                    }
                }

                Group {
                    visible: pane.shows("shape")
                    theme: pane.theme; font: pane.font
                    icon: "󰏘"
                    title: "Colors"
                    sub: "Theme follows your colours"
                    ChoiceRow {
                        theme: pane.theme; font: pane.font
                        label: "From"
                        options: ["theme", "palette", "borders", "custom", "monochrome"]
                        labels: ({ theme: "Theme", palette: "Every shape its own", borders: "Window borders", custom: "Your own", monochrome: "Greys" })
                        value: pane.look.colorMode
                        onPicked: v => pane.set("colorMode", v)
                    }
                    ChoiceRow {
                        theme: pane.theme; font: pane.font
                        label: "Middle"
                        options: ["same", "tinted", "accent"]
                        labels: ({ same: "Same", tinted: "Tinted", accent: "Accent edge" })
                        value: pane.look.centerStyle
                        onPicked: v => pane.set("centerStyle", v)
                    }
                    ChoiceRow {
                        theme: pane.theme; font: pane.font
                        label: "Widget text"
                        options: ["auto", "theme", "custom"]
                        labels: ({ auto: "Always readable", theme: "Theme", custom: "My text color" })
                        value: pane.look.widgetText
                        onPicked: v => pane.set("widgetText", v)
                    }
                    ChoiceRow {
                        visible: pane.look.colorMode === "palette"
                        theme: pane.theme; font: pane.font
                        label: "Palette"
                        options: ["accent", "fill"]
                        labels: ({ accent: "On the outlines", fill: "In the fill" })
                        value: pane.look.paletteUse
                        onPicked: v => pane.set("paletteUse", v)
                    }
                    Toggle {
                        theme: pane.theme; font: pane.font
                        label: "One color per side"
                        checked: pane.look.groupColors
                        onToggled: v => pane.set("groupColors", v)
                    }
                    ColorField {
                        visible: pane.look.groupColors
                        theme: pane.theme; font: pane.font
                        label: "Left"
                        value: pane.look.leftColor
                        onPicked: v => pane.set("leftColor", v)
                    }
                    ColorField {
                        visible: pane.look.groupColors
                        theme: pane.theme; font: pane.font
                        label: "Middle"
                        value: pane.look.centerColor
                        onPicked: v => pane.set("centerColor", v)
                    }
                    ColorField {
                        visible: pane.look.groupColors
                        theme: pane.theme; font: pane.font
                        label: "Right"
                        value: pane.look.rightColor
                        onPicked: v => pane.set("rightColor", v)
                    }
                    Stepper {
                        theme: pane.theme; font: pane.font
                        label: "Opacity"
                        value: pane.look.opacity
                        from: 10; to: 100; step: 5
                        suffix: "%"
                        onStepped: v => pane.set("opacity", v)
                    }
                    Stepper {
                        theme: pane.theme; font: pane.font
                        label: "Tint"
                        value: pane.look.barTint
                        from: 0; to: 40
                        suffix: "%"
                        onStepped: v => pane.set("barTint", v)
                    }
                    Swatches {
                        visible: pane.look.colorMode === "custom"
                        theme: pane.theme; font: pane.font
                        label: "Background"
                        colors: pane.svc ? pane.svc.swatches.slice(0, 8) : []
                        value: pane.look.customBg
                        onPicked: v => pane.set("customBg", v)
                    }
                    Swatches {
                        visible: pane.look.colorMode === "custom"
                        theme: pane.theme; font: pane.font
                        label: "Text"
                        colors: pane.svc ? pane.svc.swatches.slice(8, 16) : []
                        value: pane.look.customFg
                        onPicked: v => pane.set("customFg", v)
                    }
                    Swatches {
                        visible: pane.look.colorMode === "custom"
                        theme: pane.theme; font: pane.font
                        label: "Accent"
                        colors: pane.svc ? pane.svc.swatches.slice(16) : []
                        value: pane.look.accentColor
                        onPicked: v => pane.set("accentColor", v)
                    }
                }
            }
        }

        Group {
            visible: pane.shows("shape")
            theme: pane.theme; font: pane.font
            icon: "󰙨"
            title: "Every part"
            sub: "Ends, surface, lines and ornaments: the same parts the docks are made of."
            StyleEditor {
                Layout.fillWidth: true
                theme: pane.theme; font: pane.font
                look: pane.look
                pal: pane.pal
                edge: "top"
                onChanged: changes => pane.setMany(changes)
            }
        }

        // ---- the fine edges of a look --------------------------------------------
        Group {
            visible: pane.shows("shape")
            theme: pane.theme; font: pane.font
            icon: "󰓝"
            title: "Details"
            sub: "The little things, the same parts the docks use."
            ChoiceRow {
                theme: pane.theme; font: pane.font
                label: "Shadow"
                options: ["around", "windows"]
                labels: ({ around: "All around", windows: "Toward the windows" })
                value: pane.look.shadowDir
                onPicked: v => pane.set("shadowDir", v)
            }
            ChoiceRow {
                theme: pane.theme; font: pane.font
                label: "Line fade"
                options: ["along", "diagonal", "across", "theme"]
                labels: ({ along: "Along", diagonal: "Diagonal", across: "Across", theme: "Theme's border" })
                value: pane.look.outlineGradientDir
                enabled: pane.look.outlineGradient === true
                onPicked: v => pane.set("outlineGradientDir", v)
            }
            Stepper {
                visible: pane.look.ornaments === "brackets"
                theme: pane.theme; font: pane.font
                label: "Bracket"
                value: pane.look.bracket
                from: 3; to: 16
                suffix: " px"
                onStepped: v => pane.set("bracket", v)
            }
            ChoiceRow {
                visible: !pane.look.attach
                theme: pane.theme; font: pane.font
                label: "End cap"
                options: ["none", "start", "end", "both"]
                labels: ({ none: "None", start: "Start", end: "End", both: "Both" })
                value: pane.look.accentCap
                onPicked: v => pane.set("accentCap", v)
            }
        }

        // ---- motion ---------------------------------------------------------------
        Group {
            visible: pane.shows("shape")
            theme: pane.theme; font: pane.font
            icon: "󰅐"
            title: "Motion"
            sub: "How the shapes move and settle when things change."
            Stepper {
                theme: pane.theme; font: pane.font
                label: "Speed"
                value: pane.look.speed
                from: 0; to: 600; step: 20
                suffix: " ms"
                onStepped: v => pane.set("speed", v)
            }
            ChoiceRow {
                theme: pane.theme; font: pane.font
                label: "Easing"
                options: ["smooth", "springy", "linear"]
                labels: ({ smooth: "Smooth", springy: "Springy", linear: "Linear" })
                value: pane.look.easing
                onPicked: v => pane.set("easing", v)
            }
            Stepper {
                theme: pane.theme; font: pane.font
                label: "Resting fade"
                value: pane.look.idleOpacity
                from: 20; to: 100; step: 5
                suffix: "%"
                onStepped: v => pane.set("idleOpacity", v)
            }
            Stepper {
                visible: pane.look.idleOpacity < 100
                theme: pane.theme; font: pane.font
                label: "Fade time"
                value: pane.look.fadeTime
                from: 0; to: 1500; step: 50
                suffix: " ms"
                onStepped: v => pane.set("fadeTime", v)
            }
        }

        // ---- screen ---------------------------------------------------------------
        Group {
            visible: pane.shows("place")
            theme: pane.theme; font: pane.font
            icon: "󰺵"
            title: "Screen edges"
            sub: "Rounded corners and a frame, drawn over the desktop."
            Toggle {
                theme: pane.theme; font: pane.font
                label: "Rounded corners"
                checked: pane.look.corners
                onToggled: v => pane.set("corners", v)
            }
            ChoiceRow {
                visible: pane.look.corners
                theme: pane.theme; font: pane.font
                label: "Which"
                options: ["all", "top", "bottom"]
                labels: ({ all: "All four", top: "Top two", bottom: "Bottom two" })
                value: pane.look.cornerWhich
                onPicked: v => pane.set("cornerWhich", v)
            }
            Stepper {
                visible: pane.look.corners
                theme: pane.theme; font: pane.font
                label: "Roundness"
                value: pane.look.cornerSize
                from: 4; to: 40
                suffix: " px"
                onStepped: v => pane.set("cornerSize", v)
            }
            ChoiceRow {
                visible: pane.look.corners
                theme: pane.theme; font: pane.font
                label: "Color"
                options: ["black", "bar"]
                labels: ({ black: "Black", bar: "Bar's" })
                value: pane.look.cornerColor
                onPicked: v => pane.set("cornerColor", v)
            }
            Toggle {
                theme: pane.theme; font: pane.font
                label: "Screen frame"
                checked: pane.look.screenFrame
                onToggled: v => pane.set("screenFrame", v)
            }
            Stepper {
                visible: pane.look.screenFrame
                theme: pane.theme; font: pane.font
                label: "Width"
                value: pane.look.screenFrameWidth
                from: 1; to: 8
                suffix: " px"
                onStepped: v => pane.set("screenFrameWidth", v)
            }
            ChoiceRow {
                visible: pane.look.screenFrame
                theme: pane.theme; font: pane.font
                label: "Color"
                options: ["accent", "border", "bar", "black"]
                labels: ({ accent: "Accent", border: "Window borders", bar: "Bar's", black: "Black" })
                value: pane.look.screenFrameColor
                onPicked: v => pane.set("screenFrameColor", v)
            }
        }

        // ---- the settings button and its panel -----------------------------------
        Group {
            visible: pane.shows("place")
            theme: pane.theme; font: pane.font
            icon: "󰜟"
            title: "Bar button"
            sub: "The button on the bar that opens these settings. The Atelier button stays as it is."
            ChoiceRow {
                theme: pane.theme; font: pane.font
                label: "Show"
                options: ["icon", "text", "hidden"]
                labels: ({ icon: "Icon", text: "Text", hidden: "Hidden" })
                value: pane.look.barButton
                onPicked: v => pane.set("barButton", v)
            }
            RowLayout {
                visible: pane.look.barButton === "text"
                Layout.fillWidth: true
                spacing: 10
                Text {
                    text: "Text"
                    color: pane.theme.textSecondary
                    font.family: "sans-serif"
                    font.pixelSize: 12
                    Layout.preferredWidth: 110
                }
                Rectangle {
                    Layout.preferredWidth: 140
                    Layout.preferredHeight: 28
                    radius: 8
                    color: pane.theme.bgSurface
                    border.width: 1
                    border.color: barTextInput.activeFocus ? pane.theme.accentPrimary : pane.theme.bgBorder
                    TextInput {
                        id: barTextInput
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        verticalAlignment: TextInput.AlignVCenter
                        text: pane.look.barText
                        color: pane.theme.textPrimary
                        font.family: pane.font
                        font.pixelSize: 12
                        maximumLength: 12
                        selectByMouse: true
                        onEditingFinished: if (text.trim() !== "") pane.set("barText", text.trim())
                    }
                }
            }
            ChoiceRow {
                visible: pane.look.barButton !== "hidden"
                theme: pane.theme; font: pane.font
                label: "Right click"
                options: ["shape", "look", "none"]
                labels: ({ shape: "Next shape", look: "Next look", none: "Nothing" })
                value: pane.look.rightClick
                onPicked: v => pane.set("rightClick", v)
            }
            ChoiceRow {
                visible: pane.look.barButton !== "hidden"
                theme: pane.theme; font: pane.font
                label: "Middle click"
                options: ["toggle", "look", "none"]
                labels: ({ toggle: "On / off", look: "Next look", none: "Nothing" })
                value: pane.look.middleClick
                onPicked: v => pane.set("middleClick", v)
            }
            ChoiceRow {
                visible: pane.look.barButton !== "hidden"
                theme: pane.theme; font: pane.font
                label: "Open as"
                options: ["panel", "window"]
                labels: ({ panel: "Bar panel", window: "Own window" })
                value: pane.look.openAs
                onPicked: v => pane.set("openAs", v)
            }
            Stepper {
                visible: pane.look.barButton !== "hidden"
                theme: pane.theme; font: pane.font
                label: "Width"
                value: pane.look.windowWidth
                from: 480; to: 1000; step: 20
                suffix: " px"
                onStepped: v => pane.set("windowWidth", v)
            }
            Stepper {
                visible: pane.look.barButton !== "hidden"
                theme: pane.theme; font: pane.font
                label: "Height"
                value: pane.look.windowHeight
                from: 460; to: 1000; step: 20
                suffix: " px"
                onStepped: v => pane.set("windowHeight", v)
            }
            ChoiceRow {
                visible: pane.look.barButton !== "hidden"
                theme: pane.theme; font: pane.font
                label: "Spacing"
                options: ["compact", "comfortable", "spacious"]
                labels: ({ compact: "Compact", comfortable: "Comfortable", spacious: "Spacious" })
                value: pane.look.density
                onPicked: v => pane.set("density", v)
            }
            Stepper {
                visible: pane.look.barButton !== "hidden"
                theme: pane.theme; font: pane.font
                label: "Roundness"
                value: pane.look.cornerRadius
                from: 0; to: 20; step: 2
                suffix: " px"
                onStepped: v => pane.set("cornerRadius", v)
            }
            Stepper {
                visible: pane.look.barButton !== "hidden"
                theme: pane.theme; font: pane.font
                label: "Text size"
                value: pane.look.fontScale
                from: 80; to: 150; step: 5
                suffix: "%"
                onStepped: v => pane.set("fontScale", v)
            }
            Stepper {
                visible: pane.look.barButton !== "hidden"
                theme: pane.theme; font: pane.font
                label: "Panel tint"
                value: pane.look.surfaceTint
                from: 0; to: 30
                suffix: "%"
                onStepped: v => pane.set("surfaceTint", v)
            }
            Stepper {
                visible: pane.look.barButton !== "hidden"
                theme: pane.theme; font: pane.font
                label: "Panel opacity"
                value: pane.look.panelOpacity
                from: 50; to: 100; step: 2
                suffix: "%"
                onStepped: v => pane.set("panelOpacity", v)
            }
            Toggle {
                visible: pane.look.barButton !== "hidden"
                theme: pane.theme; font: pane.font
                label: "Colored outline"
                checked: pane.look.frame
                onToggled: v => pane.set("frame", v)
            }
            Toggle {
                visible: pane.look.barButton !== "hidden" && pane.look.frame
                theme: pane.theme; font: pane.font
                label: "Outline follows window border"
                checked: pane.look.frameGradient
                onToggled: v => pane.set("frameGradient", v)
            }
            ChoiceRow {
                visible: pane.look.barButton !== "hidden" && pane.look.frame && !pane.look.frameGradient
                theme: pane.theme; font: pane.font
                label: "Outline color"
                options: ["accent", "first", "middle", "last"]
                labels: ({ accent: "Accent", first: "First", middle: "Middle", last: "Last" })
                value: pane.look.frameColor
                onPicked: v => pane.set("frameColor", v)
            }
        }

        // ---- saved looks ----------------------------------------------------------
        Group {
            visible: pane.shows("looks")
            theme: pane.theme; font: pane.font
            icon: "󱂬"
            title: "Your looks"
            sub: "Twenty places to keep a look you made. Colors stay yours."
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Chip {
                    theme: pane.theme; font: pane.font
                    icon: "󰓦"
                    text: "Next look"
                    onClicked: pane.nextLook()
                }
                Chip {
                    theme: pane.theme; font: pane.font
                    icon: "󱁢"
                    text: "Undo"
                    enabled: !!pane.look.undoLook
                    onClicked: pane.undoLook()
                }
            }
            GridLayout {
                Layout.fillWidth: true
                columns: Math.max(4, Math.floor(pane.width / 120))
                rowSpacing: 6
                columnSpacing: 6
                Repeater {
                    model: 20
                    delegate: Rectangle {
                        required property int index
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        radius: 8
                        color: !!pane.look.savedLooks[index] ? pane.theme.bgSelected : pane.theme.bgHover
                        border.width: 1
                        border.color: pane.theme.bgBorder
                        Text {
                            anchors.centerIn: parent
                            text: String(index + 1)
                            color: pane.theme.textPrimary
                            font.family: pane.font
                            font.pixelSize: 11
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) pane.clearSlot(index);
                                else if (!!pane.look.savedLooks[index]) pane.loadSlot(index);
                                else pane.saveSlot(index);
                            }
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: "Click an empty place to save, a filled one to load, right click to clear."
                    color: pane.theme.textMuted
                    font.family: "sans-serif"
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                }
            }
        }

        RowLayout {
            visible: pane.shows("looks")
            spacing: 8
            Chip {
                theme: pane.theme; font: pane.font
                icon: "󰓦"
                text: "Docks follow the bar"
                visible: pane.dockList.length > 0
                onClicked: pane.svc.setFollow(0, true, "all")
            }
            Chip {
                theme: pane.theme; font: pane.font
                icon: "󱂬"
                text: "Docks"
                onClicked: AtelierHost.open("docks", "")
            }
            Chip {
                theme: pane.theme; font: pane.font
                icon: "󰑓"
                text: "Back to Horizon"
                onClicked: AequalynSettings.setBarStyle(AequalynSettings.barStyleDefaults)
            }
        }
    }
}
