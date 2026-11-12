// Rotation: how the wallpaper changes. Six modes as cards, then the
// options of the selected mode, then transitions and generated wallpapers.
import QtQuick
import QtQuick.Layouts
import "controls"
import "root:/settings"

Flickable {
    id: pane
    property var theme
    property string font: "JetBrainsMono Nerd Font"

    readonly property var cfg: AequalynSettings.wallpaperCfg
    readonly property string mode: cfg.mode || "static"

    function set(key, value) { AequalynSettings.setIn("wallpaper", key, value); }

    contentHeight: column.implicitHeight + 24
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    ColumnLayout {
        id: column
        width: pane.width
        spacing: 12

        SectionHeader {
            theme: pane.theme; font: pane.font
            text: "Mode"
            sub: "Pick how wallpapers change. Each mode works from Atelier, a keybind or the aequalyn-wallpaper command."
        }

        GridLayout {
            Layout.fillWidth: true
            columns: pane.width > 900 ? 3 : 2
            columnSpacing: 10
            rowSpacing: 10

            Repeater {
                model: AtelierService.modes
                delegate: Rectangle {
                    id: modeCard
                    required property var modelData
                    readonly property bool on: pane.mode === modelData.key
                    Layout.fillWidth: true
                    Layout.preferredHeight: 86
                    radius: 12
                    color: on ? pane.theme.bgSelected : (ma.containsMouse ? pane.theme.bgHover : pane.theme.bgSurface)
                    border.width: on ? 2 : 1
                    border.color: on ? pane.theme.accentPrimary : pane.theme.bgBorder
                    Behavior on color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 14
                        Rectangle {
                            Layout.preferredWidth: 44
                            Layout.preferredHeight: 44
                            radius: 12
                            color: modeCard.on ? pane.theme.accentPrimary : pane.theme.bgBase
                            Text {
                                anchors.centerIn: parent
                                text: modeCard.modelData.icon
                                color: modeCard.on ? pane.theme.bgBase : pane.theme.accentPrimary
                                font.family: pane.font
                                font.pixelSize: 20
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            Text {
                                text: modeCard.modelData.name
                                color: pane.theme.textPrimary
                                font.family: pane.font
                                font.pixelSize: 13
                                font.bold: true
                            }
                            Text {
                                Layout.fillWidth: true
                                text: modeCard.modelData.text
                                color: pane.theme.textMuted
                                font.family: pane.font
                                font.pixelSize: 10
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }
                        }
                    }
                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: AtelierService.setMode(modeCard.modelData.key)
                    }
                }
            }
        }

        // ---- Source folder (all modes but theme) --------------------------
        SectionHeader {
            visible: pane.mode !== "theme"
            theme: pane.theme; font: pane.font
            text: "Folder"
            sub: pane.mode === "daytime"
                 ? "Put images in dawn/, day/, dusk/ and night/ subfolders, or put the phase in the file name."
                 : pane.mode === "live" ? "Videos (mp4, webm, mkv, mov) in this folder."
                 : "Images in this folder and up to two levels below it."
        }
        Rectangle {
            visible: pane.mode !== "theme"
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            radius: 8
            color: pane.theme.bgSurface
            border.color: folderInput.activeFocus ? pane.theme.accentPrimary : pane.theme.bgBorder
            TextInput {
                id: folderInput
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: TextInput.AlignVCenter
                text: pane.cfg.folder || "~/Pictures/Wallpapers"
                color: pane.theme.textPrimary
                font.family: pane.font
                font.pixelSize: 12
                selectByMouse: true
                clip: true
                onEditingFinished: if (text !== pane.cfg.folder) { pane.set("folder", text); AtelierService.refreshLater(); }
            }
        }

        // ---- Slideshow -----------------------------------------------------
        SectionHeader {
            visible: pane.mode === "slideshow"
            theme: pane.theme; font: pane.font
            text: "Every"
        }
        Flow {
            visible: pane.mode === "slideshow"
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: [[5, "5 min"], [15, "15 min"], [30, "30 min"], [60, "1 hour"], [180, "3 hours"], [720, "12 hours"], [1440, "1 day"]]
                Chip {
                    required property var modelData
                    theme: pane.theme; font: pane.font
                    text: modelData[1]
                    selected: Number(pane.cfg.interval) === modelData[0]
                    onClicked: pane.set("interval", modelData[0])
                }
            }
        }
        Flow {
            visible: pane.mode === "slideshow" || pane.mode === "theme"
            Layout.fillWidth: true
            spacing: 6
            Chip { theme: pane.theme; font: pane.font; icon: "󰒟"; text: "Shuffle"; selected: pane.cfg.order === "shuffle"; onClicked: pane.set("order", "shuffle") }
            Chip { theme: pane.theme; font: pane.font; icon: "󰒿"; text: "In order"; selected: pane.cfg.order === "sequential"; onClicked: pane.set("order", "sequential") }
        }

        // ---- Time of day ---------------------------------------------------
        SectionHeader {
            visible: pane.mode === "daytime"
            theme: pane.theme; font: pane.font
            text: "Phases"
            sub: "Now: " + (AtelierService.status.phase || "") + ". Each phase starts at the hour shown."
        }
        GridLayout {
            visible: pane.mode === "daytime"
            columns: 2
            columnSpacing: 24
            rowSpacing: 6
            Repeater {
                model: [["dawn", "Dawn"], ["day", "Day"], ["dusk", "Dusk"], ["night", "Night"]]
                Stepper {
                    required property var modelData
                    theme: pane.theme; font: pane.font
                    label: modelData[1]
                    suffix: ":00"
                    from: 0; to: 23
                    value: (pane.cfg.daytime || {})[modelData[0]] || 0
                    onStepped: v => {
                        const d = Object.assign({}, pane.cfg.daytime || {});
                        d[modelData[0]] = v;
                        pane.set("daytime", d);
                    }
                }
            }
        }

        // ---- Workspaces ----------------------------------------------------
        SectionHeader {
            visible: pane.mode === "workspace"
            theme: pane.theme; font: pane.font
            text: "Workspaces"
            sub: "Workspaces without an assignment get their own pick from the folder. In Wallpapers, Enter assigns the selection to workspace " + AtelierService.focusedWorkspace + "."
        }
        Toggle {
            visible: pane.mode === "workspace"
            theme: pane.theme; font: pane.font
            label: "Recolour on every switch"
            sublabel: "Regenerate the palette for each workspace's wallpaper. Off keeps one palette and switches faster."
            checked: !!pane.cfg.workspacePalette
            onToggled: v => pane.set("workspacePalette", v)
        }

        // ---- Live ----------------------------------------------------------
        SectionHeader {
            visible: pane.mode === "live"
            theme: pane.theme; font: pane.font
            text: "Playback"
            sub: "Colours come from a still frame of the video. Needs mpvpaper and ffmpeg."
        }
        Flow {
            visible: pane.mode === "live"
            Layout.fillWidth: true
            spacing: 6
            Chip {
                theme: pane.theme; font: pane.font; text: "Fill"
                selected: (pane.cfg.liveOptions || "").indexOf("panscan=1.0") >= 0
                onClicked: pane.set("liveOptions", "no-audio loop panscan=1.0 hwdec=auto")
            }
            Chip {
                theme: pane.theme; font: pane.font; text: "Fit"
                selected: (pane.cfg.liveOptions || "").indexOf("panscan=1.0") < 0
                onClicked: pane.set("liveOptions", "no-audio loop hwdec=auto")
            }
        }

        // ---- Monitors ------------------------------------------------------
        SectionHeader {
            visible: pane.mode !== "live" && pane.mode !== "workspace"
            theme: pane.theme; font: pane.font
            text: "Monitors"
        }
        Flow {
            visible: pane.mode !== "live" && pane.mode !== "workspace"
            Layout.fillWidth: true
            spacing: 6
            Chip { theme: pane.theme; font: pane.font; icon: "󰍹"; text: "Same everywhere"; selected: pane.cfg.outputs !== "different"; onClicked: pane.set("outputs", "same") }
            Chip { theme: pane.theme; font: pane.font; icon: "󰍺"; text: "Different per monitor"; selected: pane.cfg.outputs === "different"; onClicked: pane.set("outputs", "different") }
        }

        // ---- Transition ----------------------------------------------------
        SectionHeader {
            theme: pane.theme; font: pane.font
            text: "Transition"
        }
        Flow {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: [["fade", "Fade"], ["wipe", "Wipe"], ["wave", "Wave"], ["grow", "Grow"], ["outer", "Shrink"], ["center", "Centre"], ["left", "Slide"], ["simple", "Cut"], ["random", "Surprise me"]]
                Chip {
                    required property var modelData
                    theme: pane.theme; font: pane.font
                    text: modelData[1]
                    selected: (pane.cfg.transition || "fade") === modelData[0]
                    onClicked: pane.set("transition", modelData[0])
                }
            }
        }
        Stepper {
            theme: pane.theme; font: pane.font
            label: "Duration"
            suffix: " s"
            from: 0.2; to: 5; step: 0.2
            value: Number(pane.cfg.transitionDuration || 1)
            onStepped: v => pane.set("transitionDuration", v)
        }

        // ---- Generated -----------------------------------------------------
        SectionHeader {
            theme: pane.theme; font: pane.font
            text: "Paint one from the palette"
            sub: "A wallpaper made from the current colours, sized to your largest monitor. Needs ImageMagick."
        }
        Flow {
            Layout.fillWidth: true
            spacing: 6
            Chip { theme: pane.theme; font: pane.font; icon: "󰝤"; text: "Solid";    onClicked: AtelierService.generate("solid") }
            Chip { theme: pane.theme; font: pane.font; icon: "󰗘"; text: "Gradient"; onClicked: AtelierService.generate("gradient") }
            Chip { theme: pane.theme; font: pane.font; icon: "󰖙"; text: "Aurora";   onClicked: AtelierService.generate("aurora") }
            Chip { theme: pane.theme; font: pane.font; icon: "󰖚"; text: "Dusk";     onClicked: AtelierService.generate("dusk") }
        }
    }
}
