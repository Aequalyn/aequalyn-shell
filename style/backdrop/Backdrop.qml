// What the desktop looks like behind a full-screen panel, and how it comes and goes.
//
// Every style but "instant" is drawn here, on a still picture of the screen taken the
// moment the panel opens (before anything of it is drawn), so the blur itself can grow
// and fade: the compositor's blur can only be on or off, and a panel fading over it
// shows the desktop sharp for a moment. "instant" is the compositor's own live blur: the
// window opens as aequalyn-panel-<name>, which Hyprland's aequalyn-.* rule blurs whole.
// (Not the background-effect protocol: on a scaled screen Hyprland blurs only part of
// the window with it.)
//
// The window maps while `shown`, is named by `layerName()`, and its content follows
// `progress` (0 → 1):
//   PanelWindow {
//       visible: bd.shown
//       WlrLayershell.namespace: bd.layerName("settings")
//       Backdrop { id: bd; open: root.panelVisible; theme: root.theme; tintAlpha: 0.35 }
//       Item { opacity: bd.progress; ... the panel ... }
//   }
//
// In settings it also draws a small preview: set `preview`, `image` (a picture to stand in
// for the desktop) and `style`, and toggle `open`; it always draws the picture itself, so
// nothing under it shows through between its comings and goings.
//
// How the picture is drawn: one shader pass (prep.frag) carries the picture's edge pixels
// out past the screen (so the blur never fades to see-through at the edges), twists it
// (Maelstrom), breaks it into tiles (Mosaic) and lays the shade over it; then one
// MultiEffect blurs, tints and, for Iris and the zoom, masks it. The shade is part of the
// picture, so it blurs, zooms and is masked with it: no second edge.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "root:/settings"
import "Styles.js" as Styles

Item {
    id: bd
    anchors.fill: parent

    property bool open: false
    property var screen: null                // default: the screen in use (where the panel opens)
    readonly property var where: screen || Quickshell.screens.find(x => Hyprland.focusedMonitor
                                                                    && x.name === Hyprland.focusedMonitor.name)
                                        || Quickshell.screens[0] || null
    property bool preview: false             // a small picture in settings, not a real panel
    property url image: ""                   // preview: this picture instead of the screen
    property string style: ""                // preview: this style instead of the setting
    property real strength: -1               // preview: 0..100 instead of the setting
    property real darkness: -1               // preview: 0..100 instead of the setting
    property var theme: null                 // for "From the theme" colours
    property real tintAlpha: 0.35            // the panel's own shade, at the default darkness
    property string colours: ""              // preview: "theme" or "neutral" instead of the setting
    property point origin: Qt.point(width / 2, height / 2)   // where Iris and Maelstrom start

    readonly property var cfg: AequalynSettings.backdropCfg
    readonly property string kind: Styles.valid(style !== "" ? style : cfg.style)
    readonly property real power: Math.max(0, Math.min(100, strength >= 0 ? strength : Number(cfg.strength))) / 100
    readonly property real shade: Math.min(0.92, tintAlpha * Math.max(0, Math.min(100, darkness >= 0 ? darkness : Number(cfg.dim))) / 50)
    readonly property real px: width / 2560               // blur sizes are set for a large screen

    // the colours: the theme's (its background as the shade, a little of its accent in the
    // blur) or neutral (black, and a cool white for Frost)
    readonly property bool themed: (colours !== "" ? colours : cfg.colour) !== "neutral" && theme !== null
    readonly property color shadeColour: themed ? Qt.rgba(theme.bgBase.r, theme.bgBase.g, theme.bgBase.b, 1) : "black"
    readonly property color frostColour: themed ? Qt.tint("#f2f4f8", Qt.rgba(theme.accentPrimary.r, theme.accentPrimary.g, theme.accentPrimary.b, 0.28)) : "#e8eef8"
    readonly property color glow: themed ? Qt.rgba(theme.accentPrimary.r, theme.accentPrimary.g, theme.accentPrimary.b, 1) : "white"

    // the desktop picture is taken, or there is none to wait for
    // (Instant needs none; it is not taken then, so a style picked while the panel is open
    // only replays when there is a picture to replay on)
    readonly property bool hasShot: preview || (shot.item !== null && shot.item.hasContent)
    readonly property bool ready: hasShot || waited || layerBlur && !shooting
    property bool waited: false
    property bool shooting: false   // a picture was asked for as this panel opened
    property bool closing: false
    readonly property bool shown: open || closing || preview

    // Instant: the compositor blurs the window, by its name. A layer's name is set as it
    // opens, so this follows the style only while the panel is closed; picked while it
    // is open, Instant keeps the picture there is, still, until it closes.
    property bool layerBlur: false
    Binding on layerBlur {
        when: !bd.shown
        value: bd.kind === "instant" && !bd.preview
        restoreMode: Binding.RestoreNone
    }
    function layerName(name) { return (layerBlur ? "aequalyn-panel-" : "aequalyn_panel_") + name; }
    readonly property bool instantNow: layerBlur || preview && kind === "instant"

    property real progress: 0      // the panel itself
    property real fx: 0            // the desktop behind it

    function begin() {
        if (!open || !ready) return;
        if (instantNow) { inAnim.stop(); progress = 1; fx = 1; return; }
        if (!inAnim.running && progress < 1) inAnim.restart();
    }
    onOpenChanged: {
        if (open) {
            closing = false; outAnim.stop(); waited = false;
            shooting = !preview && !layerBlur;
            if (shooting) wait.restart();
            begin();
        } else {
            inAnim.stop(); wait.stop();
            if (instantNow || !preview && !ready) { progress = 0; fx = 0; closing = false; }
            else { closing = true; outAnim.restart(); }
        }
    }
    onReadyChanged: begin()
    // a new style while open plays its way in again behind the panel
    onKindChanged: {
        if (!open) return;
        if (kind === "instant" || layerBlur) { fxAnim.stop(); fx = 1; }
        else if (ready) { fx = 0; fxAnim.restart(); }
    }
    Component.onCompleted: begin()

    // if the screen cannot be pictured, open anyway (just darkened)
    // (and stop asking: a picture coming later would make the blur jump in)
    Timer {
        id: wait
        interval: 250
        onTriggered: {
            if (bd.hasShot) return;
            bd.waited = true; bd.shooting = false; bd.begin();
        }
    }

    readonly property int inMs: kind === "maelstrom" ? 520 : kind === "mosaic" ? 380 : 320
    readonly property int outMs: kind === "maelstrom" ? 340 : 220
    ParallelAnimation {
        id: inAnim
        NumberAnimation { target: bd; property: "progress"; to: 1; duration: Math.min(260, bd.inMs); easing.type: Easing.OutCubic }
        NumberAnimation { target: bd; property: "fx"; to: 1; duration: bd.inMs; easing.type: Easing.OutCubic }
    }
    NumberAnimation { id: fxAnim; target: bd; property: "fx"; to: 1; duration: bd.inMs; easing.type: Easing.OutCubic }
    ParallelAnimation {
        id: outAnim
        NumberAnimation { target: bd; property: "progress"; to: 0; duration: Math.min(150, bd.outMs); easing.type: Easing.OutCubic }
        NumberAnimation { target: bd; property: "fx"; to: 0; duration: bd.outMs; easing.type: Easing.InOutQuad }
        onFinished: bd.closing = false
    }

    // ---- the desktop, as it was ----------------------------------------------------
    // (a preview always draws its picture: Instant blurred, Dim only darkened; Instant
    // picked while open keeps blurring the picture taken as it opened)
    readonly property bool pictured: preview || kind !== "dim" && !layerBlur && (kind !== "instant" || hasShot)
    readonly property bool drawn: pictured && shown && hasShot
    Item {
        id: desk
        width: bd.width
        height: bd.height
        visible: false
        // on before the picture comes: the screen is pictured once, and a layer made
        // after that would stay empty
        layer.enabled: bd.shown && (bd.preview || bd.shooting)
        Loader {
            id: shot
            anchors.fill: parent
            active: !bd.preview && bd.shown && bd.shooting
            sourceComponent: ScreencopyView {
                captureSource: bd.where
                live: false
                paintCursor: false
            }
        }
        Image {
            anchors.fill: parent
            visible: bd.preview
            source: bd.image
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(640, 360)
            asynchronous: true
        }
    }

    // a preview has no live desktop under it: the plain picture stands in for it (round
    // Iris's circle, behind the zoom)
    Image {
        anchors.fill: parent
        visible: bd.preview
        source: bd.image
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(640, 360)
        asynchronous: true
    }

    // no picture (Dim only, Instant, or none could be taken): just the shade
    Rectangle {
        anchors.fill: parent
        visible: bd.shown && !bd.drawn
        color: bd.shadeColour
        opacity: bd.shade * bd.fx
    }

    // ---- the picture, blurred ----------------------------------------------------------
    // drawn on a stage larger than the screen by `pad` on every side. Made only once the
    // picture is there (and the picture's layer is on): the effects look at their sources
    // once, when made, and a layer switched on later would leave them empty.
    readonly property real blurPx: Math.max(4, Math.round((20 + 44 * power) * Math.max(0.3, px)))
    readonly property int pad: Math.ceil(blurPx * 2 + 4)
    Loader {
        id: stage
        x: -bd.pad
        y: -bd.pad
        width: bd.width + 2 * bd.pad
        height: bd.height + 2 * bd.pad
        active: bd.drawn
        transformOrigin: Item.Center
        scale: bd.kind === "zoom" ? 1 - 0.07 * bd.fx : 1
        sourceComponent: Item {
            ShaderEffect {
                id: prep
                width: stage.width
                height: stage.height
                visible: false
                layer.enabled: true
                property var source: desk
                readonly property point inset: Qt.point(bd.pad / Math.max(1, bd.width), bd.pad / Math.max(1, bd.height))
                readonly property real twist: bd.kind === "maelstrom" ? bd.fx * (4 + 6 * bd.power) : 0
                readonly property real pull: bd.kind === "maelstrom" ? bd.fx : 0
                readonly property real aspect: bd.width / Math.max(1, bd.height)
                readonly property real reach: 0.55 + 0.35 * bd.fx
                readonly property point center: Qt.point(bd.origin.x / Math.max(1, bd.width), bd.origin.y / Math.max(1, bd.height))
                // Mosaic: the tile grows from a pixel to its full size
                readonly property real cell: 1 + bd.fx * (6 + 34 * bd.power) * Math.max(0.25, bd.px * 2)
                readonly property point cells: bd.kind === "mosaic" && bd.fx > 0.001
                    ? Qt.point(Math.max(1, bd.width / cell), Math.max(1, bd.height / cell)) : Qt.point(0, 0)
                readonly property color tone: bd.kind === "frost" ? bd.frostColour : bd.shadeColour
                readonly property real amount: (bd.kind === "frost" ? 0.12 + 0.3 * bd.shade : bd.shade) * bd.fx
                readonly property vector4d shade: Qt.vector4d(tone.r, tone.g, tone.b, amount)
                fragmentShader: "prep.frag.qsb"
            }

            // Iris: a circle that opens from the middle (from round the panel, so the
            // panel never sits on sharp desktop); the zoom: the screen, corners rounded;
            // the others: all of it. The shapes are shown and hidden by colour: in a
            // hidden layer, `visible` changes are never redrawn.
            Item {
                id: mask
                width: stage.width
                height: stage.height
                visible: false
                layer.enabled: true
                Rectangle {
                    color: bd.kind === "iris" ? "white" : "transparent"
                    readonly property real far: Math.hypot(bd.width, bd.height) * 0.62
                    readonly property real r: (0.28 + 0.72 * bd.fx) * far
                    x: bd.pad + bd.origin.x - r
                    y: bd.pad + bd.origin.y - r
                    width: 2 * r; height: 2 * r; radius: r
                }
                Rectangle {
                    color: bd.kind !== "iris" && bd.kind !== "zoom" ? "white" : "transparent"
                    width: stage.width; height: stage.height
                }
                Rectangle {
                    color: bd.kind === "zoom" ? "white" : "transparent"
                    x: bd.pad; y: bd.pad
                    width: bd.width; height: bd.height
                    radius: 36 * bd.fx * Math.max(0.3, bd.px * 2)
                }
            }

            MultiEffect {
                width: stage.width
                height: stage.height
                source: prep
                autoPaddingEnabled: false
                blurEnabled: true
                blurMax: bd.blurPx
                blur: bd.kind === "dim" ? 0 : bd.kind === "mosaic" ? 0.25 * bd.fx : bd.fx
                blurMultiplier: bd.kind === "frost" ? 0.6 : 0
                saturation: bd.kind === "frost" ? -0.55 * bd.fx : bd.kind === "maelstrom" ? 0.15 * bd.fx : 0
                brightness: bd.kind === "frost" ? 0.06 * bd.fx : 0
                colorization: bd.themed && bd.kind !== "dim" ? 0.3 * bd.fx : 0
                colorizationColor: bd.glow
                // the mask is always on (fully open but for Iris and the zoom), so changing
                // style never swaps the effect's shader or source under it
                maskEnabled: true
                maskSource: mask
                maskThresholdMin: 0.4
                maskSpreadAtMin: bd.kind === "iris" ? 0.6 : 0.2
            }
        }
    }

    // the zoom's surround
    Rectangle {
        anchors.fill: parent
        z: -1
        visible: bd.drawn && bd.kind === "zoom"
        color: bd.shadeColour
        opacity: bd.fx
    }
}
