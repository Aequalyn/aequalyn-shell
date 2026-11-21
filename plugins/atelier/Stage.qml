// The desktop in miniature: the bar and every dock together, as they are
// right now (or as an ensemble would make them). Shared by the Bar and Docks
// tabs, so you always see the two side by side.
import QtQuick
import "root:/settings"
import "../../style/Style.js" as Style

Item {
    id: stage
    clip: true
    property var theme
    property string font: "JetBrainsMono Nerd Font"
    property var barLook
    property int barSize: 22
    // [{ look, pal, edge, icons }]
    property var docks: []
    property int dockSize: 22
    property int marked: -1         // a dock to point out
    property string caption: ""

    // the wallpaper to show (empty: the theme's colours)
    property string wallpaper: ""

    Desk { anchors.fill: parent; theme: stage.theme; radius: 12; source: stage.wallpaper }

    // two windows, tiled
    Repeater {
        model: [[0.05, 0.27, 0.52, 0.5], [0.59, 0.27, 0.36, 0.5]]
        delegate: Rectangle {
            required property var modelData
            x: modelData[0] * stage.width; y: modelData[1] * stage.height
            width: modelData[2] * stage.width; height: modelData[3] * stage.height
            radius: 6
            color: Qt.rgba(stage.theme.bgBase.r, stage.theme.bgBase.g, stage.theme.bgBase.b, 0.55)
            border.color: Qt.rgba(stage.theme.textPrimary.r, stage.theme.textPrimary.g, stage.theme.textPrimary.b, 0.08)
        }
    }

    // the bar on the edge it sits on (Settings -> Bar); on a side, the same picture
    // turned a quarter
    readonly property string barEdge: ["bottom", "left", "right"].indexOf(AequalynSettings.barPosition) >= 0
                                      ? AequalynSettings.barPosition : "top"
    readonly property bool barAtBottom: barEdge === "bottom"
    readonly property bool barSide: barEdge === "left" || barEdge === "right"
    BarMini {
        id: miniBar
        // along the stage's height on a side; its centre where the side bar's would be
        readonly property real length: stage.barSide ? stage.height - 12 : stage.width - 16
        rotation: stage.barSide ? 90 : 0
        x: stage.barSide ? (stage.barEdge === "left" ? 6 + height / 2 : stage.width - 6 - height / 2) - width / 2 : 8
        y: stage.barSide ? stage.height / 2 - height / 2 : (stage.barAtBottom ? stage.height - height - 6 : 6)
        width: length
        theme: stage.theme
        look: stage.barLook
        barSize: stage.barSize
        edgeAtStart: stage.barEdge === "top" || stage.barEdge === "left"
        vertical: stage.barSide
    }

    // the bar's real footprint in stage coordinates: the clickable area in the
    // Control Center is bound to this, so it follows the bar to every edge
    readonly property int barThickness: Math.round(miniBar.height)
    readonly property rect barArea: stage.barSide
        ? Qt.rect(stage.barEdge === "left" ? 6 : stage.width - 6 - stage.barThickness,
                  6, stage.barThickness, Math.max(0, stage.height - 12))
        : Qt.rect(8, stage.barAtBottom ? stage.height - 6 - stage.barThickness : 6,
                  Math.max(0, stage.width - 16), stage.barThickness)

    // one miniature dock, fitted to the space it actually has. Docks share their
    // edge, so a long one is scaled down instead of spilling past the picture.
    function dockGeometry(i) {
        const d = stage.docks[i] || {};
        const edge = d.edge || "bottom";
        const hz = edge === "top" || edge === "bottom";
        const mates = stage.docks.filter(x => (x.edge || "bottom") === edge);
        const pos = stage.docks.slice(0, i).filter(x => (x.edge || "bottom") === edge).length;
        const icons = Math.max(1, d.icons || 4);
        const glow = Style.marginFor(d.look || {});
        const naturalW = icons * (stage.dockSize + 10) + 18 + 2 * glow;
        const naturalH = stage.dockSize + 18 + 2 * glow;
        const along = hz ? stage.width : stage.height;
        const across = hz ? stage.height : stage.width;
        const clearance = stage.barEdge === edge ? stage.barThickness + 6 : 0;
        const per = along / Math.max(1, mates.length);
        const fit = Math.max(0.05, Math.min(1,
            (per - 12) / Math.max(1, naturalW),
            (across - 12 - clearance) / Math.max(1, naturalH)));
        const visualW = naturalW * fit;
        const visualH = naturalH * fit;
        const centre = Math.min(along - 6 - visualW / 2,
                                Math.max(6 + visualW / 2, (pos + 0.5) * per));
        const cx = hz ? centre : (edge === "left" ? 6 + visualH / 2 + clearance
                                                  : stage.width - 6 - visualH / 2 - clearance);
        const cy = hz ? (edge === "top" ? 6 + visualH / 2 + clearance
                                        : stage.height - 6 - visualH / 2 - clearance) : centre;
        const boxW = hz ? visualW : visualH;
        const boxH = hz ? visualH : visualW;
        return {
            edge: edge, hz: hz, cx: cx, cy: cy, scale: fit,
            boxW: boxW, boxH: boxH,
            rect: Qt.rect(cx - boxW / 2, cy - boxH / 2, boxW, boxH)
        };
    }
    readonly property rect dockArea: stage.docks.length > 0 ? stage.dockGeometry(0).rect : Qt.rect(0, 0, 0, 0)

    Repeater {
        model: stage.docks
        delegate: Item {
            id: slot
            required property var modelData
            required property int index
            readonly property var geo: stage.dockGeometry(index)

            DockMini {
                id: dm
                look: slot.modelData.look
                pal: slot.modelData.pal
                size: stage.dockSize
                icons: slot.modelData.icons || 4
                rotation: slot.geo.hz ? 0 : (slot.geo.edge === "left" ? 90 : -90)
                scale: slot.geo.scale
                transformOrigin: Item.Center
                x: slot.geo.cx - width / 2
                y: slot.geo.cy - height / 2
            }
            Rectangle {   // the dock being edited: a number beside it, on the windows' side
                visible: stage.marked === slot.index
                x: slot.geo.hz ? slot.geo.cx - width / 2
                   : slot.geo.edge === "left" ? slot.geo.cx + slot.geo.boxW / 2 + 6
                                              : slot.geo.cx - slot.geo.boxW / 2 - width - 6
                y: !slot.geo.hz ? slot.geo.cy - height / 2
                   : slot.geo.edge === "bottom" ? slot.geo.cy - slot.geo.boxH / 2 - height - 6
                                                : slot.geo.cy + slot.geo.boxH / 2 + 6
                width: 22; height: 16; radius: 8
                color: stage.theme.accentPrimary
                Text {
                    anchors.centerIn: parent
                    text: slot.index + 1
                    color: stage.theme.bgBase
                    font.family: stage.font
                    font.pixelSize: 10
                    font.bold: true
                }
            }
        }
    }

    Text {
        visible: stage.caption !== ""
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: stage.barEdge === "top" ? stage.barThickness + 20 : 14
        text: stage.caption
        color: "white"
        opacity: 0.85
        font.family: stage.font
        font.pixelSize: 11
    }
}
