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
        AequalynSettings.setBarStyle(Object.assign(BarLooks.applyLook(look, key), { enabled: true, chips: raw.chips }));
    }
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
                                    font.pixelSize: 15
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text {
                                    Layout.fillWidth: true
                                    text: shapeCard.modelData[2]
                                    color: pane.theme.textPrimary
                                    font.family: pane.font
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: shapeCard.modelData[3]
                                    color: pane.theme.textMuted
                                    font.family: pane.font
                                    font.pixelSize: 10
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
            Layout.fillWidth: true
            columns: pane.width > 900 ? 2 : 1
            columnSpacing: 12
            rowSpacing: 12

            Group {
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
                    from: 0; to: 40
                    suffix: " px"
                    onStepped: v => pane.set("padding", v)
                }
                Stepper {
                    theme: pane.theme; font: pane.font
                    label: "Corners"
                    value: pane.look.radius
                    from: 0; to: 40
                    suffix: " px"
                    onStepped: v => pane.set("radius", v)
                }
                Stepper {
                    visible: pane.look.shape !== "full"
                    theme: pane.theme; font: pane.font
                    label: "Edge gap"
                    value: pane.look.edgeGap
                    from: 0; to: 30
                    suffix: " px"
                    onStepped: v => pane.set("edgeGap", v)
                }
                Stepper {
                    visible: pane.look.shape !== "full"
                    theme: pane.theme; font: pane.font
                    label: "Side gap"
                    value: pane.look.sideGap
                    from: 0; to: 200; step: 4
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
                Layout.alignment: Qt.AlignTop
                Layout.fillWidth: true
                spacing: 12

                Group {
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
                    theme: pane.theme; font: pane.font
                    icon: "󰏘"
                    title: "Colors"
                    sub: "Theme follows Atelier's palette"
                    ChoiceRow {
                        theme: pane.theme; font: pane.font
                        label: "From"
                        options: ["theme", "palette", "custom", "monochrome"]
                        labels: ({ theme: "Theme", palette: "Every shape its own", custom: "Your own", monochrome: "Greys" })
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
                    Stepper {
                        theme: pane.theme; font: pane.font
                        label: "Opacity"
                        value: pane.look.opacity
                        from: 10; to: 100; step: 5
                        suffix: "%"
                        onStepped: v => pane.set("opacity", v)
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

        RowLayout {
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
