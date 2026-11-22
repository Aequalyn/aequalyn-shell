// Rounded screen corners and a frame around the screen, from the bar's look.
// Corners are a small window in each corner painting the area outside a quarter
// circle; the frame is a thin window along each edge. They take no space and no
// clicks, and follow the same settings the bar does.
import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/settings"
import "../../style/BarLooks.js" as BarLooks
import "../../style/Colors.js" as Colors

Item {
    id: root
    property var theme

    readonly property var cfg: BarLooks.clean(AequalynSettings.barStyleCfg)
    readonly property var pal: Colors.fromTheme(theme)
    readonly property int size: cfg.cornerSize
    readonly property color paint: cfg.cornerColor === "bar" ? pal.bg : "black"
    readonly property bool cornersOn: cfg.corners
    readonly property var cornerList: cfg.cornerWhich === "top" ? ["tl", "tr"]
        : cfg.cornerWhich === "bottom" ? ["bl", "br"] : ["tl", "tr", "bl", "br"]
    readonly property bool frameOn: cfg.screenFrame
    readonly property var borders: pal.borders
    readonly property bool frameGradient: cfg.screenFrameColor === "border" && borders.length > 0
    readonly property color borderFirst: borders.length > 0 ? borders[0] : "black"
    readonly property color borderLast: borders.length > 0 ? borders[borders.length - 1] : "black"
    readonly property int frameWidth: cfg.screenFrameWidth
    readonly property color frameColor: cfg.screenFrameColor === "accent" ? pal.ac
        : cfg.screenFrameColor === "bar" ? pal.bg : "black"

    Variants {
        model: Quickshell.screens

        delegate: Component {
            Scope {
                id: perScreen
                required property var modelData

                Variants {
                    model: root.frameOn ? ["top", "bottom", "left", "right"] : []
                    delegate: Component {
                        PanelWindow {
                            id: edge
                            required property var modelData
                            screen: perScreen.modelData
                            anchors {
                                top: edge.modelData !== "bottom"
                                bottom: edge.modelData !== "top"
                                left: edge.modelData !== "right"
                                right: edge.modelData !== "left"
                            }
                            implicitWidth: root.frameWidth
                            implicitHeight: root.frameWidth
                            color: root.frameGradient ? "transparent" : root.frameColor
                            Rectangle {
                                anchors.fill: parent
                                visible: root.frameGradient
                                gradient: Gradient {
                                    orientation: edge.modelData === "top" || edge.modelData === "bottom"
                                        ? Gradient.Horizontal : Gradient.Vertical
                                    GradientStop { position: 0; color: root.borderFirst }
                                    GradientStop { position: 1; color: root.borderLast }
                                }
                            }
                            exclusionMode: ExclusionMode.Ignore
                            WlrLayershell.namespace: "aequalyn-bar-frame"
                            WlrLayershell.layer: WlrLayer.Overlay
                            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                            mask: Region {}
                        }
                    }
                }

                Variants {
                    model: root.cornersOn ? root.cornerList : []
                    delegate: Component {
                        PanelWindow {
                            id: corner
                            required property var modelData
                            screen: perScreen.modelData
                            anchors {
                                top: corner.modelData === "tl" || corner.modelData === "tr"
                                bottom: corner.modelData === "bl" || corner.modelData === "br"
                                left: corner.modelData === "tl" || corner.modelData === "bl"
                                right: corner.modelData === "tr" || corner.modelData === "br"
                            }
                            implicitWidth: root.size
                            implicitHeight: root.size
                            color: "transparent"
                            exclusionMode: ExclusionMode.Ignore
                            WlrLayershell.namespace: "aequalyn-bar-corners"
                            WlrLayershell.layer: WlrLayer.Overlay
                            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                            mask: Region {}

                            Canvas {
                                anchors.fill: parent
                                readonly property color c: root.paint
                                readonly property int n: root.size
                                onCChanged: requestPaint()
                                onNChanged: requestPaint()
                                onPaint: {
                                    const ctx = getContext("2d");
                                    ctx.reset();
                                    const ox = corner.modelData === "tl" || corner.modelData === "bl" ? n : 0;
                                    const oy = corner.modelData === "tl" || corner.modelData === "tr" ? n : 0;
                                    ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, 1);
                                    ctx.fillRect(0, 0, n, n);
                                    ctx.globalCompositeOperation = "destination-out";
                                    ctx.beginPath();
                                    ctx.arc(ox, oy, n, 0, Math.PI * 2, false);
                                    ctx.fill();
                                    ctx.globalCompositeOperation = "source-over";
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
