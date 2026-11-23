// Theme: where the desktop's colours come from, a theme (its colours, and its own
// wallpapers when "A theme brings its wallpapers" is on) or the wallpaper (colours made
// from whatever wallpaper is on), the themes themselves, and how wallpaper colours are
// made (Atelier's palette pane).
import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/settings"
import "../../../plugins/atelier"
import "../../../style/BarLooks.js" as BarLooks
import ".."

CcPage {
    id: page
    title: "Theme"
    sub: "Colours and wallpapers that belong together, or colours made from your wallpaper. Super + T picks one from anywhere."
    tabs: ["Themes", "How colours are made"]

    readonly property var svc: AtelierHost.docks
    // the themes with their own colours and wallpapers, as the picker lists them
    readonly property var themes: (Cc.theme && Cc.theme.folderThemes ? Cc.theme.folderThemes : [])
        .filter(f => f.hasPalette && (f.backgrounds || []).length > 0)
    readonly property var current: Cc.theme && Cc.theme.currentFolderId ? Cc.theme.folderTheme(Cc.theme.currentFolderId) : null

    // your desktop in these colours: the bar, docks and windows as they are
    stageHeight: 190
    stage: Stage {
        anchors.fill: parent
        theme: Cc.theme
        font: Cc.mono
        wallpaper: Cc.wallpaper
        barLook: BarLooks.clean(AequalynSettings.barStyleCfg)
        barSize: Math.round(AequalynSettings.barHeight * 0.75)
        docks: page.svc && AequalynSettings.dockEnabled ? page.svc.docks.map((d, i) => {
            const e = page.svc.effective(i);
            return { look: e, pal: page.svc.palette(e), edge: d.edge, icons: Math.max(3, Math.min(6, d.apps.length)) };
        }) : []
    }

    actions: [
        CcButton {
            text: "Browse themes"; icon: "\u{F03D8}"; primary: true
            onClicked: Cc.ipc(["atelier", "open", "themes"], true)
        }
    ]

    // ---- where the colours come from ------------------------------------------------------
    CcSection {
        visible: page.tab === 0
        title: "Colours come from"
        hint: Cc.theme.wallpaperMode ? "Every new wallpaper repaints the desktop, apps and terminals."
                                     : "The theme's own colours, whatever the wallpaper."
        CcChoice {
            options: [{ key: "theme", label: "The theme" }, { key: "wallpaper", label: "The wallpaper" }]
            current: Cc.theme.wallpaperMode ? "wallpaper" : "theme"
            onChosen: key => {
                if (key === "wallpaper") { Cc.theme.setWallpaperMode(); AequalynSettings.retheme(); }
                else Cc.theme.useThemeColours(Cc.theme.currentFolderId);
            }
        }
    }
    CcToggle {
        visible: page.tab === 0
        title: "A theme brings its wallpapers"
        sub: "On: picking a theme also puts on its first wallpaper. Off: only its colours; your wallpaper stays."
        checked: AequalynSettings.atelierCfg.themeWallpapers !== false
        onToggled: v => AequalynSettings.setIn("atelier", "themeWallpapers", v)
    }

    // ---- the themes -----------------------------------------------------------------------
    CcSection {
        visible: page.tab === 0
        title: "Your themes"
        hint: Cc.theme.wallpaperMode ? "Picking one goes back to a theme's colours."
            : page.current ? page.current.name + " is on, with " + page.current.backgrounds.length
                             + (page.current.backgrounds.length === 1 ? " wallpaper." : " wallpapers.") : ""
        GridLayout {
            Layout.fillWidth: true
            columns: Math.max(2, Math.floor(width / 200))
            columnSpacing: 10
            rowSpacing: 10
            Repeater {
                model: page.themes
                delegate: Rectangle {
                    id: tile
                    required property var modelData
                    readonly property bool on: !Cc.theme.wallpaperMode && page.current && page.current.id === modelData.id
                    Layout.fillWidth: true
                    implicitHeight: 150
                    radius: 14
                    color: on ? Cc.alpha(Cc.theme.accentPrimary, 0.14) : (tileArea.containsMouse ? Cc.theme.bgHover : Cc.theme.bgSurface)
                    border.width: 2
                    border.color: on ? Cc.theme.accentPrimary : "transparent"
                    Accessible.role: Accessible.RadioButton
                    Accessible.name: modelData.name
                    Accessible.checked: on

                    Image {
                        id: shot
                        x: 8; y: 8
                        width: parent.width - 16
                        height: 96
                        source: "file://" + (tile.modelData.preview || tile.modelData.backgrounds[0])
                        sourceSize: Qt.size(400, 240)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        clip: true
                    }
                    // its colours, on the picture
                    Row {
                        anchors.left: shot.left
                        anchors.bottom: shot.bottom
                        anchors.margins: 6
                        spacing: 3
                        Repeater {
                            model: ["bgBase", "accentPrimary", "accentCyan", "accentGreen", "accentOrange", "accentRed"]
                            delegate: Rectangle {
                                required property string modelData
                                width: 12; height: 12; radius: 3
                                color: tile.modelData[modelData] || "transparent"
                                border.width: 1
                                border.color: Qt.rgba(0, 0, 0, 0.35)
                            }
                        }
                    }
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.right: count.left
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 12
                        text: tile.modelData.name
                        elide: Text.ElideRight
                        color: Cc.theme.textPrimary
                        font.family: Cc.sans
                        font.pixelSize: 13
                        font.weight: tile.on ? Font.DemiBold : Font.Normal
                    }
                    Text {
                        id: count
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 13
                        text: tile.modelData.backgrounds.length + " \u{F0E09}"
                        color: Cc.theme.textMuted
                        font.family: Cc.mono
                        font.pixelSize: 11
                    }
                    MouseArea {
                        id: tileArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Cc.theme.setFolderTheme(tile.modelData.id)
                    }
                }
            }
        }
        CcNote {
            visible: page.themes.length === 0
            text: "No themes found. A theme is a folder with a theme.json and a backgrounds folder."
        }
    }

    CcSection {
        visible: page.tab === 0
        CcToggle {
            setting: "themeApps"
            title: "Apps use these colours too"
            sub: "Files, settings windows and other GTK apps match your desktop. Off leaves them as they come."
        }
        CcToggle {
            title: "Show each theme on the whole desktop while choosing"
            sub: "In the picker, the bar, dock and windows take the colours of the theme you are on until you pick one or close it."
            checked: AequalynSettings.atelierCfg.livePreview !== false
            onToggled: v => AequalynSettings.setIn("atelier", "livePreview", v)
        }
        CcToggle {
            setting: "themeBrowser"
            title: "Browsers use these colours too"
            sub: "Chromium, Chrome, Brave and Edge take the bar's base colour from a managed policy. Off removes it. Each colour change asks for admin permission."
        }
    }
    CcMore {
        visible: page.tab === 0
        title: "Add your own theme"
        CcNote {
            text: "A theme is a folder in ~/.config/aequalyn/themes: a theme.json with its name and colours, and a backgrounds folder with one or more wallpapers. It shows here and in Super + T as soon as it is there."
        }
        CcButton {
            text: "Open the themes folder"; icon: "\u{F024B}"
            onClicked: Cc.run(["sh", "-c", "mkdir -p \"$HOME/.config/aequalyn/themes\" && xdg-open \"$HOME/.config/aequalyn/themes\""])
        }
    }

    // ---- how wallpaper colours are made --------------------------------------------------
    Loader {
        visible: page.tab === 1
        active: page.opened(1)
        Layout.fillWidth: true
        Layout.preferredHeight: item ? item.contentHeight : 0
        sourceComponent: Component {
            PalettePane {
                interactive: false
                theme: Cc.theme
                font: Cc.mono
            }
        }
    }
}
