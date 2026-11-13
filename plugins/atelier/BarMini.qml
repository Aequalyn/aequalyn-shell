// A small bar with made up widgets, painted by the bar's own BarDecor: the
// shape cards, the ready made looks and the preview on the Bar tab.
import QtQuick
import  "../bar"
import  "../../style/Shapes.js" as Shapes

Item {
    id: mini
    property var theme
    property var look
    property int barSize: 20
    property bool widgets: true

    // left: 3 widgets, center: 1, right: 4 (as a share of the width)
    readonly property var plan: [
        ["left", 0.035, 0.05], ["left", 0.095, 0.10], ["left", 0.205, 0.045],
        ["center", 0.44, 0.12],
        ["right", 0.70, 0.045], ["right", 0.755, 0.06], ["right", 0.825, 0.045], ["right", 0.88, 0.075]
    ]
    readonly property int inset: look ? Math.round(Shapes.sectionMargin(look, 4, barSize) / 2) : 4
    readonly property var slots: plan.map(p => ({
        a: Math.round(p[0] === "left" ? p[1] * width + inset : p[0] === "right" ? p[1] * width - inset : p[1] * width),
        len: Math.max(6, Math.round(p[2] * width)), region: p[0], hovered: false
    }))
    readonly property int floatGap: look && look.enabled ? Math.min(Shapes.floatGapFor(look), 8) : 0
    readonly property int band: look && look.enabled ? Shapes.thicknessFor(barSize, look) : barSize

    implicitHeight: band + floatGap

    Item {
        id: bandItem
        y: mini.floatGap
        width: parent.width
        height: mini.band

        Rectangle {
            anchors.fill: parent
            visible: !mini.look || !mini.look.enabled
            color: mini.theme ? mini.theme.bgBase : "black"
        }
        BarDecor {
            anchors.fill: parent
            visible: mini.look && mini.look.enabled
            theme: mini.theme
            look: mini.look
            barSize: mini.barSize
            fakeSlots: mini.slots
        }
        // the widgets themselves, as little bars of text
        Repeater {
            model: mini.widgets ? mini.slots : []
            delegate: Rectangle {
                required property var modelData
                x: modelData.a + 3
                y: (bandItem.height - height) / 2
                width: Math.max(3, modelData.len - 6)
                height: Math.max(2, Math.round(mini.barSize / 7))
                radius: height / 2
                color: mini.theme ? Qt.rgba(mini.theme.textPrimary.r, mini.theme.textPrimary.g, mini.theme.textPrimary.b,
                                            modelData.region === "center" ? 0.8 : 0.45) : "white"
            }
        }
    }
}
