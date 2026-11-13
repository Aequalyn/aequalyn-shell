// Every part of a look, for the bar and the docks alike: ends, surface, lines
// and ornaments as painted tiles, then fill, border and shadow. Changes go out
// through changed(set) as { key: value }; the owner decides where they land
// (the bar, one dock, an edge or all docks).
import QtQuick
import QtQuick.Layouts
import "controls"
import  "../../style/Style.js" as Style

ColumnLayout {
    id: ed
    property var theme
    property string font: "JetBrainsMono Nerd Font"
    property var look: ({})          // what is being edited, as drawn
    property var pal
    property string edge: "bottom"
    property bool enabled: true
    signal changed(var set)

    property string part: "ends"
    readonly property var parts: [
        ["ends", "Ends", Style.ends], ["surface", "Surface", Style.surfaces],
        ["lines", "Lines", Style.lines], ["ornaments", "Ornaments", Style.ornaments],
        ["fill", "Fill", null], ["edge", "Border & shadow", null]
    ]
    readonly property var current: parts.find(p => p[0] === part)
    readonly property var defs: Style.settings

    function pick(key, value) { if (ed.enabled) ed.changed({ [key]: value }); }
    function opts(key) { return defs[key] ? defs[key].options : []; }

    spacing: 10
    opacity: enabled ? 1 : 0.5

    Flow {
        Layout.fillWidth: true
        spacing: 6
        Repeater {
            model: ed.parts
            delegate: Chip {
                required property var modelData
                theme: ed.theme
                font: ed.font
                text: modelData[1]
                selected: ed.part === modelData[0]
                onClicked: ed.part = modelData[0]
            }
        }
    }

    // ends, surfaces, lines, ornaments: one tile each, painted with that part
    Flow {
        Layout.fillWidth: true
        visible: ed.current && ed.current[2] !== null
        spacing: 8
        Repeater {
            model: ed.current && ed.current[2] ? ed.current[2].options : []
            delegate: StyleTile {
                required property string modelData
                theme: ed.theme
                font: ed.font
                pal: ed.pal
                edge: ed.edge
                look: Object.assign({}, ed.look, { [ed.part]: modelData })
                label: ed.current[2].labels[modelData] || modelData
                selected: ed.look[ed.part] === modelData
                onClicked: ed.pick(ed.part, modelData)
            }
        }
    }
    Text {
        visible: ed.current && ed.current[2] !== null
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: ed.current && ed.current[2] ? (ed.current[2].abouts[ed.look[ed.part]] || "") : ""
        color: ed.theme.textMuted
        font.family: ed.font
        font.pixelSize: 10
    }
    ChoiceRow {
        visible: ed.part === "ends"
        theme: ed.theme; font: ed.font
        label: "Pointing"
        options: ed.opts("pointing")
        labels: ({ right: "Right", left: "Left", both: "Both" })
        value: ed.look.pointing
        enabled: Style.pointingEnds.indexOf(ed.look.ends) >= 0
        onPicked: v => ed.pick("pointing", v)
    }
    ChoiceRow {
        visible: ed.part === "ends"
        theme: ed.theme; font: ed.font
        label: "Flat side"
        options: ed.opts("flatSide")
        labels: ({ none: "None", edge: "Screen edge", windows: "Windows" })
        value: ed.look.flatSide
        onPicked: v => ed.pick("flatSide", v)
    }
    ChoiceRow {
        visible: ed.part === "lines"
        theme: ed.theme; font: ed.font
        label: "Line side"
        options: ed.opts("railSide")
        labels: ({ windows: "Windows", edge: "Screen edge", both: "Both" })
        value: ed.look.railSide
        onPicked: v => ed.pick("railSide", v)
    }

    // fill
    ChoiceRow {
        visible: ed.part === "fill"
        theme: ed.theme; font: ed.font
        label: "Fill"
        options: ed.opts("fill")
        labels: ({ solid: "Solid", gradient: "Gradient", glass: "Glass" })
        value: ed.look.fill
        enabled: Style.noGradient.indexOf(ed.look.surface) < 0
        onPicked: v => ed.pick("fill", v)
    }
    ChoiceRow {
        visible: ed.part === "fill"
        theme: ed.theme; font: ed.font
        label: "Gradient to"
        options: ed.opts("gradientTo")
        labels: ({ accent: "Accent", palette: "Palette", spectrum: "Spectrum", lighter: "Lighter", darker: "Darker" })
        value: ed.look.gradientTo
        enabled: ed.look.fill === "gradient" && Style.noGradient.indexOf(ed.look.surface) < 0
        onPicked: v => ed.pick("gradientTo", v)
    }
    Toggle {
        visible: ed.part === "fill"
        theme: ed.theme; font: ed.font
        label: "Gradient across"
        sublabel: "From the edge to the windows instead of end to end"
        checked: ed.look.gradientAcross === true
        onToggled: v => ed.pick("gradientAcross", v)
    }
    ChoiceRow {
        visible: ed.part === "fill"
        theme: ed.theme; font: ed.font
        label: "Pattern"
        options: ed.opts("pattern")
        labels: ({ none: "None", stripes: "Stripes", dots: "Dots", grid: "Grid" })
        value: ed.look.pattern
        enabled: Style.noTexture.indexOf(ed.look.surface) < 0
        onPicked: v => ed.pick("pattern", v)
    }
    ChoiceRow {
        visible: ed.part === "fill"
        theme: ed.theme; font: ed.font
        label: "Depth"
        options: ed.opts("depth")
        labels: ({ flat: "Flat", raised: "Raised", sunken: "Sunken" })
        value: ed.look.depth
        enabled: Style.noDepth.indexOf(ed.look.surface) < 0
        onPicked: v => ed.pick("depth", v)
    }

    // border and shadow
    ChoiceRow {
        visible: ed.part === "edge"
        theme: ed.theme; font: ed.font
        label: "Border"
        options: ed.opts("border")
        labels: ({ subtle: "Subtle", text: "Text", accent: "Accent" })
        value: ed.look.border
        enabled: Style.colorlessLines.indexOf(ed.look.lines) < 0
        onPicked: v => ed.pick("border", v)
    }
    Stepper {
        visible: ed.part === "edge"
        theme: ed.theme; font: ed.font
        label: "Width"
        value: ed.look.borderWidth || 1
        from: 1; to: 4
        suffix: " px"
        onStepped: v => ed.pick("borderWidth", v)
    }
    Toggle {
        visible: ed.part === "edge"
        theme: ed.theme; font: ed.font
        label: "Border gradient"
        checked: ed.look.outlineGradient === true
        onToggled: v => ed.pick("outlineGradient", v)
    }
    ChoiceRow {
        visible: ed.part === "edge" && ed.look.outlineGradient === true
        theme: ed.theme; font: ed.font
        label: "Border to"
        options: ed.opts("outlineGradientTo")
        labels: ({ lighter: "Lighter", accent: "Accent", palette: "Palette", spectrum: "Spectrum" })
        value: ed.look.outlineGradientTo
        onPicked: v => ed.pick("outlineGradientTo", v)
    }
    ChoiceRow {
        visible: ed.part === "edge"
        theme: ed.theme; font: ed.font
        label: "Shadow"
        options: ed.opts("shadow")
        labels: ({ none: "None", soft: "Soft", strong: "Strong" })
        value: ed.look.shadow
        onPicked: v => ed.pick("shadow", v)
    }
    ChoiceRow {
        visible: ed.part === "edge"
        theme: ed.theme; font: ed.font
        label: "Shadow color"
        options: ed.opts("shadowColor")
        labels: ({ dark: "Dark", accent: "Accent glow" })
        value: ed.look.shadowColor
        enabled: ed.look.shadow !== "none"
        onPicked: v => ed.pick("shadowColor", v)
    }
}
