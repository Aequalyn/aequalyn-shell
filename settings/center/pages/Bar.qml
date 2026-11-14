// Bar: its look (Atelier's bar pane), its size, and which widgets it shows where.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/settings"
import "../../../plugins/atelier"
import "../../../style/BarLooks.js" as BarLooks
import ".."

CcPage {
    id: page
    title: "Bar"
    sub: "The strip along the top of the screen: how it looks and what it shows."
    tabs: ["Look", "Size", "What it shows"]
    fills: [0]

    BarPane {
        visible: page.tab === 0
        Layout.fillWidth: true
        Layout.fillHeight: true
        theme: Cc.theme
        font: Cc.mono
    }

    // ---- size ---------------------------------------------------------------------
    Stage {
        visible: page.tab === 1
        Layout.fillWidth: true
        Layout.maximumWidth: 640
        Layout.preferredHeight: 150
        theme: Cc.theme
        font: Cc.mono
        wallpaper: Cc.wallpaper
        barLook: BarLooks.clean(AequalynSettings.barStyleCfg)
        barSize: Math.round(AequalynSettings.barHeight * 0.75)
    }
    CcSlider {
        visible: page.tab === 1
        setting: "barHeight"; title: "Height"
        from: 24; to: 48; step: 2; unit: " px"
    }
    CcSlider {
        visible: page.tab === 1
        setting: "barOpacity"; title: "How solid it is"
        sub: "Lower lets the wallpaper show through."
        from: 40; to: 100; step: 5; unit: "%"
    }
    CcMore {
        visible: page.tab === 1
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
        visible: page.tab === 2
        text: "Move a widget with the arrows, or hide it with its switch. When a part is full, its widgets scroll."
    }
    GridLayout {
        visible: page.tab === 2
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
}
