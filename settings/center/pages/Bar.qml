// Bar: its look (Atelier's bar pane), its size, and which widgets it shows where.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/settings"
import "../../../plugins/atelier"
import "../../../style/BarLooks.js" as BarLooks
import "../../../plugins/bar/widgets/Widgets.js" as Widgets
import ".."

CcPage {
    id: page
    title: "Bar"
    plugin: "bar"
    sub: "The strip along the top of the screen: how it looks and what it shows."
    tabs: ["Ready-made", "Shape and colours", "Size and place", "What it shows"]

    readonly property var look: BarLooks.clean(AequalynSettings.barStyleCfg)
    readonly property var svc: AtelierHost.docks
    readonly property var stageDocks: svc ? svc.docks.map((d, i) => {
        const e = svc.effective(i);
        return { look: e, pal: svc.palette(e), edge: d.edge, icons: Math.max(3, Math.min(6, d.apps.length)) };
    }) : []

    // ---- the picture on top: your desktop, or your bar's widgets in order --------------
    stageHeight: tab === 3 ? Math.min(220, widgetStrip.implicitHeight) : 190
    stage: [
        Stage {
            visible: page.tab !== 3
            anchors.fill: parent
            theme: Cc.theme
            font: Cc.mono
            wallpaper: Cc.wallpaper
            barLook: page.look
            barSize: Math.round(AequalynSettings.barHeight * 0.75)
            docks: page.stageDocks
        },
        WidgetStrip { id: widgetStrip; visible: page.tab === 3; anchors.fill: parent }
    ]

    // ---- ready-made looks, and the bar and docks together ---------------------------------
    Loader {
        visible: page.tab === 0
        active: page.opened(0)
        Layout.fillWidth: true
        Layout.preferredHeight: item ? item.contentHeight : 0
        sourceComponent: Component {
            BarPane {
                section: "looks"
                showStage: false
                interactive: false
                theme: Cc.theme
                font: Cc.mono
            }
        }
    }

    // ---- shape, every part and colours ----------------------------------------------------
    Loader {
        visible: page.tab === 1
        active: page.opened(1)
        Layout.fillWidth: true
        Layout.preferredHeight: item ? item.contentHeight : 0
        sourceComponent: Component {
            BarPane {
                section: "shape"
                showStage: false
                interactive: false
                theme: Cc.theme
                font: Cc.mono
            }
        }
    }

    // ---- size and place -------------------------------------------------------------------
    CcSlider {
        visible: page.tab === 2
        setting: "barHeight"; title: "Height"
        from: 24; to: 48; step: 2; unit: " px"
    }
    CcSlider {
        visible: page.tab === 2
        setting: "barOpacity"; title: "How solid it is"
        sub: "Lower lets the wallpaper show through."
        from: 40; to: 100; step: 5; unit: "%"
    }
    Loader {
        visible: page.tab === 2
        active: page.opened(2)
        Layout.fillWidth: true
        Layout.preferredHeight: item ? item.contentHeight : 0
        sourceComponent: Component {
            BarPane {
                section: "place"
                showStage: false
                interactive: false
                theme: Cc.theme
                font: Cc.mono
            }
        }
    }
    CcMore {
        visible: page.tab === 2
        title: "When a part of the bar is full"
        CcNote { text: "How much of the bar each part may use before its widgets scroll (with the mouse wheel). A third each keeps them equal on any screen." }
        CcSlider {
            setting: "barSidePercent"; title: "Each side may use"
            from: 0; to: 100; step: 1
            format: v => v === 0 ? "As much as fits" : v + "% of the bar"
        }
        CcSlider {
            setting: "barCenterPercent"; title: "The middle may use"
            from: 0; to: 100; step: 1
            format: v => v === 0 ? "As much as fits" : v + "% of the bar"
        }
    }

    // ---- what it shows --------------------------------------------------------------
    CcNote {
        visible: page.tab === 3
        text: "Move a widget with the arrows, or hide it with its switch. When a part is full, its widgets scroll."
    }
    CcMore {
        visible: page.tab === 3
        title: "Workspaces on the bar"
        CcSlider {
            setting: "workspaceCount"; title: "Workspace slots"
            sub: "Show between one and ten workspaces on each screen."
            from: 1; to: 10; step: 1
        }
        CcChoice {
            setting: "workspaceLabelStyle"
            options: [
                { key: "numbers", label: "1  2  3  4  5 — Numbers" },
                { key: "roman", label: "I  II  III  IV  V — Roman" },
                { key: "japanese", label: "一  二  三  四  五 — Japanese" },
                { key: "symbols", label: "●  ◆  ▲  ■  ★ — Symbols" }
            ]
        }
        CcToggle {
            setting: "workspaceShowEmpty"; title: "Show empty workspaces"
            sub: "Keep every workspace slot visible, including ones with no windows."
        }
    }
    GridLayout {
        visible: page.tab === 3
        Layout.fillWidth: true
        columns: width > 760 ? 3 : 1
        columnSpacing: 10
        rowSpacing: 10
        Repeater {
            model: [{ key: "left", label: "Left" }, { key: "center", label: "Middle" }, { key: "right", label: "Right" }]
            delegate: Rectangle {
                id: region
                required property var modelData
                required property int index
                readonly property var ids: modelData.key === "left" ? AequalynSettings.barLeft
                    : modelData.key === "center" ? AequalynSettings.barCenter : AequalynSettings.barRight
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                implicitHeight: regionCol.implicitHeight + 24
                radius: 14
                color: Cc.theme.bgSurface
                ColumnLayout {
                    id: regionCol
                    x: 12; y: 12
                    width: parent.width - 24
                    spacing: 6
                    Text {
                        text: region.modelData.label
                        color: Cc.theme.textSecondary
                        font.family: Cc.sans
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        Layout.bottomMargin: 2
                    }
                    CcNote { visible: region.ids.length === 0; text: "Nothing here yet." }
                    Repeater {
                        model: region.ids
                        delegate: Rectangle {
                            id: w
                            required property string modelData
                            required property int index
                            readonly property string toggleKey: AequalynSettings.pluginToggleKey[modelData] || ""
                            readonly property bool shown: AequalynSettings.pluginVisible(modelData)
                            Layout.fillWidth: true
                            implicitHeight: 40
                            radius: 10
                            color: Cc.theme.bgBase
                            opacity: shown ? 1 : 0.55
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 6
                                spacing: 4
                                Text {
                                    text: AequalynSettings.pluginLabels[w.modelData] || w.modelData
                                    color: Cc.theme.textPrimary
                                    font.family: Cc.sans
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Mini { glyph: "\u{F0143}"; tip: "Up"; enabled: w.index > 0
                                    onClicked: AequalynSettings.moveBarPlugin(region.modelData.key, w.index, region.modelData.key, w.index - 1) }
                                Mini { glyph: "\u{F0140}"; tip: "Down"; enabled: w.index < region.ids.length - 1
                                    onClicked: AequalynSettings.moveBarPlugin(region.modelData.key, w.index, region.modelData.key, w.index + 2) }
                                Mini { glyph: "\u{F0141}"; tip: "To the part on the left"; enabled: region.index > 0
                                    onClicked: page.moveTo(region.modelData.key, w.index, region.index - 1) }
                                Mini { glyph: "\u{F0142}"; tip: "To the part on the right"; enabled: region.index < 2
                                    onClicked: page.moveTo(region.modelData.key, w.index, region.index + 1) }
                                CcSwitch {
                                    visible: w.toggleKey !== ""
                                    scale: 0.8
                                    checked: w.shown
                                    onToggled: v => AequalynSettings.apply(w.toggleKey, v)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // which click opens each plugin widget's quick panel (Widgets.js: quick); the click
    // it takes from the left button moves the widget's own thing to the right one
    CcSection {
        visible: page.tab === 3 && page.quickWidgets.length > 0
        title: "Their quick panels"
        hint: "Which click opens each widget's quick panel. If it takes the left click, the right click does what the left one did."
        Repeater {
            model: page.quickWidgets
            delegate: RowLayout {
                id: qrow
                required property string modelData
                Layout.fillWidth: true
                spacing: 10
                Text {
                    Layout.preferredWidth: 150
                    text: AequalynSettings.pluginLabels[qrow.modelData] || qrow.modelData
                    color: Cc.theme.textPrimary
                    font.family: Cc.sans
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
                CcChoice {
                    Layout.fillWidth: true
                    options: [{ key: "left", label: "Left click" }, { key: "right", label: "Right click" },
                              { key: "middle", label: "Middle click" }, { key: "none", label: "None" }]
                    current: AequalynSettings.quickClick(qrow.modelData, Widgets.quickDefault(qrow.modelData))
                    onChosen: k => AequalynSettings.setQuickClick(qrow.modelData, k)
                }
            }
        }
        CcNote { text: "The Themes and Layouts buttons choose theirs below, with their other clicks." }
    }
    // the widgets on the bar with a quick panel, whose plugin is on
    readonly property var quickWidgets: AequalynSettings.pluginOrder.filter(id => Widgets.quickDefault(id) !== "none"
        && (Widgets.pluginFor(id) === "" || AequalynSettings.enabledPlugins.indexOf(Widgets.pluginFor(id)) >= 0))

    // the Themes and Layouts buttons: the name beside the icon, and their other clicks
    CcMore {
        visible: page.tab === 3
        title: "The Themes and Layouts buttons"
        Repeater {
            model: [
                { key: "atelier", title: "Themes button", sub: "A click opens the theme picker.", right: "quick", middle: "random-wallpaper" },
                { key: "layouts", title: "Layouts button", sub: "A click opens Arranging windows.", right: "next-layout", middle: "prev-layout" }
            ]
            delegate: CcSection {
                id: btn
                required property var modelData
                title: modelData.title
                hint: modelData.sub
                CcToggle {
                    title: "Show the name beside the icon"
                    checked: AequalynSettings.atelierCfg[btn.modelData.key + "ShowName"] !== false
                    onToggled: v => AequalynSettings.setIn("atelier", btn.modelData.key + "ShowName", v)
                }
                Repeater {
                    model: [["Right", "A right click"], ["Middle", "A middle click"]]
                    delegate: ColumnLayout {
                        id: click
                        required property var modelData
                        readonly property string key: btn.modelData.key + modelData[0] + "Click"
                        Layout.fillWidth: true
                        spacing: 6
                        CcNote { text: click.modelData[1] }
                        CcChoice {
                            options: page.buttonActions
                            current: AequalynSettings.atelierCfg[click.key] || (click.modelData[0] === "Right" ? btn.modelData.right : btn.modelData.middle)
                            onChosen: k => AequalynSettings.setIn("atelier", click.key, k)
                        }
                    }
                }
            }
        }
    }
    readonly property var buttonActions: [
        { key: "next-layout", label: "Next layout" }, { key: "prev-layout", label: "Previous layout" },
        { key: "next-wallpaper", label: "Next wallpaper" }, { key: "random-wallpaper", label: "Random wallpaper" },
        { key: "themes", label: "Themes" }, { key: "quick", label: "Its quick panel" }, { key: "none", label: "Nothing" }
    ]

    readonly property var regionKeys: ["left", "center", "right"]
    // to the end of the part on the left / the start of the part on the right
    function moveTo(from, index, toRegion) {
        const to = regionKeys[toRegion];
        const target = to === "left" ? AequalynSettings.barLeft : to === "center" ? AequalynSettings.barCenter : AequalynSettings.barRight;
        const fromIdx = regionKeys.indexOf(from);
        AequalynSettings.moveBarPlugin(from, index, to, toRegion < fromIdx ? target.length : 0);
    }

    component Mini: Rectangle {
        id: mini
        property string glyph: ""
        property string tip: ""
        signal clicked()
        implicitWidth: 26
        implicitHeight: 26
        radius: 8
        color: miniArea.containsMouse && enabled ? Cc.theme.bgHover : "transparent"
        opacity: enabled ? 1 : 0.25
        Accessible.role: Accessible.Button
        Accessible.name: tip
        Text {
            anchors.centerIn: parent
            text: mini.glyph
            color: Cc.theme.textSecondary
            font.family: Cc.mono
            font.pixelSize: 14
        }
        MouseArea {
            id: miniArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: mini.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: mini.clicked()
        }
    }

    // the bar's widgets as they sit: left, middle and right, hidden ones left out
    component WidgetStrip: Rectangle {
        id: strip
        function shown(ids) { return (ids || []).filter(id => AequalynSettings.pluginVisible(id)); }
        function shortName(id) {
            const n = AequalynSettings.pluginLabels[id] || id;
            return n.replace(/ \(.*\)$/, "").replace(/ & .*$/, "");
        }
        implicitHeight: cols.implicitHeight + 24
        radius: 14
        color: Cc.theme.bgSurface
        RowLayout {
            id: cols
            x: 12; y: 12
            width: parent.width - 24
            spacing: 10
            Repeater {
                model: [["Left", AequalynSettings.barLeft], ["Middle", AequalynSettings.barCenter], ["Right", AequalynSettings.barRight]]
                delegate: Rectangle {
                    id: part
                    required property var modelData
                    readonly property var ids: strip.shown(modelData[1])
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.alignment: Qt.AlignTop
                    implicitHeight: partCol.implicitHeight + 16
                    radius: 10
                    color: Cc.alpha(Cc.theme.bgBase, Math.max(0.5, AequalynSettings.barOpacity / 100))
                    Column {
                        id: partCol
                        x: 8; y: 8
                        width: parent.width - 16
                        spacing: 6
                        Text {
                            text: part.modelData[0] + "  ·  " + part.ids.length
                            color: Cc.theme.textMuted
                            font.family: Cc.sans
                            font.pixelSize: 11
                        }
                        Flow {
                            width: parent.width
                            spacing: 4
                            Repeater {
                                model: part.ids
                                delegate: Pill { required property string modelData; label: strip.shortName(modelData) }
                            }
                        }
                        Text {
                            visible: part.ids.length === 0
                            text: "Nothing here"
                            color: Cc.theme.textMuted
                            font.family: Cc.sans
                            font.pixelSize: 11
                        }
                    }
                }
            }
        }
    }
    component Pill: Rectangle {
        property string label: ""
        width: pillText.implicitWidth + 14
        height: 24
        radius: 8
        color: Cc.theme.bgSelected
        Text {
            id: pillText
            anchors.centerIn: parent
            text: parent.label
            color: Cc.theme.textPrimary
            font.family: Cc.sans
            font.pixelSize: 11
        }
    }
}
