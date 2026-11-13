// Settings panel UI (Aequalyn settings window/overlay).
// Tabbed interface for configuring appearance, top bar/plugins, Hyprland,
// bluetooth, displays, dock, power, and about/keybind info. Edits flow through
// AequalynSettings (which persists and triggers apply scripts where needed), and
// the panel is controlled via IPC (target "aequalyn"/settings actions).

// Aequalyn Settings -- one page for the shell and for Hyprland customisations.
// Open with `qs ipc call aequalyn settings` (bound to SUPER + comma by default).
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "root:/settings"
import "root:/bluetooth"
import "root:/wifi"

Scope {
    id: root
    property var theme: AequalynDefaultTheme {}
    property bool panelVisible: false
    property string tab: "appearance"
    property string font: "JetBrainsMono Nerd Font"
    readonly property string version: "0.1.0"
    property string exportStatus: ""
    property bool hasExportFiles: false
    property string detectedExportFile: ""

    function refreshExportFiles() {
        if (!detectExportProc.running) detectExportProc.running = true
    }

    Component.onCompleted: refreshExportFiles()
    onPanelVisibleChanged: if (panelVisible) refreshExportFiles()

    property var tabs: [
        { key: "appearance", label: "Appearance" },
        { key: "bar",        label: "Top bar" },
        { key: "hyprland",   label: "Hyprland" },
        { key: "bluetooth",  label: "Bluetooth" },
        { key: "wifi",       label: "Wi-Fi" },
        { key: "displays",   label: "Displays" },
        { key: "dock",       label: "Dock" },
        { key: "power",      label: "Power" },
        { key: "about",      label: "About" }
    ]

    IpcHandler {
        target: "aequalyn"
        function settings(): void { root.panelVisible = !root.panelVisible }
        function openSettings(): void { root.panelVisible = true }
        function closeSettings(): void { root.panelVisible = false }
        function appearance(): void { root.tab = "appearance"; root.panelVisible = true }
        function bar(): void { root.tab = "bar"; root.panelVisible = true }
        function displays(): void { root.tab = "displays"; root.panelVisible = true }
        function bluetooth(): void { root.tab = "bluetooth"; root.panelVisible = true }
        function wifi(): void { root.tab = "wifi"; root.panelVisible = true }
        function hyprland(): void { root.tab = "hyprland"; root.panelVisible = true }
        function dock(): void { root.tab = "dock"; root.panelVisible = true }
        function power(): void { root.tab = "power"; root.panelVisible = true }
    }

    // ------------------------------------------------------- Bluetooth audio --
    // PipeWire-Pulse card profiles for connected headsets (A2DP / HSP-HFP).
    property var audioCards: []
    property string audioMessage: ""

    // Wi-Fi password prompt state
    property string wifiPasswordSsid: ""
    property string wifiPasswordText: ""

    function connectWifiWithPassword() {
        const net = WifiService.networkForSsid(root.wifiPasswordSsid)
        if (net) WifiService.connectWithPsk(net, root.wifiPasswordText)
        root.wifiPasswordSsid = ""
        root.wifiPasswordText = ""
    }

    function refreshAudio() {
        if (!audioListProc.running) audioListProc.running = true
    }

    function setAudioProfile(card, profile) {
        audioSetProc.command = ["aequalyn-bluetooth-audio", "set", card, profile]
        audioSetProc.running = true
        root.audioMessage = "Switching to " + profile + "…"
        audioRefreshTimer.restart()
    }

    onTabChanged: {
        if (root.tab === "bluetooth") root.refreshAudio()
        if (root.tab === "wifi") { WifiService.scan(); wifiScanTimer.restart() }
    }

    Timer {
        id: wifiScanTimer
        interval: 3000
        repeat: false
        onTriggered: WifiService.setScanning(false)
    }

    Timer {
        interval: 5000
        repeat: true
        running: root.tab === "wifi" && root.panelVisible
        onTriggered: WifiService.scan()
    }

    Process {
        id: audioListProc
        running: false
        command: ["aequalyn-bluetooth-audio", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text)
                    root.audioCards = d.cards || []
                } catch (e) {
                    root.audioCards = []
                }
            }
        }
    }

    Process {
        id: audioSetProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.audioMessage = text.trim() === "ok" ? "Profile applied." : "Could not apply profile."
                root.refreshAudio()
            }
        }
    }

    Timer {
        id: audioRefreshTimer
        interval: 1200
        repeat: false
        onTriggered: root.refreshAudio()
    }

    Timer {
        interval: 6000
        repeat: true
        running: root.tab === "bluetooth" && root.panelVisible
        onTriggered: root.refreshAudio()
    }

    // ---------------------------------------------------------------- shared UI
    component ToggleSwitch: Rectangle {
        id: sw
        property bool checked: false
        signal toggled()
        implicitWidth: 38
        implicitHeight: 21
        radius: 11
        color: sw.checked ? root.theme.accentPrimary : root.theme.bgSelected
        border.color: root.theme.bgBorder
        border.width: 1
        Behavior on color { ColorAnimation { duration: 120 } }
        Rectangle {
            width: 15; height: 15; radius: 8
            color: sw.checked ? root.theme.bgBase : root.theme.textPrimary
            anchors.verticalCenter: parent.verticalCenter
            x: sw.checked ? parent.width - width - 3 : 3
            Behavior on x { NumberAnimation { duration: 120 } }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: sw.toggled()
        }
    }

    component ToggleRow: RowLayout {
        id: tr
        property string label: ""
        property string sublabel: ""
        property bool checked: false
        property string settingKey: ""
        Layout.fillWidth: true
        spacing: 8
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text {
                text: tr.label
                color: root.theme.textPrimary
                font.pixelSize: 12
                font.family: root.font
                Layout.fillWidth: true
            }
            Text {
                visible: tr.sublabel !== ""
                text: tr.sublabel
                color: root.theme.textMuted
                font.pixelSize: 10
                font.family: root.font
                Layout.fillWidth: true
            }
        }
        ToggleSwitch {
            checked: tr.checked
            onToggled: AequalynSettings.apply(tr.settingKey, !tr.checked)
        }
    }

    component StepperRow: ColumnLayout {
        id: sr
        property string label: ""
        property string settingKey: ""
        property real minValue: 0
        property real maxValue: 100
        property real stepValue: 1
        property bool decimals: false
        Layout.fillWidth: true
        spacing: 6
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: sr.label
                color: root.theme.textPrimary
                font.pixelSize: 12
                font.family: root.font
                Layout.fillWidth: true
            }
            Text {
                text: sr.decimals ? Number(AequalynSettings[sr.settingKey]).toFixed(2)
                                  : AequalynSettings[sr.settingKey]
                color: root.theme.accentPrimary
                font.pixelSize: 12
                font.family: root.font
                font.bold: true
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Rectangle {
                implicitWidth: 26; implicitHeight: 24; radius: 6
                color: root.theme.bgSurface
                Text { anchors.centerIn: parent; text: "−"; color: root.theme.textPrimary; font.pixelSize: 14; font.family: root.font }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: AequalynSettings.apply(sr.settingKey,
                        Math.max(sr.minValue, AequalynSettings[sr.settingKey] - sr.stepValue))
                }
            }
            Rectangle {
                Layout.fillWidth: true; implicitHeight: 6; radius: 3
                color: root.theme.bgSurface
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1,
                        (AequalynSettings[sr.settingKey] - sr.minValue) / (sr.maxValue - sr.minValue)))
                    height: parent.height; radius: 3
                    color: root.theme.accentPrimary
                }
            }
            Rectangle {
                implicitWidth: 26; implicitHeight: 24; radius: 6
                color: root.theme.bgSurface
                Text { anchors.centerIn: parent; text: "+"; color: root.theme.textPrimary; font.pixelSize: 14; font.family: root.font }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: AequalynSettings.apply(sr.settingKey,
                        Math.min(sr.maxValue, AequalynSettings[sr.settingKey] + sr.stepValue))
                }
            }
        }
    }

    component ChoiceRow: Flow {
        id: cr
        property var options: []
        property string current: ""
        property string settingKey: ""
        signal chosen(string key)
        Layout.fillWidth: true
        spacing: 8
        Repeater {
            model: cr.options
            Rectangle {
                required property var modelData
                implicitWidth: choiceText.implicitWidth + 20
                implicitHeight: 28
                radius: 7
                color: cr.current === modelData.key ? root.theme.accentPrimary : root.theme.bgSurface
                border.color: root.theme.bgBorder
                border.width: 1
                Text {
                    id: choiceText
                    anchors.centerIn: parent
                    text: modelData.label
                    color: cr.current === modelData.key ? root.theme.bgBase : root.theme.textSecondary
                    font.pixelSize: 11
                    font.family: root.font
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: AequalynSettings.apply(cr.settingKey, modelData.key)
                }
            }
        }
    }

    component ActionButton: Rectangle {
        id: ab
        property string label: ""
        property string hint: ""
        signal clicked()
        implicitWidth: Math.max(150, abRow.implicitWidth + 28)
        implicitHeight: 34
        radius: 8
        color: abHover.containsMouse ? root.theme.accentPrimary : root.theme.bgSelected
        border.color: root.theme.bgBorder
        border.width: 1
        Behavior on color { ColorAnimation { duration: 120 } }
        Row {
            id: abRow
            anchors.centerIn: parent
            spacing: 8
            Text {
                text: ab.label
                color: abHover.containsMouse ? root.theme.bgBase : root.theme.textPrimary
                font.pixelSize: 11
                font.family: root.font
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                visible: ab.hint !== ""
                text: ab.hint
                color: abHover.containsMouse ? root.theme.bgBase : root.theme.textMuted
                font.pixelSize: 10
                font.family: root.font
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        MouseArea {
            id: abHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ab.clicked()
        }
    }

    component SectionTitle: Text {
        color: root.theme.accentPrimary
        font.pixelSize: 13
        font.bold: true
        font.family: root.font
    }
    component SubLabel: Text {
        color: root.theme.textMuted
        font.pixelSize: 10
        font.family: root.font
        Layout.fillWidth: true
        Layout.rightMargin: 16
        rightPadding: 12
        wrapMode: Text.WordWrap
    }
    component Divider: Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: root.theme.bgBorder
    }

    // ---------------------------------------------------------------- window
    PanelWindow {
        id: win
        visible: root.panelVisible
        // Never leave the page non-scrollable if the panel closes mid-drag.
        onVisibleChanged: if (!visible) flick.interactive = true
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "aequalyn-settings"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }

        Item {
            anchors.fill: parent
            focus: win.visible
            Keys.onEscapePressed: root.panelVisible = false

            MouseArea {
                anchors.fill: parent
                onClicked: root.panelVisible = false
                Rectangle { anchors.fill: parent; color: root.theme.bgOverlay }
            }

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(980, parent.width * 0.94)
                height: Math.min(680, parent.height * 0.92)
                radius: 16
                color: root.theme.bgBase
                border.color: root.theme.bgBorder
                border.width: 1
                MouseArea { anchors.fill: parent; onClicked: {} }

                Row {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 18

                    // ---- sidebar ----
                    ColumnLayout {
                        width: 168
                        height: parent.height
                        spacing: 6
                        Text {
                            text: "  AEQUALYN"
                            color: root.theme.accentPrimary
                            font.pixelSize: 20
                            font.bold: true
                            font.family: root.font
                            Layout.bottomMargin: 4
                        }
                        Text {
                            text: "settings"
                            color: root.theme.textMuted
                            font.pixelSize: 11
                            font.family: root.font
                            Layout.bottomMargin: 12
                        }
                        Repeater {
                            model: root.tabs
                            Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: 34
                                radius: 8
                                color: root.tab === modelData.key ? root.theme.accentPrimary
                                     : (tabHover.containsMouse ? root.theme.bgHover : "transparent")
                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.label
                                    color: root.tab === modelData.key ? root.theme.bgBase : root.theme.textSecondary
                                    font.pixelSize: 12
                                    font.family: root.font
                                    font.bold: root.tab === modelData.key
                                }
                                MouseArea {
                                    id: tabHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.tab = modelData.key
                                }
                            }
                        }
                        Item { Layout.fillHeight: true }
                        Text {
                            text: "v" + root.version + "\nesc to close"
                            color: root.theme.textMuted
                            font.pixelSize: 9
                            font.family: root.font
                        }
                    }

                    Rectangle { width: 1; height: parent.height; color: root.theme.bgBorder }

                    // ---- content ----
                    Flickable {
                        id: flick
                        // 24 px of right padding: the Row leaves the leftover
                        // space at the right edge so long text is never cut off.
                        width: parent.width - 168 - 1 - 18 - 24
                        height: parent.height
                        contentWidth: width
                        contentHeight: col.implicitHeight + 24
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        ColumnLayout {
                            id: col
                            width: flick.width - 20
                            spacing: 16

                            // ============ APPEARANCE ============
                            ColumnLayout {
                                Layout.fillWidth: true
                                visible: root.tab === "appearance"
                                spacing: 12
                                SectionTitle { text: "Theme" }
                                SubLabel { text: "Aequalyn extracts a Material 3 palette from your wallpaper with matugen and applies it systemwide: shell, Hyprland, GTK, Qt, terminals and btop." }

                                SubLabel { text: "Themes, wallpapers, rotation (slideshow, time of day, per workspace, live) and palette options all live in Atelier." }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 12
                                    ActionButton {
                                        label: "Themes"
                                        hint: "SUPER+T"
                                        onClicked: { root.panelVisible = false; qsIpc.command = ["qs", "ipc", "call", "atelier", "open", "themes"]; qsIpc.running = true }
                                    }
                                    ActionButton {
                                        label: "Wallpapers"
                                        hint: "SUPER+W"
                                        onClicked: { root.panelVisible = false; qsIpc.command = ["qs", "ipc", "call", "atelier", "open", "wallpapers"]; qsIpc.running = true }
                                    }
                                    ActionButton {
                                        label: "Rotation"
                                        hint: "SUPER+SHIFT+W"
                                        onClicked: { root.panelVisible = false; qsIpc.command = ["qs", "ipc", "call", "atelier", "open", "rotation"]; qsIpc.running = true }
                                    }
                                    ActionButton {
                                        label: "Palette"
                                        onClicked: { root.panelVisible = false; qsIpc.command = ["qs", "ipc", "call", "atelier", "open", "palette"]; qsIpc.running = true }
                                    }
                                    ActionButton {
                                        label: "Bar look"
                                        onClicked: { root.panelVisible = false; qsIpc.command = ["qs", "ipc", "call", "atelier", "open", "bar"]; qsIpc.running = true }
                                    }
                                    ActionButton {
                                        label: "Regenerate colours"
                                        onClicked: AequalynSettings.retheme()
                                    }
                                }

                                Divider {}
                                SectionTitle { text: "Application theming" }
                                ToggleRow {
                                    label: "Theme third-party apps"
                                    sublabel: "GTK 3 / GTK 4 CSS generated by matugen. Turn off to leave GTK apps stock."
                                    checked: AequalynSettings.themeApps
                                    settingKey: "themeApps"
                                }

                                Divider {}
                                SectionTitle { text: "Clock" }
                                ToggleRow {
                                    label: "24-hour clock"
                                    checked: AequalynSettings.use24h
                                    settingKey: "use24h"
                                }
                                ToggleRow {
                                    label: "Show seconds"
                                    checked: AequalynSettings.clockSeconds
                                    settingKey: "clockSeconds"
                                }

                                // Live swatches from the last generated palette
                                Divider {}
                                SectionTitle { text: "Current palette" }
                                Row {
                                    spacing: 8
                                    Repeater {
                                        model: [root.theme.bgBase, root.theme.bgSurface, root.theme.bgSelected,
                                                root.theme.textPrimary, root.theme.textSecondary,
                                                root.theme.accentPrimary, root.theme.accentCyan,
                                                root.theme.accentGreen, root.theme.accentOrange, root.theme.accentRed]
                                        Rectangle {
                                            required property var modelData
                                            width: 32; height: 32; radius: 8
                                            color: modelData
                                            border.color: root.theme.bgBorder
                                            border.width: 1
                                        }
                                    }
                                }
                            }

                            // ============ BAR ============
                            ColumnLayout {
                                Layout.fillWidth: true
                                visible: root.tab === "bar"
                                spacing: 12
                                SectionTitle { text: "Top bar" }
                                StepperRow {
                                    label: "Bar height"; settingKey: "barHeight"
                                    minValue: 24; maxValue: 48; stepValue: 2
                                }
                                StepperRow {
                                    label: "Bar opacity"; settingKey: "barOpacity"
                                    minValue: 40; maxValue: 100; stepValue: 5
                                }
                                Divider {}
                                SectionTitle { text: "Arrange plugins" }
                                SubLabel { text: "Drag plugins to reorder them or move them between Left, Center, and Right bar regions. The Arch apps-menu stays at the far left and the settings gear at the far right." }

                                Item {
                                    id: barArrange
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Math.max(420, Math.max(AequalynSettings.barLeft.length, AequalynSettings.barCenter.length, AequalynSettings.barRight.length) * 34 + 60)
                                    property int rowH: 34
                                    property string dragRegion: ""
                                    property int dragIndex: -1
                                    property string dragLabel: ""
                                    property string hoverRegion: ""
                                    property int hoverIndex: -1
                                    property bool dragging: dragRegion !== ""
                                    property var regions: ["left", "center", "right"]
                                    property var regionLabels: ({ left: "Left", center: "Center", right: "Right" })

                                    function regionModel(name) {
                                        if (name === "left") return AequalynSettings.barLeft
                                        if (name === "center") return AequalynSettings.barCenter
                                        return AequalynSettings.barRight
                                    }

                                    function endDrag(commit) {
                                        if (commit && dragging && hoverRegion !== "") {
                                            AequalynSettings.moveBarPlugin(dragRegion, dragIndex, hoverRegion, hoverIndex)
                                        }
                                        dragRegion = ""; dragIndex = -1; dragLabel = ""
                                        hoverRegion = ""; hoverIndex = -1
                                        dragGhost.visible = false
                                        flick.interactive = true
                                    }

                                    Row {
                                        id: regionRow
                                        anchors.fill: parent
                                        spacing: 10

                                        Repeater {
                                            id: regionRepeater
                                            model: barArrange.regions
                                            delegate: Rectangle {
                                                id: regionBox
                                                required property string modelData
                                                required property int index
                                                property string regionName: modelData
                                                width: (regionRow.width - 20) / 3
                                                height: regionRow.height
                                                radius: 10
                                                color: root.theme.bgSurface
                                                border.color: (barArrange.dragging && barArrange.hoverRegion === regionName) ? root.theme.accentPrimary : root.theme.bgBorder
                                                border.width: 1

                                                Column {
                                                    id: regionCol
                                                    anchors.fill: parent
                                                    anchors.margins: 8
                                                    spacing: 6

                                                    Text {
                                                        text: barArrange.regionLabels[regionName]
                                                        color: root.theme.textSecondary
                                                        font.pixelSize: 11
                                                        font.family: root.font
                                                        font.bold: true
                                                    }

                                                    Rectangle { width: parent.width; height: 1; color: root.theme.bgBorder }

                                                    Item {
                                                        id: listArea
                                                        width: parent.width
                                                        height: regionBox.height - 50
                                                        clip: true

                                                        Column {
                                                            id: itemCol
                                                            width: parent.width
                                                            spacing: 4
                                                            Repeater {
                                                                id: itemRepeater
                                                                model: barArrange.regionModel(regionName)
                                                                delegate: Rectangle {
                                                                    id: pluginItem
                                                                    required property string modelData
                                                                    required property int index
                                                                    width: itemCol.width
                                                                    height: 30
                                                                    radius: 7
                                                                    color: (barArrange.dragging && barArrange.dragRegion === regionName && barArrange.dragIndex === index)
                                                                        ? root.theme.bgSelected : root.theme.bgBase
                                                                    border.color: root.theme.bgBorder
                                                                    border.width: 1
                                                                    opacity: (barArrange.dragging && barArrange.dragRegion === regionName && barArrange.dragIndex === index) ? 0.5 : 1.0

                                                                    RowLayout {
                                                                        anchors.fill: parent
                                                                        anchors.leftMargin: 8
                                                                        anchors.rightMargin: 8
                                                                        spacing: 6
                                                                        Text {
                                                                            text: "≡"
                                                                            color: root.theme.textMuted
                                                                            font.pixelSize: 13
                                                                            font.family: root.font
                                                                        }
                                                                        Text {
                                                                            Layout.fillWidth: true
                                                                            text: AequalynSettings.pluginLabels[modelData] || modelData
                                                                            color: root.theme.textPrimary
                                                                            font.pixelSize: 11
                                                                            font.family: root.font
                                                                            elide: Text.ElideRight
                                                                        }
                                                                        Text {
                                                                            visible: !AequalynSettings.pluginVisible(modelData)
                                                                            text: "hidden"
                                                                            color: root.theme.textMuted
                                                                            font.pixelSize: 9
                                                                            font.family: root.font
                                                                        }
                                                                    }
                                                                }
                                                            }

                                                            // empty-region drop hint
                                                            Text {
                                                                visible: barArrange.regionModel(regionName).length === 0
                                                                width: parent.width
                                                                height: 28
                                                                horizontalAlignment: Text.AlignHCenter
                                                                verticalAlignment: Text.AlignVCenter
                                                                text: "Drop plugins here"
                                                                color: root.theme.textMuted
                                                                font.pixelSize: 10
                                                                font.family: root.font
                                                            }
                                                        }

                                                        // Drop indicator line
                                                        Rectangle {
                                                            id: dropLine
                                                            visible: barArrange.dragging && barArrange.hoverRegion === regionName
                                                            width: parent.width
                                                            height: 2
                                                            color: root.theme.accentPrimary
                                                            y: Math.max(0, Math.min(listArea.height - 2, barArrange.hoverIndex * 34))
                                                            z: 5
                                                        }

                                                        MouseArea {
                                                            anchors.fill: parent
                                                            preventStealing: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onPressed: (mouse) => {
                                                                flick.interactive = false
                                                                const model = barArrange.regionModel(regionName)
                                                                const idx = Math.floor(mouse.y / 34)
                                                                if (idx < 0 || idx >= model.length) { flick.interactive = true; return }
                                                                barArrange.dragRegion = regionName
                                                                barArrange.dragIndex = idx
                                                                barArrange.dragLabel = AequalynSettings.pluginLabels[model[idx]] || model[idx]
                                                                barArrange.hoverRegion = regionName
                                                                barArrange.hoverIndex = idx
                                                                dragGhost.textLabel = "≡  " + barArrange.dragLabel
                                                                dragGhost.visible = true
                                                                const p = mapToItem(barArrange, mouse.x, mouse.y)
                                                                dragGhost.x = p.x + 10
                                                                dragGhost.y = p.y - 12
                                                            }
                                                            onPositionChanged: (mouse) => {
                                                                if (!barArrange.dragging) return
                                                                const p = mapToItem(barArrange, mouse.x, mouse.y)
                                                                dragGhost.x = p.x + 10
                                                                dragGhost.y = p.y - 12
                                                                // find target region
                                                                let targetRegion = regionName
                                                                let targetIndex = 0
                                                                for (let r = 0; r < regionRepeater.count; r++) {
                                                                    const box = regionRepeater.itemAt(r)
                                                                    if (!box) continue
                                                                    const bp = mapToItem(box, mouse.x, mouse.y)
                                                                    if (bp.x >= 0 && bp.x <= box.width && p.y >= 0 && p.y <= barArrange.height) {
                                                                        targetRegion = box.regionName
                                                                        const lp = mapToItem(box.children[0].children[2], mouse.x, mouse.y) // listArea
                                                                        const m = barArrange.regionModel(targetRegion)
                                                                        targetIndex = Math.max(0, Math.min(m.length, Math.floor(lp.y / 34 + 0.5)))
                                                                        break
                                                                    }
                                                                }
                                                                // fallback by x across arrange area
                                                                const ax = p.x
                                                                const third = barArrange.width / 3
                                                                if (ax < third) targetRegion = "left"
                                                                else if (ax < third * 2) targetRegion = "center"
                                                                else targetRegion = "right"
                                                                const m2 = barArrange.regionModel(targetRegion)
                                                                // approximate y in target list
                                                                const targetBox = regionRepeater.itemAt(barArrange.regions.indexOf(targetRegion))
                                                                if (targetBox) {
                                                                    const lp2 = targetBox.mapFromItem(barArrange, p.x, p.y)
                                                                    targetIndex = Math.max(0, Math.min(m2.length, Math.floor((lp2.y - 60) / 34 + 0.5)))
                                                                }
                                                                barArrange.hoverRegion = targetRegion
                                                                barArrange.hoverIndex = targetIndex
                                                            }
                                                            onReleased: { barArrange.endDrag(true) }
                                                            onCanceled: { barArrange.endDrag(false) }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Floating drag ghost
                                    Rectangle {
                                        id: dragGhost
                                        property string textLabel: ""
                                        visible: false
                                        z: 100
                                        width: 180
                                        height: 28
                                        radius: 7
                                        color: root.theme.bgSelected
                                        border.color: root.theme.accentPrimary
                                        border.width: 1
                                        Text {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            verticalAlignment: Text.AlignVCenter
                                            text: dragGhost.textLabel
                                            color: root.theme.textPrimary
                                            font.pixelSize: 11
                                            font.family: root.font
                                            elide: Text.ElideRight
                                        }
                                    }
                                }

                                Divider {}
                                SectionTitle { text: "Show plugins" }
                                SubLabel { text: "Toggle individual widgets. Hidden plugins keep their position in the order above." }
                                Repeater {
                                    model: [
                                        { label: "Clock & date",        key: "showClock" },
                                        { label: "Workspaces",          key: "showWorkspaces" },
                                        { label: "Now playing",         key: "showMedia" },
                                        { label: "Window title",        key: "showTitle" },
                                        { label: "Audio / volume",      key: "showVolume" },
                                        { label: "Brightness",          key: "showBrightness" },
                                        { label: "CPU usage",           key: "showCpu" },
                                        { label: "Network",             key: "showNetwork" },
                                        { label: "Bluetooth",           key: "showBluetooth" },
                                        { label: "Battery",             key: "showBattery" },
                                        { label: "Temperature",         key: "showTemperature" },
                                        { label: "System tray",         key: "showTray" },
                                        { label: "Power menu",          key: "showPower" },
                                        { label: "Screen recorder",     key: "showScreenRecorder" },
                                        { label: "Screenshot",          key: "showScreenshot" },
                                        { label: "Caffeine (idle inhibit)", key: "showCaffeine" },
                                        { label: "Atelier (themes & wallpapers)", key: "showAtelier" },
                                        { label: "Window layout",       key: "showLayouts" },
                                        { label: "Arch apps-menu button", key: "showAppsMenu" },
                                        { label: "Settings gear button",  key: "showSettingsButton" }
                                    ]
                                    ToggleRow {
                                        required property var modelData
                                        label: modelData.label
                                        checked: AequalynSettings[modelData.key]
                                        settingKey: modelData.key
                                    }
                                }
                            }

                            // ============ HYPRLAND ============
                            ColumnLayout {
                                Layout.fillWidth: true
                                visible: root.tab === "hyprland"
                                spacing: 12
                                SectionTitle { text: "Hyprland customisations" }
                                SubLabel { text: "Written to ~/.config/hypr/aequalyn/look.lua and reloaded with hyprctl. Hand overrides go in aequalyn/user.lua." }
                                StepperRow { label: "Gaps in";       settingKey: "gapsIn";       minValue: 0;  maxValue: 20; stepValue: 1 }
                                StepperRow { label: "Gaps out";      settingKey: "gapsOut";      minValue: 0;  maxValue: 30; stepValue: 1 }
                                StepperRow { label: "Border size";   settingKey: "borderSize";   minValue: 0;  maxValue: 8;  stepValue: 1 }
                                StepperRow { label: "Rounding";      settingKey: "rounding";     minValue: 0;  maxValue: 24; stepValue: 1 }
                                Divider {}
                                SectionTitle { text: "Effects" }
                                ToggleRow {
                                    label: "Blur"
                                    checked: AequalynSettings.blurEnabled
                                    settingKey: "blurEnabled"
                                }
                                StepperRow { label: "Blur size";     settingKey: "blurSize";     minValue: 1;  maxValue: 20; stepValue: 1 }
                                ToggleRow {
                                    label: "Animations"
                                    checked: AequalynSettings.animationsEnabled
                                    settingKey: "animationsEnabled"
                                }
                                StepperRow { label: "Active opacity";   settingKey: "activeOpacity";   minValue: 0.6; maxValue: 1.0; stepValue: 0.05; decimals: true }
                                StepperRow { label: "Inactive opacity"; settingKey: "inactiveOpacity"; minValue: 0.6; maxValue: 1.0; stepValue: 0.05; decimals: true }
                                Divider {}
                                SectionTitle { text: "Layout & input" }
                                ChoiceRow {
                                    options: [
                                        { key: "dwindle",   label: "Dwindle" },
                                        { key: "master",    label: "Master" },
                                        { key: "scrolling", label: "Scrolling" }
                                    ]
                                    current: AequalynSettings.layout
                                    settingKey: "layout"
                                }
                                ToggleRow {
                                    label: "Natural scroll (touchpad)"
                                    checked: AequalynSettings.naturalScroll
                                    settingKey: "naturalScroll"
                                }
                                ChoiceRow {
                                    options: [
                                        { key: "us", label: "US" }, { key: "ro", label: "RO" },
                                        { key: "de", label: "DE" }, { key: "fr", label: "FR" },
                                        { key: "gb", label: "GB" }
                                    ]
                                    current: AequalynSettings.kbLayout
                                    settingKey: "kbLayout"
                                }
                            }

                            // ============ POWER ============
                            ColumnLayout {
                                Layout.fillWidth: true
                                visible: root.tab === "power"
                                spacing: 12
                                SectionTitle { text: "Screen lock & idle" }
                                SubLabel { text: "These options drive hypridle. Timers only run while the session is idle; SUPER+SHIFT+C toggles the Caffeine idle inhibitor for a temporary override." }

                                ToggleRow {
                                    label: "Lock the screen when idle"
                                    sublabel: "Runs hyprlock after the timeout below. Off means the screen is never locked automatically, including before suspend."
                                    checked: AequalynSettings.lockEnabled
                                    settingKey: "lockEnabled"
                                }
                                StepperRow {
                                    visible: AequalynSettings.lockEnabled
                                    label: "Lock after (minutes)"
                                    settingKey: "lockMinutes"
                                    minValue: 1; maxValue: 60; stepValue: 1
                                }
                                Divider {}
                                ToggleRow {
                                    label: "Turn the display off when idle"
                                    sublabel: "Blanks the panel with DPMS without locking or suspending."
                                    checked: AequalynSettings.screenOffEnabled
                                    settingKey: "screenOffEnabled"
                                }
                                StepperRow {
                                    visible: AequalynSettings.screenOffEnabled
                                    label: "Display off after (minutes)"
                                    settingKey: "screenOffMinutes"
                                    minValue: 1; maxValue: 120; stepValue: 1
                                }
                                Divider {}
                                ToggleRow {
                                    label: "Suspend when idle"
                                    sublabel: "Suspends the machine after the timeout. Turn this off if only the display should sleep."
                                    checked: AequalynSettings.suspendEnabled
                                    settingKey: "suspendEnabled"
                                }
                                StepperRow {
                                    visible: AequalynSettings.suspendEnabled
                                    label: "Suspend after (minutes)"
                                    settingKey: "suspendMinutes"
                                    minValue: 1; maxValue: 240; stepValue: 1
                                }
                                Divider {}
                                SubLabel { text: "Changes are written to ~/.config/aequalyn/settings.json and applied immediately by restarting hypridle. With lock and suspend both off, an idle session stays awake with only the display turning off." }
                            }

                            // ============ BLUETOOTH ============
                            ColumnLayout {
                                Layout.fillWidth: true
                                visible: root.tab === "bluetooth"
                                spacing: 12
                                SectionTitle { text: "Bluetooth" }
                                SubLabel { text: "Power, scan and manage devices through BlueZ. The bar plugin shows the connection state; right-click it to open this page." }

                                Divider {}
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10
                                    Text {
                                        Layout.fillWidth: true
                                        text: BluetoothService.available
                                            ? (BluetoothService.powered ? "Adapter on" : "Adapter off")
                                            : "No Bluetooth adapter found"
                                        color: root.theme.textPrimary
                                        font.pixelSize: 12
                                        font.family: root.font
                                    }
                                    ToggleSwitch {
                                        checked: BluetoothService.powered
                                        enabled: BluetoothService.available
                                        onToggled: BluetoothService.togglePower()
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10
                                    ActionButton {
                                        label: BluetoothService.discovering ? "Stop scan" : "Scan for devices"
                                        enabled: BluetoothService.available && BluetoothService.powered
                                        onClicked: BluetoothService.toggleDiscovering()
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: BluetoothService.connectedCount + " connected · " +
                                              BluetoothService.deviceCount + " known"
                                        color: root.theme.textMuted
                                        font.pixelSize: 10
                                        font.family: root.font
                                    }
                                }

                                Divider {}
                                SectionTitle { text: "Devices" }
                                SubLabel {
                                    visible: BluetoothService.deviceCount === 0
                                    text: "No devices yet. Turn the adapter on and scan to discover nearby devices, or pair them with your system's Bluetooth tools."
                                }

                                Repeater {
                                    model: BluetoothService.devices
                                    Rectangle {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        implicitHeight: 46
                                        radius: 8
                                        color: root.theme.bgSurface
                                        border.color: modelData.connected ? root.theme.accentPrimary : root.theme.bgBorder
                                        border.width: 1

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 12
                                            spacing: 10
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 2
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: modelData.deviceName || modelData.name || modelData.address
                                                    color: root.theme.textPrimary
                                                    font.pixelSize: 12
                                                    font.family: root.font
                                                    elide: Text.ElideRight
                                                }
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: (modelData.connected ? "Connected" :
                                                           modelData.paired ? "Paired" : "Available") +
                                                          (modelData.batteryAvailable
                                                              ? " · " + Math.round(modelData.battery * 100) + "%"
                                                              : "") +
                                                          " · " + modelData.address
                                                    color: root.theme.textMuted
                                                    font.pixelSize: 10
                                                    font.family: root.font
                                                    elide: Text.ElideRight
                                                }
                                            }
                                            Rectangle {
                                                implicitWidth: connectLabel.implicitWidth + 20
                                                implicitHeight: 28
                                                radius: 7
                                                color: connectHover.containsMouse ? root.theme.accentPrimary : root.theme.bgSelected
                                                border.color: root.theme.bgBorder
                                                border.width: 1
                                                Text {
                                                    id: connectLabel
                                                    anchors.centerIn: parent
                                                    text: modelData.connected ? "Disconnect" : "Connect"
                                                    color: connectHover.containsMouse ? root.theme.bgBase : root.theme.textPrimary
                                                    font.pixelSize: 10
                                                    font.family: root.font
                                                }
                                                MouseArea {
                                                    id: connectHover
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (modelData.connected) modelData.disconnect()
                                                        else modelData.connect()
                                                    }
                                                }
                                            }
                                            Rectangle {
                                                visible: modelData.paired
                                                implicitWidth: forgetLabel.implicitWidth + 16
                                                implicitHeight: 28
                                                radius: 7
                                                color: "transparent"
                                                border.color: root.theme.bgBorder
                                                border.width: 1
                                                Text {
                                                    id: forgetLabel
                                                    anchors.centerIn: parent
                                                    text: "Forget"
                                                    color: root.theme.textMuted
                                                    font.pixelSize: 10
                                                    font.family: root.font
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: modelData.forget()
                                                }
                                            }
                                        }
                                    }
                                }

                                Divider {}
                                SectionTitle { text: "Audio profile" }
                                SubLabel { text: "Choose the Bluetooth audio codec for a connected headset. A2DP is high-fidelity playback; HSP/HFP also enables the microphone." }

                                SubLabel {
                                    visible: root.audioCards.length === 0
                                    text: "No Bluetooth audio card is active yet. Connect a headset and wait a moment, then it will appear here with its available profiles."
                                }

                                Text {
                                    visible: root.audioMessage !== ""
                                    Layout.fillWidth: true
                                    text: root.audioMessage
                                    color: root.theme.accentGreen
                                    font.pixelSize: 10
                                    font.family: root.font
                                }

                                Repeater {
                                    model: root.audioCards
                                    ColumnLayout {
                                        id: cardRow
                                        required property var modelData
                                        Layout.fillWidth: true
                                        spacing: 8
                                        Text {
                                            Layout.fillWidth: true
                                            text: cardRow.modelData.description + "  ·  " + cardRow.modelData.address
                                            color: root.theme.textPrimary
                                            font.pixelSize: 11
                                            font.family: root.font
                                            elide: Text.ElideRight
                                        }
                                        Flow {
                                            Layout.fillWidth: true
                                            spacing: 8
                                            Repeater {
                                                model: cardRow.modelData.profiles || []
                                                Rectangle {
                                                    required property var modelData
                                                    readonly property bool active:
                                                        modelData.name === cardRow.modelData.activeProfile
                                                    implicitWidth: profileLabel.implicitWidth + 20
                                                    implicitHeight: 30
                                                    radius: 7
                                                    color: active ? root.theme.accentPrimary
                                                                  : (profileHover.containsMouse ? root.theme.bgHover : root.theme.bgSurface)
                                                    border.color: root.theme.bgBorder
                                                    border.width: 1
                                                    Text {
                                                        id: profileLabel
                                                        anchors.centerIn: parent
                                                        text: modelData.description || modelData.name
                                                        color: active ? root.theme.bgBase : root.theme.textSecondary
                                                        font.pixelSize: 10
                                                        font.family: root.font
                                                    }
                                                    MouseArea {
                                                        id: profileHover
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: root.setAudioProfile(
                                                            cardRow.modelData.name, modelData.name)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // ============ WI-FI ============
                            ColumnLayout {
                                Layout.fillWidth: true
                                visible: root.tab === "wifi"
                                spacing: 12
                                SectionTitle { text: "Wi-Fi" }
                                SubLabel { text: "Scan and connect to wireless networks through NetworkManager. The bar plugin shows the connection state; right-click it to open this page." }

                                Divider {}
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10
                                    Text {
                                        Layout.fillWidth: true
                                        text: WifiService.available
                                            ? (WifiService.wifiEnabled ? "Wi-Fi on" : "Wi-Fi off")
                                            : "No Wi-Fi adapter / NetworkManager found"
                                        color: root.theme.textPrimary
                                        font.pixelSize: 12
                                        font.family: root.font
                                    }
                                    ToggleSwitch {
                                        checked: WifiService.wifiEnabled
                                        enabled: WifiService.available
                                        onToggled: WifiService.toggleWifi()
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10
                                    ActionButton {
                                        label: WifiService.scanning ? "Scanning…" : "Scan for networks"
                                        enabled: WifiService.available && WifiService.wifiEnabled
                                        onClicked: { WifiService.scan(); wifiScanTimer.restart() }
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: WifiService.networkCount + " network" + (WifiService.networkCount === 1 ? "" : "s") +
                                              (WifiService.connectedName !== "" ? " · connected to " + WifiService.connectedName : "")
                                        color: root.theme.textMuted
                                        font.pixelSize: 10
                                        font.family: root.font
                                    }
                                }

                                Divider {}
                                SectionTitle { text: "Networks" }
                                SubLabel {
                                    visible: WifiService.networkCount === 0
                                    text: "No networks yet. Turn Wi-Fi on and scan to discover nearby networks."
                                }

                                Repeater {
                                    model: WifiService.networks
                                    Rectangle {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        implicitHeight: 46
                                        radius: 8
                                        color: root.theme.bgSurface
                                        border.color: modelData.connected ? root.theme.accentPrimary : root.theme.bgBorder
                                        border.width: 1

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 12
                                            spacing: 10
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 2
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: modelData.name || "(hidden network)"
                                                    color: root.theme.textPrimary
                                                    font.pixelSize: 12
                                                    font.family: root.font
                                                    elide: Text.ElideRight
                                                }
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: (modelData.connected ? "Connected" :
                                                           modelData.known ? "Saved" : "Available") +
                                                          " · " + Math.round(modelData.signalStrength || 0) + "%" +
                                                          " · " + WifiService.securityText(modelData.security)
                                                    color: root.theme.textMuted
                                                    font.pixelSize: 10
                                                    font.family: root.font
                                                    elide: Text.ElideRight
                                                }
                                            }
                                            Rectangle {
                                                implicitWidth: wifiConnectLabel.implicitWidth + 20
                                                implicitHeight: 28
                                                radius: 7
                                                color: wifiConnectHover.containsMouse ? root.theme.accentPrimary : root.theme.bgSelected
                                                border.color: root.theme.bgBorder
                                                border.width: 1
                                                Text {
                                                    id: wifiConnectLabel
                                                    anchors.centerIn: parent
                                                    text: modelData.connected ? "Disconnect" : "Connect"
                                                    color: wifiConnectHover.containsMouse ? root.theme.bgBase : root.theme.textPrimary
                                                    font.pixelSize: 10
                                                    font.family: root.font
                                                }
                                                MouseArea {
                                                    id: wifiConnectHover
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (modelData.connected) {
                                                            WifiService.disconnectNetwork(modelData)
                                                        } else if (WifiService.requiresCredentials(modelData.security) && !modelData.known) {
                                                            root.wifiPasswordSsid = modelData.name || ""
                                                            root.wifiPasswordText = ""
                                                        } else {
                                                            WifiService.connectNetwork(modelData)
                                                        }
                                                    }
                                                }
                                            }
                                            Rectangle {
                                                visible: modelData.known
                                                implicitWidth: wifiForgetLabel.implicitWidth + 16
                                                implicitHeight: 28
                                                radius: 7
                                                color: "transparent"
                                                border.color: root.theme.bgBorder
                                                border.width: 1
                                                Text {
                                                    id: wifiForgetLabel
                                                    anchors.centerIn: parent
                                                    text: "Forget"
                                                    color: root.theme.textMuted
                                                    font.pixelSize: 10
                                                    font.family: root.font
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: WifiService.forgetNetwork(modelData)
                                                }
                                            }
                                        }
                                    }
                                }

                                // Password prompt
                                ColumnLayout {
                                    visible: root.wifiPasswordSsid !== ""
                                    Layout.fillWidth: true
                                    spacing: 8
                                    Divider {}
                                    Text {
                                        Layout.fillWidth: true
                                        text: "Password for " + root.wifiPasswordSsid
                                        color: root.theme.textPrimary
                                        font.pixelSize: 12
                                        font.family: root.font
                                    }
                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: 32
                                        radius: 8
                                        color: root.theme.bgSurface
                                        border.color: root.theme.bgBorder
                                        border.width: 1
                                        TextInput {
                                            id: wifiPasswordField
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            verticalAlignment: Text.AlignVCenter
                                            color: root.theme.textPrimary
                                            font.pixelSize: 12
                                            font.family: root.font
                                            echoMode: TextInput.Password
                                            text: root.wifiPasswordText
                                            onTextChanged: root.wifiPasswordText = text
                                            onAccepted: root.connectWifiWithPassword()
                                        }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 10
                                        ActionButton {
                                            label: "Cancel"
                                            onClicked: { root.wifiPasswordSsid = ""; root.wifiPasswordText = "" }
                                        }
                                        ActionButton {
                                            label: "Connect"
                                            onClicked: root.connectWifiWithPassword()
                                        }
                                    }
                                }

                                Divider {}
                                SubLabel { text: "Wi-Fi state is managed by NetworkManager. Scanning may take a few seconds." }
                            }

                            // ============ DISPLAYS ============
                            ColumnLayout {
                                Layout.fillWidth: true
                                visible: root.tab === "displays"
                                spacing: 12
                                SectionTitle { text: "Displays" }
                                SubLabel { text: "Arrange, scale, rotate or mirror monitors with the visual editor. Layouts are saved to ~/.config/hypr/monitors.lua and restored at login." }
                                ActionButton {
                                    label: "Open display manager"
                                    hint: "SUPER+O"
                                    onClicked: { root.panelVisible = false; qsIpc.command = ["qs", "ipc", "call", "monitors", "toggle"]; qsIpc.running = true }
                                }
                                Divider {}
                                SubLabel { text: "Tip: the display manager writes monitors.lua (Lua config). Everything else about monitors (resolution, refresh rate) is handled there too." }
                            }


                            // ============ DOCK ============
                            ColumnLayout {
                                Layout.fillWidth: true
                                visible: root.tab === "dock"
                                spacing: 12
                                SectionTitle { text: "Docks" }
                                SubLabel { text: "Up to 16 docks on any edge of any screen, 4 per edge, each with its own apps, size, auto-hide effect and look, or the bar's look so they change together. Everything about them lives in Atelier -> Docks; right-click any dock to get there." }
                                ToggleRow {
                                    label: "Docks"
                                    sublabel: "Show the docks."
                                    checked: AequalynSettings.dockEnabled
                                    settingKey: "dockEnabled"
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 12
                                    ActionButton {
                                        label: "Docks"
                                        onClicked: { root.panelVisible = false; qsIpc.command = ["qs", "ipc", "call", "atelier", "open", "docks"]; qsIpc.running = true }
                                    }
                                    ActionButton {
                                        label: "Bar look"
                                        onClicked: { root.panelVisible = false; qsIpc.command = ["qs", "ipc", "call", "atelier", "open", "bar"]; qsIpc.running = true }
                                    }
                                    ActionButton {
                                        label: "Add a dock"
                                        onClicked: { qsIpc.command = ["qs", "ipc", "call", "dock", "add"]; qsIpc.running = true }
                                    }
                                }
                            }

                            // ============ ABOUT ============
                            ColumnLayout {
                                Layout.fillWidth: true
                                visible: root.tab === "about"
                                spacing: 12
                                SectionTitle { text: "Aequalyn" }
                                SubLabel { text: "A QuickShell desktop for Hyprland, built on Arch Linux. v" + root.version }
                                Divider {}
                                SectionTitle { text: "Keybinds" }
                                Repeater {
                                    model: [
                                        { k: "SUPER + Return",  v: "Terminal (kitty)" },
                                        { k: "SUPER + E",       v: "File manager (nautilus)" },
                                        { k: "SUPER + Space",   v: "Fuzzel launcher" },
                                        { k: "SUPER + D",       v: "Aequalyn app launcher" },
                                        { k: "apps-menu (bar)", v: "Open the app launcher" },
                                        { k: "gear (bar)",      v: "Open Aequalyn settings" },
                                        { k: "BT pill (right-click)", v: "Bluetooth settings" },
                                        { k: "SUPER + ,",       v: "Aequalyn settings" },
                                        { k: "SUPER + C/V/X/A", v: "Universal copy / paste / cut / select-all" },
                                        { k: "SUPER + Ctrl + V", v: "Clipboard history (text + images)" },
                                        { k: "SUPER + T",       v: "Theme switcher" },
                                        { k: "SUPER + W",       v: "Wallpaper picker" },
                                        { k: "SUPER + O",       v: "Display manager" },
                                        { k: "SUPER + SHIFT + O", v: "Refresh display layout" },
                                        { k: "SUPER + SHIFT + C", v: "Caffeine (idle inhibit)" },
                                        { k: "SUPER + SHIFT + V", v: "Toggle floating" },
                                        { k: "SUPER + I",       v: "Installer (live ISO)" },
                                        { k: "SUPER + N",       v: "Dismiss notifications" },
                                        { k: "SUPER + SHIFT + N", v: "Toggle do-not-disturb" },
                                        { k: "SUPER + Q",       v: "Close window" },
                                        { k: "SUPER + F",       v: "Fullscreen" },
                                        { k: "SUPER + P",       v: "Pseudo-tile" },
                                        { k: "SUPER + J",       v: "Toggle split" },
                                        { k: "SUPER + 1..0",    v: "Switch workspace" },
                                        { k: "SUPER + SHIFT + 1..0", v: "Move window to workspace" },
                                        { k: "SUPER + S",       v: "Special workspace (scratchpad)" },
                                        { k: "SUPER + arrows",  v: "Focus window" },
                                        { k: "SUPER + SHIFT + arrows", v: "Move window" },
                                        { k: "SUPER + Print",   v: "Screenshot to clipboard" },
                                        { k: "Print",           v: "Region screenshot to clipboard" },
                                        { k: "SUPER + SHIFT + Print", v: "Region screenshot to file (~/Pictures/Screenshots)" },
                                        { k: "SUPER + SHIFT + M", v: "Power menu" },
                                        { k: "SUPER + SHIFT + R", v: "Toggle screen recording" }
                                    ]
                                    RowLayout {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        spacing: 12
                                        Text {
                                            text: modelData.k
                                            color: root.theme.accentPrimary
                                            font.pixelSize: 11
                                            font.family: root.font
                                            Layout.preferredWidth: 170
                                        }
                                        Text {
                                            text: modelData.v
                                            color: root.theme.textSecondary
                                            font.pixelSize: 11
                                            font.family: root.font
                                            Layout.fillWidth: true
                                        }
                                    }
                                }
                                Divider {}
                                SectionTitle { text: "Settings backup" }
                                SubLabel { text: "Export or import settings.json, pinned apps, Hyprland settings, and installed packages (Arch + AUR) as a portable JSON file." }
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10
                                    Rectangle {
                                        id: exportBtn
                                        visible: root.hasExportFiles
                                        implicitWidth: exportBtnLabel.implicitWidth + 24
                                        implicitHeight: 32
                                        radius: 8
                                        color: exportBtnHover.containsMouse ? root.theme.accentPrimary : root.theme.bgSelected
                                        border.color: root.theme.bgBorder
                                        border.width: 1
                                        opacity: exportProc.running ? 0.7 : 1.0
                                        Text {
                                            id: exportBtnLabel
                                            anchors.centerIn: parent
                                            text: exportProc.running ? "Exporting…" : "Export settings"
                                            color: exportBtnHover.containsMouse ? root.theme.bgBase : root.theme.textPrimary
                                            font.pixelSize: 11
                                            font.family: root.font
                                        }
                                        MouseArea {
                                            id: exportBtnHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: exportProc.running ? Qt.BusyCursor : Qt.PointingHandCursor
                                            enabled: !exportProc.running
                                            onClicked: {
                                                root.exportStatus = ""
                                                exportProc.running = true
                                            }
                                        }
                                    }
                                    Rectangle {
                                        id: importBtn
                                        implicitWidth: importBtnLabel.implicitWidth + 24
                                        implicitHeight: 32
                                        radius: 8
                                        color: importBtnHover.containsMouse ? root.theme.accentPrimary : root.theme.bgSelected
                                        border.color: root.theme.bgBorder
                                        border.width: 1
                                        opacity: importProc.running ? 0.7 : 1.0
                                        Text {
                                            id: importBtnLabel
                                            anchors.centerIn: parent
                                            text: importProc.running ? "Importing…" : "Import settings"
                                            color: importBtnHover.containsMouse ? root.theme.bgBase : root.theme.textPrimary
                                            font.pixelSize: 11
                                            font.family: root.font
                                        }
                                        MouseArea {
                                            id: importBtnHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: importProc.running ? Qt.BusyCursor : Qt.PointingHandCursor
                                            enabled: !importProc.running
                                            onClicked: {
                                                root.exportStatus = ""
                                                importProc.running = true
                                            }
                                        }
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        visible: root.exportStatus !== ""
                                        text: root.exportStatus
                                        color: root.theme.textSecondary
                                        font.pixelSize: 11
                                        font.family: root.font
                                        wrapMode: Text.WrapAnywhere
                                    }
                                }
                                SubLabel {
                                    visible: !root.hasExportFiles
                                    text: "No Aequalyn export files detected in your home folder. Use Import settings to select an export file."
                                }
                                SubLabel {
                                    visible: root.hasExportFiles && root.detectedExportFile !== ""
                                    text: "Detected export: " + root.detectedExportFile
                                }
                                Divider {}
                                SubLabel { text: "Colours: matugen. Shell: Quickshell. Compositor: Hyprland. Config lives in ~/.config/aequalyn/settings.json -- edit it, import it, or let the installer generate it." }
                            }
                        }
                    }
                }
            }
        }
    }

    Process { id: qsIpc; running: false }
    Process {
        id: detectExportProc
        running: false
        command: ["bash", "-lc", "ls -1t \"$HOME\"/Aequalyn-export-*.json 2>/dev/null | head -n1 || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim()
                root.detectedExportFile = p
                root.hasExportFiles = p.length > 0
            }
        }
    }
    Process {
        id: exportProc
        running: false
        command: ["aequalyn-export-settings"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim()
                if (p.length > 0)
                    root.exportStatus = "Exported to " + p
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const e = text.trim()
                if (e.length > 0 && root.exportStatus === "")
                    root.exportStatus = "Export failed: " + e
            }
        }
        onExited: (code, status) => {
            if (code !== 0 && root.exportStatus === "")
                root.exportStatus = "Export failed (exit " + code + ")"
            if (code === 0) root.refreshExportFiles()
        }
    }
    Process {
        id: importProc
        running: false
        command: ["bash", "-lc", "file=$(zenity --file-selection --title='Import Aequalyn Settings' --file-filter='JSON files (*.json) | *.json' --file-filter='All files | *' 2>/dev/null || kdialog --getopenfilename \"$HOME\" '*.json' 2>/dev/null || true); if [ -n \"$file\" ]; then aequalyn-import-settings \"$file\"; else echo '__CANCELLED__'; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = text.trim()
                if (out === "__CANCELLED__" || out.length === 0) {
                    root.exportStatus = "Import cancelled."
                } else {
                    root.exportStatus = out
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const e = text.trim()
                if (e.length > 0 && root.exportStatus.indexOf("Import failed") !== 0)
                    root.exportStatus = "Import failed: " + e
            }
        }
        onExited: (code, status) => {
            if (code !== 0 && root.exportStatus === "")
                root.exportStatus = "Import failed (exit " + code + ")"
            if (code === 0) root.refreshExportFiles()
        }
    }
}
