// Docks: up to 16, 4 on each edge of each screen. The stage shows them with
// the bar; pick one below it, then where it sits, how it hides and how it
// looks: the bar's look ("Same as the bar") or one of its own, for this dock,
// its edge or every dock. A dock's right click opens this tab on that dock.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "controls"
import "../style/AequalynLooks.js" as Looks
import "../style/BarLooks.js" as BarLooks
import "../style/Effects.js" as Fx
import "root:/settings"

Flickable {
    id: pane
    property var theme
    property string font: "JetBrainsMono Nerd Font"

    readonly property var svc: AtelierHost.docks
    readonly property var list: svc ? svc.docks : []
    readonly property int sel: Math.max(0, Math.min(list.length - 1, AtelierHost.dockFocus))
    readonly property var dock: list[sel] || null
    readonly property var drawn: svc && dock ? svc.effective(sel) : ({})
    readonly property var pal: svc && dock ? svc.palette(drawn) : null
    readonly property string ownLook: dock && !dock.followBar ? Looks.dockLookOf(drawn) : ""
    // where look changes go: "one", "edge" or "all"
    property string scope: "one"
    property string family: "all"

    readonly property var edgeNames: ({ bottom: "Bottom", top: "Top", left: "Left", right: "Right" })
    readonly property var edgeGlyphs: ({ bottom: "󰁅", top: "󰁝", left: "󰁍", right: "󰁔" })

    function set(key, value) { if (svc) svc.patch(sel, key, value); }
    function setLook(changes) { if (svc) svc.patchManyScope(sel, changes, scope); }
    function lookName(d, i) {
        if (d.followBar) return "Bar's look";
        const k = Looks.dockLookOf(svc.effective(i));
        return k !== "" ? Looks.byKey(Looks.dock, k).label : "Own look";
    }

    readonly property var stageDocks: list.map((d, i) => {
        const e = svc.effective(i);
        return { look: e, pal: svc.palette(e), edge: d.edge, icons: Math.max(3, Math.min(6, d.apps.length)) };
    })

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
            barLook: BarLooks.clean(AequalynSettings.barStyleCfg)
            docks: AequalynSettings.dockEnabled ? pane.stageDocks : []
            marked: pane.sel
            caption: AequalynSettings.dockEnabled ? pane.list.length + " of 16 docks" : "Docks are off"
        }

        Toggle {
            theme: pane.theme; font: pane.font
            label: "Docks"
            sublabel: "Up to 16, 4 on each edge of each screen. Right-click a dock to come back here."
            checked: AequalynSettings.dockEnabled
            onToggled: v => AequalynSettings.apply("dockEnabled", v)
        }

        // ---- the docks: one card each ------------------------------------------------
        Flow {
            Layout.fillWidth: true
            spacing: 8
            visible: !!pane.svc
            Repeater {
                model: pane.list
                delegate: Rectangle {
                    id: dcard
                    required property var modelData
                    required property int index
                    readonly property bool on: index === pane.sel
                    width: 150; height: 54
                    radius: 12
                    color: on ? pane.theme.bgSelected : (dArea.containsMouse ? pane.theme.bgHover : pane.theme.bgSurface)
                    border.width: on ? 2 : 1
                    border.color: on ? pane.theme.accentPrimary : pane.theme.bgBorder
                    Behavior on color { ColorAnimation { duration: 120 } }
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10
                        Rectangle {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            radius: 9
                            color: dcard.on ? pane.theme.accentPrimary : pane.theme.bgBase
                            Text {
                                anchors.centerIn: parent
                                text: dcard.index + 1
                                color: dcard.on ? pane.theme.bgBase : pane.theme.accentPrimary
                                font.family: pane.font
                                font.pixelSize: 13
                                font.bold: true
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                                Layout.fillWidth: true
                                text: pane.edgeGlyphs[dcard.modelData.edge] + " " + pane.edgeNames[dcard.modelData.edge]
                                    + (Quickshell.screens.length > 1 && dcard.modelData.monitor ? " · " + dcard.modelData.monitor : "")
                                color: pane.theme.textPrimary
                                font.family: pane.font
                                font.pixelSize: 11
                                font.bold: true
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: pane.lookName(dcard.modelData, dcard.index)
                                color: pane.theme.textMuted
                                font.family: pane.font
                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }
                        }
                    }
                    MouseArea {
                        id: dArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: AtelierHost.dockFocus = dcard.index
                    }
                }
            }
            Rectangle {   // add a dock
                visible: pane.list.length < 16
                width: 150; height: 54
                radius: 12
                color: addArea.containsMouse ? pane.theme.bgHover : "transparent"
                border.width: 1
                border.color: pane.theme.bgBorder
                Text {
                    anchors.centerIn: parent
                    text: "󰐕  Add a dock"
                    color: pane.theme.textSecondary
                    font.family: pane.font
                    font.pixelSize: 11
                }
                MouseArea {
                    id: addArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { pane.svc.addDock(pane.sel); AtelierHost.dockFocus = pane.svc.docks.length - 1; }
                }
            }
        }
        Text {
            visible: !!pane.svc && pane.svc.notice !== ""
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: pane.svc ? pane.svc.notice : ""
            color: pane.theme.accentOrange
            font.family: pane.font
            font.pixelSize: 11
        }
        Text {
            visible: !pane.svc
            text: "Turn the docks on to set them up."
            color: pane.theme.textMuted
            font.family: pane.font
            font.pixelSize: 12
        }

        // ---- place and hiding ---------------------------------------------------------
        GridLayout {
            visible: !!pane.dock
            Layout.fillWidth: true
            columns: pane.width > 900 ? 2 : 1
            columnSpacing: 12
            rowSpacing: 12

            Group {
                Layout.alignment: Qt.AlignTop
                theme: pane.theme; font: pane.font
                icon: pane.dock ? pane.edgeGlyphs[pane.dock.edge] : ""
                title: "Dock " + (pane.sel + 1)
                sub: pane.dock ? pane.dock.apps.length + (pane.dock.apps.length === 1 ? " app" : " apps")
                    + ". Pin apps with its + button and drag icons to reorder." : ""
                ChoiceRow {
                    visible: Quickshell.screens.length > 1
                    theme: pane.theme; font: pane.font
                    label: "Screen"
                    options: [""].concat(Quickshell.screens.map(s => s.name))
                    labels: ({ "": "Main" })
                    value: pane.dock ? pane.dock.monitor : ""
                    onPicked: v => pane.set("monitor", v)
                }
                ChoiceRow {
                    theme: pane.theme; font: pane.font
                    label: "Edge"
                    options: ["bottom", "top", "left", "right"]
                    labels: pane.edgeNames
                    value: pane.dock ? pane.dock.edge : ""
                    onPicked: v => pane.set("edge", v)
                }
                ChoiceRow {
                    theme: pane.theme; font: pane.font
                    label: "Along it"
                    options: ["start", "center", "end"]
                    labels: ({ start: "Start", center: "Middle", end: "End" })
                    value: pane.dock ? pane.dock.align : ""
                    onPicked: v => pane.set("align", v)
                }
                Stepper {
                    theme: pane.theme; font: pane.font
                    label: "Size"
                    value: pane.dock ? pane.dock.size : 44
                    from: 16; to: 64; step: 2
                    suffix: " px"
                    onStepped: v => pane.set("size", v)
                }
                Stepper {
                    theme: pane.theme; font: pane.font
                    label: "Icons"
                    value: pane.dock ? pane.dock.iconScale : 100
                    from: 50; to: 200; step: 10
                    suffix: "%"
                    onStepped: v => pane.set("iconScale", v)
                }
                Stepper {
                    theme: pane.theme; font: pane.font
                    label: "Margin"
                    value: pane.svc && pane.dock ? pane.svc.marginOf(pane.dock.edge) : 6
                    from: 0; to: 64
                    suffix: " px"
                    onStepped: v => pane.svc.setMargin(pane.dock.edge, v)
                }
                Toggle {
                    theme: pane.theme; font: pane.font
                    label: "Full length"
                    checked: pane.dock ? pane.dock.stretch : false
                    onToggled: v => pane.set("stretch", v)
                }
                Toggle {
                    theme: pane.theme; font: pane.font
                    label: "Keep windows clear"
                    sublabel: "Shared by every dock on this edge"
                    checked: pane.dock ? pane.dock.reserve : false
                    onToggled: v => pane.set("reserve", v)
                }
                Chip {
                    visible: pane.list.length > 1
                    theme: pane.theme; font: pane.font
                    compact: true
                    icon: "󰍴"
                    text: "Remove this dock"
                    onClicked: { pane.svc.removeDock(pane.sel); AtelierHost.dockFocus = Math.max(0, pane.sel - 1); }
                }
            }

            Group {
                Layout.alignment: Qt.AlignTop
                theme: pane.theme; font: pane.font
                icon: "󰘕"
                title: "Hiding"
                sub: "Out of the way until the pointer reaches the edge"
                Toggle {
                    theme: pane.theme; font: pane.font
                    label: "Auto-hide"
                    checked: pane.dock ? pane.dock.autohide : false
                    onToggled: v => pane.set("autohide", v)
                }
                ChoiceRow {
                    theme: pane.theme; font: pane.font
                    label: "Effect"
                    options: pane.svc ? pane.svc.hideEffects : []
                    labels: Fx.labels
                    value: pane.dock ? pane.dock.hideEffect : ""
                    enabled: pane.dock ? pane.dock.autohide : false
                    onPicked: v => pane.set("hideEffect", v)
                }
                Stepper {
                    visible: !!pane.dock && pane.dock.autohide
                    theme: pane.theme; font: pane.font
                    label: "Speed"
                    value: pane.dock ? pane.dock.hideSpeed : 180
                    from: 60; to: 800; step: 20
                    suffix: " ms"
                    onStepped: v => pane.set("hideSpeed", v)
                }
                Stepper {
                    visible: !!pane.dock && pane.dock.autohide
                    theme: pane.theme; font: pane.font
                    label: "Show after"
                    value: pane.dock ? pane.dock.showDelay : 0
                    from: 0; to: 1000; step: 50
                    suffix: " ms"
                    onStepped: v => pane.set("showDelay", v)
                }
                Stepper {
                    visible: !!pane.dock && pane.dock.autohide
                    theme: pane.theme; font: pane.font
                    label: "Hide after"
                    value: pane.dock ? pane.dock.hideDelay : 450
                    from: 0; to: 2000; step: 50
                    suffix: " ms"
                    onStepped: v => pane.set("hideDelay", v)
                }
                Stepper {
                    visible: !!pane.dock && pane.dock.autohide
                    theme: pane.theme; font: pane.font
                    label: "Edge strip"
                    value: pane.dock ? pane.dock.revealStrip : 3
                    from: 1; to: 12
                    suffix: " px"
                    onStepped: v => pane.set("revealStrip", v)
                }
                Toggle {
                    visible: !!pane.dock && pane.dock.autohide
                    theme: pane.theme; font: pane.font
                    label: "A line where it waits"
                    checked: pane.dock ? pane.dock.edgeHint : true
                    onToggled: v => pane.set("edgeHint", v)
                }
                ChoiceRow {
                    theme: pane.theme; font: pane.font
                    label: "Attention"
                    options: ["off", "dot", "pulse"]
                    labels: ({ off: "Nothing", dot: "Dot", pulse: "Pulse" })
                    value: pane.dock ? pane.dock.attention : ""
                    onPicked: v => pane.set("attention", v)
                }
            }
        }

        // ---- look ------------------------------------------------------------------
        Group {
            visible: !!pane.dock
            theme: pane.theme; font: pane.font
            icon: "󰏘"
            title: "Look"
            sub: "Wear the bar's look and change with it, or a look of the dock's own."
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                    model: [[true, "󰍜", "Same as the bar", "Changes whenever the bar does"],
                            [false, "󱂬", "Its own look", "Picked below"]]
                    delegate: Rectangle {
                        id: followCard
                        required property var modelData
                        readonly property bool on: !!pane.dock && pane.dock.followBar === modelData[0]
                        Layout.fillWidth: true
                        Layout.preferredHeight: 54
                        radius: 12
                        color: on ? pane.theme.bgSelected : (followArea.containsMouse ? pane.theme.bgHover : pane.theme.bgSurface)
                        border.width: on ? 2 : 1
                        border.color: on ? pane.theme.accentPrimary : pane.theme.bgBorder
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10
                            Rectangle {
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32
                                radius: 9
                                color: followCard.on ? pane.theme.accentPrimary : pane.theme.bgBase
                                Text {
                                    anchors.centerIn: parent
                                    text: followCard.modelData[1]
                                    color: followCard.on ? pane.theme.bgBase : pane.theme.accentPrimary
                                    font.family: pane.font
                                    font.pixelSize: 15
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text {
                                    Layout.fillWidth: true
                                    text: followCard.modelData[2]
                                    color: pane.theme.textPrimary
                                    font.family: pane.font
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: followCard.modelData[3]
                                    color: pane.theme.textMuted
                                    font.family: pane.font
                                    font.pixelSize: 10
                                }
                            }
                        }
                        MouseArea {
                            id: followArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: pane.svc.setFollow(pane.sel, followCard.modelData[0], pane.scope)
                        }
                    }
                }
            }
            ChoiceRow {
                theme: pane.theme; font: pane.font
                label: "Apply to"
                options: ["one", "edge", "all"]
                labels: ({ one: "Dock " + (pane.sel + 1), edge: "Its edge", all: "Every dock" })
                value: pane.scope
                onPicked: v => pane.scope = v
            }
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
                columns: Math.max(2, Math.floor(pane.width / 200))
                columnSpacing: 8
                rowSpacing: 8
                Repeater {
                    model: Looks.inFamily(Looks.dock, pane.family)
                    delegate: LookCard {
                        id: lc
                        required property var modelData
                        readonly property var sample: Object.assign({}, pane.drawn, Looks.dockSet(modelData.key))
                        Layout.fillWidth: true
                        theme: pane.theme; font: pane.font
                        previewHeight: 52
                        title: modelData.label
                        subtitle: modelData.about
                        badge: Looks.byKey(Looks.families, modelData.family).label.toUpperCase()
                        selected: pane.ownLook === modelData.key
                        onClicked: pane.svc.applyLook(pane.sel, modelData.key, pane.scope)
                        Desk {
                            anchors.fill: parent
                            theme: pane.theme
                            DockMini {
                                anchors.centerIn: parent
                                look: lc.sample
                                pal: pane.pal
                                size: 22
                                icons: 4
                            }
                        }
                    }
                }
            }
            RowLayout {
                spacing: 8
                Chip {
                    visible: !!pane.svc && pane.svc.canUndo
                    theme: pane.theme; font: pane.font
                    compact: true
                    icon: "󰕌"
                    text: "Undo"
                    onClicked: pane.svc.undoLook()
                }
                Chip {
                    theme: pane.theme; font: pane.font
                    compact: true
                    icon: "󰍜"
                    text: "Dress the bar like this dock"
                    onClicked: pane.svc.lookToBar(pane.sel)
                }
                Chip {
                    theme: pane.theme; font: pane.font
                    compact: true
                    icon: "󰑓"
                    text: "Reset dock"
                    onClicked: pane.svc.resetDock(pane.sel)
                }
            }
        }

        GridLayout {
            visible: !!pane.dock
            Layout.fillWidth: true
            columns: pane.width > 900 ? 2 : 1
            columnSpacing: 12
            rowSpacing: 12

            Group {
                Layout.alignment: Qt.AlignTop
                theme: pane.theme; font: pane.font
                icon: "󰏘"
                title: "Colors"
                sub: pane.dock && pane.dock.followBar ? "From the bar; a change here gives the dock its own look" : "Theme follows Atelier's palette"
                ChoiceRow {
                    theme: pane.theme; font: pane.font
                    label: "From"
                    options: pane.svc ? pane.svc.styles : []
                    labels: ({ theme: "Theme", custom: "Your own", monochrome: "Greys", category: "Per app kind" })
                    value: pane.drawn.style
                    onPicked: v => pane.setLook({ style: v })
                }
                Stepper {
                    theme: pane.theme; font: pane.font
                    label: "Opacity"
                    value: pane.drawn.opacity || 90
                    from: 10; to: 100; step: 5
                    suffix: "%"
                    onStepped: v => pane.setLook({ opacity: v })
                }
                Stepper {
                    theme: pane.theme; font: pane.font
                    label: "Corners"
                    value: pane.drawn.radius || 16
                    from: 1; to: 64
                    suffix: " px"
                    onStepped: v => pane.setLook({ radius: v })
                }
                Swatches {
                    visible: pane.drawn.style === "custom"
                    theme: pane.theme; font: pane.font
                    label: "Background"
                    colors: pane.svc ? pane.svc.swatches.slice(0, 8) : []
                    value: pane.drawn.customBg || ""
                    onPicked: v => pane.setLook({ customBg: v })
                }
                Swatches {
                    visible: pane.drawn.style === "custom"
                    theme: pane.theme; font: pane.font
                    label: "Text"
                    colors: pane.svc ? pane.svc.swatches.slice(8, 16) : []
                    value: pane.drawn.customFg || ""
                    onPicked: v => pane.setLook({ customFg: v })
                }
                Swatches {
                    visible: pane.drawn.style === "custom"
                    theme: pane.theme; font: pane.font
                    label: "Accent"
                    colors: pane.svc ? pane.svc.swatches.slice(16) : []
                    value: pane.drawn.accentColor || ""
                    onPicked: v => pane.setLook({ accentColor: v })
                }
            }

            Group {
                Layout.alignment: Qt.AlignTop
                theme: pane.theme; font: pane.font
                icon: "󰙨"
                title: "Every part"
                sub: "Ends, surface, lines and ornaments, shared with the bar"
                StyleEditor {
                    Layout.fillWidth: true
                    theme: pane.theme; font: pane.font
                    look: pane.drawn
                    pal: pane.pal
                    // tiles are drawn lying down: a side dock is shown as if at the bottom
                    edge: pane.dock && pane.dock.edge === "top" ? "top" : "bottom"
                    onChanged: changes => pane.setLook(changes)
                }
            }
        }
    }
}
