// Palette: where the colours come from and how they are generated.
import QtQuick
import QtQuick.Layouts
import "controls"
import "root:/settings"

Flickable {
    id: pane
    property var theme          // the live Theme singleton
    property string font: "JetBrainsMono Nerd Font"

    readonly property var cfg: AequalynSettings.paletteCfg
    readonly property bool fromWallpaper: theme.wallpaperMode
    readonly property var schemes: [
        ["scheme-tonal-spot", "Balanced", "Calm accents from the image's main hue. The default."],
        ["scheme-content", "Faithful", "Follows the image's own colours closely."],
        ["scheme-fidelity", "Exact", "Keeps the source colour as the accent, as-is."],
        ["scheme-expressive", "Playful", "Shifts hues for unexpected combinations."],
        ["scheme-fruit-salad", "Bold", "Several strong hues at once."],
        ["scheme-rainbow", "Rainbow", "Colourful accents on neutral surfaces."],
        ["scheme-neutral", "Muted", "Low saturation, close to grey."],
        ["scheme-monochrome", "Mono", "Greyscale only."]
    ]

    function set(key, value) { AequalynSettings.setIn("palette", key, value); }

    contentHeight: column.implicitHeight + 24
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    ColumnLayout {
        id: column
        width: pane.width
        spacing: 12

        SectionHeader {
            theme: pane.theme; font: pane.font
            text: "Colours come from"
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Repeater {
                model: [
                    { key: "wallpaper", icon: "󰸉", title: "The wallpaper", text: "Every new wallpaper repaints the shell, Hyprland, GTK, Qt and terminals." },
                    { key: "theme", icon: "󰏘", title: "A fixed theme", text: pane.theme.wallpaperMode ? "Pick a theme or palette in Themes to pin its colours." : "Pinned: " + pane.theme.committed.family + " " + pane.theme.committed.name }
                ]
                delegate: Rectangle {
                    id: srcCard
                    required property var modelData
                    readonly property bool on: (modelData.key === "wallpaper") === pane.fromWallpaper
                    Layout.fillWidth: true
                    Layout.preferredHeight: 78
                    radius: 12
                    color: on ? pane.theme.bgSelected : (sa.containsMouse ? pane.theme.bgHover : pane.theme.bgSurface)
                    border.width: on ? 2 : 1
                    border.color: on ? pane.theme.accentPrimary : pane.theme.bgBorder
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 12
                        Text {
                            text: srcCard.modelData.icon
                            color: pane.theme.accentPrimary
                            font.family: pane.font
                            font.pixelSize: 22
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            Text {
                                text: srcCard.modelData.title
                                color: pane.theme.textPrimary
                                font.family: pane.font
                                font.pixelSize: 13
                                font.bold: true
                            }
                            Text {
                                Layout.fillWidth: true
                                text: srcCard.modelData.text
                                color: pane.theme.textMuted
                                font.family: pane.font
                                font.pixelSize: 10
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                    MouseArea {
                        id: sa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (srcCard.modelData.key === "wallpaper") {
                                // Regenerate from what is on screen now, then follow it.
                                pane.theme.setWallpaperMode();
                                AequalynSettings.retheme();
                            }
                        }
                    }
                }
            }
        }

        Toggle {
            theme: pane.theme; font: pane.font
            label: "Lock the palette"
            sublabel: "Keep the current colours while wallpapers keep changing, for example during a slideshow."
            checked: !!pane.cfg.locked
            onToggled: v => pane.set("locked", v)
        }

        SectionHeader {
            theme: pane.theme; font: pane.font
            text: "Brightness"
            sub: "Applies to wallpaper colours. Auto switches by the clock."
        }
        Flow {
            Layout.fillWidth: true
            spacing: 6
            Chip { theme: pane.theme; font: pane.font; icon: "󰖔"; text: "Dark";  selected: (pane.cfg.mode || "dark") === "dark";  onClicked: pane.set("mode", "dark") }
            Chip { theme: pane.theme; font: pane.font; icon: "󰖙"; text: "Light"; selected: pane.cfg.mode === "light"; onClicked: pane.set("mode", "light") }
            Chip { theme: pane.theme; font: pane.font; icon: "󰔎"; text: "Auto";  selected: pane.cfg.mode === "auto";  onClicked: pane.set("mode", "auto") }
        }
        RowLayout {
            visible: pane.cfg.mode === "auto"
            spacing: 24
            Stepper {
                theme: pane.theme; font: pane.font
                label: "Light at"; suffix: ":00"; from: 0; to: 23
                value: pane.cfg.lightFrom === undefined ? 7 : pane.cfg.lightFrom
                onStepped: v => pane.set("lightFrom", v)
            }
            Stepper {
                theme: pane.theme; font: pane.font
                label: "Dark at"; suffix: ":00"; from: 0; to: 23
                value: pane.cfg.darkFrom === undefined ? 19 : pane.cfg.darkFrom
                onStepped: v => pane.set("darkFrom", v)
            }
        }

        SectionHeader {
            theme: pane.theme; font: pane.font
            text: "Character"
            sub: "How matugen turns the wallpaper into a palette."
        }
        GridLayout {
            Layout.fillWidth: true
            columns: pane.width > 900 ? 4 : 2
            columnSpacing: 8
            rowSpacing: 8
            Repeater {
                model: pane.schemes
                delegate: Rectangle {
                    id: sc
                    required property var modelData
                    readonly property bool on: (pane.cfg.scheme || "scheme-tonal-spot") === modelData[0]
                    Layout.fillWidth: true
                    Layout.preferredHeight: 62
                    radius: 10
                    color: on ? pane.theme.bgSelected : (sca.containsMouse ? pane.theme.bgHover : pane.theme.bgSurface)
                    border.width: on ? 2 : 1
                    border.color: on ? pane.theme.accentPrimary : pane.theme.bgBorder
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 2
                        Text {
                            text: sc.modelData[1]
                            color: pane.theme.textPrimary
                            font.family: pane.font
                            font.pixelSize: 12
                            font.bold: true
                        }
                        Text {
                            Layout.fillWidth: true
                            text: sc.modelData[2]
                            color: pane.theme.textMuted
                            font.family: pane.font
                            font.pixelSize: 9
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }
                    MouseArea {
                        id: sca
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pane.set("scheme", sc.modelData[0])
                    }
                }
            }
        }

        SectionHeader {
            theme: pane.theme; font: pane.font
            text: "Contrast"
        }
        Flow {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: [[-0.5, "Soft"], [0, "Standard"], [0.5, "Medium"], [1, "High"]]
                Chip {
                    required property var modelData
                    theme: pane.theme; font: pane.font
                    text: modelData[1]
                    selected: Number(pane.cfg.contrast || 0) === modelData[0]
                    onClicked: pane.set("contrast", modelData[0])
                }
            }
        }

        Toggle {
            theme: pane.theme; font: pane.font
            label: "Theme third-party apps"
            sublabel: "GTK 3 and GTK 4 colours generated with the palette. Off leaves GTK apps stock."
            checked: AequalynSettings.themeApps
            onToggled: v => AequalynSettings.apply("themeApps", v)
        }

        SectionHeader {
            theme: pane.theme; font: pane.font
            text: "Current palette"
        }
        Flow {
            Layout.fillWidth: true
            spacing: 8
            Repeater {
                model: [
                    ["bgBase", "Base"], ["bgSurface", "Surface"], ["bgHover", "Hover"], ["bgSelected", "Selected"],
                    ["bgBorder", "Border"], ["textPrimary", "Text"], ["textSecondary", "Secondary"], ["textMuted", "Muted"],
                    ["accentPrimary", "Primary"], ["accentCyan", "Cyan"], ["accentGreen", "Green"],
                    ["accentOrange", "Orange"], ["accentRed", "Red"]
                ]
                Rectangle {
                    required property var modelData
                    width: 150; height: 46; radius: 8
                    color: pane.theme.bgSurface
                    border.color: pane.theme.bgBorder
                    Row {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8
                        Rectangle {
                            width: 30; height: 30; radius: 6
                            color: pane.theme[modelData[0]]
                            border.color: pane.theme.bgBorder
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                text: modelData[1]
                                color: pane.theme.textPrimary
                                font.family: pane.font
                                font.pixelSize: 11
                                font.bold: true
                            }
                            Text {
                                text: String(pane.theme[modelData[0]]).toUpperCase()
                                color: pane.theme.textMuted
                                font.family: pane.font
                                font.pixelSize: 9
                            }
                        }
                    }
                }
            }
        }
    }
}
