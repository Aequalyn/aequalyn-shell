// Layouts: every window layout as a picture to click, for any workspace.
// The dot in a tile's corner keeps it in (or leaves it out of) Super + L.
import QtQuick
import QtQuick.Layouts
import "controls"

Item {
    id: pane
    property var theme
    property string font: "JetBrainsMono Nerd Font"
    property string searchText: ""

    property string group: "all"
    property string workspace: LayoutService.focusedWorkspace
    property int currentIndex: 0

    readonly property string activeId: LayoutService.layoutOf(workspace)
    readonly property var items: {
        const q = searchText.toLowerCase();
        return LayoutService.catalogue.filter(l =>
            (group === "all" || l.group === group)
            && (q === "" || (l.name + " " + l.group + " " + l.hint).toLowerCase().indexOf(q) >= 0));
    }
    readonly property var current: items[currentIndex] || null
    readonly property int columns: grid.columns

    onItemsChanged: if (currentIndex >= items.length) currentIndex = Math.max(0, items.length - 1)

    function selectActive() {
        for (let i = 0; i < items.length; i++) if (items[i].id === activeId) { currentIndex = i; return; }
    }
    function apply(i) {
        const it = items[i];
        if (!it) return;
        currentIndex = i;
        LayoutService.set(it.id, workspace);
    }

    // Arrows, Enter, Space (cycle dot); Atelier forwards keys here.
    function handleKey(event) {
        const n = items.length;
        if (n === 0) return false;
        const k = event.key;
        if (k === Qt.Key_Left) currentIndex = Math.max(0, currentIndex - 1);
        else if (k === Qt.Key_Right) currentIndex = Math.min(n - 1, currentIndex + 1);
        else if (k === Qt.Key_Up) currentIndex = Math.max(0, currentIndex - columns);
        else if (k === Qt.Key_Down) currentIndex = Math.min(n - 1, currentIndex + columns);
        else if (k === Qt.Key_Return || k === Qt.Key_Enter) apply(currentIndex);
        else if (k === Qt.Key_Space && (event.modifiers & Qt.ControlModifier)) LayoutService.toggleCycle(items[currentIndex].id);
        else return false;
        return true;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        // Workspace picker
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Text {
                text: "WORKSPACE"
                color: pane.theme.textMuted
                font.family: pane.font
                font.pixelSize: 10
                font.bold: true
                font.letterSpacing: 1.4
                Layout.rightMargin: 6
            }
            Repeater {
                model: 10
                delegate: Rectangle {
                    id: wsChip
                    required property int index
                    readonly property string ws: String(index + 1)
                    readonly property bool on: pane.workspace === ws
                    readonly property var lay: LayoutService.find(LayoutService.layoutOf(ws))
                    implicitWidth: 58
                    implicitHeight: 40
                    radius: 8
                    color: on ? pane.theme.bgSelected : (wsArea.containsMouse ? pane.theme.bgHover : pane.theme.bgSurface)
                    border.width: on ? 2 : 1
                    border.color: on ? pane.theme.accentPrimary : pane.theme.bgBorder
                    LayoutArt {
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        width: 26; height: 16
                        theme: pane.theme
                        boxes: wsChip.lay ? wsChip.lay.art : []
                        on: wsChip.on
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 7
                        anchors.verticalCenter: parent.verticalCenter
                        text: wsChip.ws
                        color: wsChip.on ? pane.theme.textPrimary : pane.theme.textSecondary
                        font.family: pane.font
                        font.pixelSize: 12
                        font.bold: true
                    }
                    Rectangle {
                        visible: wsChip.ws === LayoutService.focusedWorkspace
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottomMargin: 3
                        width: 12; height: 2; radius: 1
                        color: pane.theme.accentGreen
                    }
                    MouseArea {
                        id: wsArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { pane.workspace = wsChip.ws; pane.selectActive(); }
                    }
                }
            }
            Item { Layout.fillWidth: true }
            Text {
                text: (pane.current ? pane.current.name : "") + "  ·  " + pane.items.length + " layouts"
                color: pane.theme.textMuted
                font.family: pane.font
                font.pixelSize: 11
            }
        }

        // Groups
        Flow {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: [["all", "All"]].concat(LayoutService.groups.map(g => [g, g]))
                Chip {
                    required property var modelData
                    theme: pane.theme; font: pane.font; compact: true
                    text: modelData[1] + (modelData[0] === "all" ? "" : "  " + LayoutService.catalogue.filter(l => l.group === modelData[0]).length)
                    selected: pane.group === modelData[0]
                    onClicked: { pane.group = modelData[0]; pane.currentIndex = 0; }
                }
            }
        }

        // Tiles
        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            readonly property int columns: Math.max(3, Math.floor(width / 196))
            cellWidth: Math.floor(width / columns)
            cellHeight: Math.floor(cellWidth * 0.56) + 46
            model: pane.items
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            currentIndex: pane.currentIndex
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)

            delegate: Item {
                id: cell
                required property var modelData
                required property int index
                readonly property bool active: modelData.id === pane.activeId
                readonly property bool selected: index === pane.currentIndex
                readonly property bool cycled: LayoutService.inCycle(modelData.id)
                width: grid.cellWidth
                height: grid.cellHeight

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 5
                    radius: 12
                    color: cell.active ? pane.theme.bgSelected : (tileArea.containsMouse || cell.selected ? pane.theme.bgHover : pane.theme.bgSurface)
                    border.width: cell.selected || cell.active ? 2 : 1
                    border.color: cell.active ? pane.theme.accentPrimary : (cell.selected ? pane.theme.textMuted : pane.theme.bgBorder)
                    Behavior on color { ColorAnimation { duration: 110 } }

                    LayoutArt {
                        id: tileArt
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 10
                        height: width * 0.5625
                        theme: pane.theme
                        boxes: cell.modelData.art
                        on: cell.active || cell.selected
                    }
                    Column {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: tileArt.bottom
                        anchors.leftMargin: 11
                        anchors.rightMargin: 11
                        anchors.topMargin: 6
                        spacing: 1
                        Text {
                            width: parent.width
                            text: cell.modelData.name
                            color: pane.theme.textPrimary
                            font.family: pane.font
                            font.pixelSize: 12
                            font.bold: cell.active
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: cell.modelData.group
                            color: pane.theme.textMuted
                            font.family: pane.font
                            font.pixelSize: 9
                        }
                    }

                    // In Super + L?
                    Rectangle {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 10
                        width: 12; height: 12; radius: 6
                        color: cell.cycled ? pane.theme.accentPrimary : "transparent"
                        border.color: cell.cycled ? pane.theme.accentPrimary : pane.theme.textMuted
                        border.width: 1.5
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: LayoutService.toggleCycle(cell.modelData.id)
                        }
                    }
                    Rectangle {
                        visible: cell.active
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 6
                        width: 18; height: 18; radius: 9
                        color: pane.theme.accentGreen
                        Text {
                            anchors.centerIn: parent
                            text: "󰄬"
                            color: pane.theme.bgBase
                            font.family: pane.font
                            font.pixelSize: 11
                        }
                    }
                    MouseArea {
                        id: tileArea
                        anchors.fill: parent
                        anchors.bottomMargin: 26
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: pane.currentIndex = cell.index
                        onClicked: pane.apply(cell.index)
                    }
                }
            }
        }

        // Hint + sizes
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            radius: 10
            color: pane.theme.bgSurface
            border.color: pane.theme.bgBorder
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 18
                Text {
                    Layout.fillWidth: true
                    text: pane.current ? pane.current.hint : ""
                    color: pane.theme.textSecondary
                    font.family: pane.font
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
                Stepper {
                    theme: pane.theme; font: pane.font
                    label: "Main pane"; suffix: "%"
                    from: 30; to: 85; step: 2
                    value: Math.round((LayoutService.status.pane || 0.62) * 100)
                    onStepped: v => LayoutService.option("pane", (v / 100).toFixed(2))
                }
                Stepper {
                    theme: pane.theme; font: pane.font
                    label: "Gap"; suffix: " px"
                    from: 0; to: 120; step: 4
                    value: LayoutService.status.gap === undefined ? 24 : LayoutService.status.gap
                    onStepped: v => LayoutService.option("gap", v)
                }
            }
        }

        // Keys and windows: how the layout keys behave, and how the windows look
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: keysRow.implicitHeight + 20
            radius: 10
            color: pane.theme.bgSurface
            border.color: pane.theme.bgBorder
            Flow {
                id: keysRow
                anchors.fill: parent
                anchors.margins: 10
                anchors.leftMargin: 14
                spacing: 18
                // one press of Super + - / =, as a share of the screen (Alt: a quarter, Ctrl: four times)
                Stepper {
                    theme: pane.theme; font: pane.font
                    label: "Resize step"; suffix: "%"
                    from: 0.25; to: 5; step: 0.25
                    value: Math.round((LayoutService.status.step || 0.01) * 400) / 4
                    onStepped: v => LayoutService.option("step", (v / 100).toFixed(4))
                }
                Toggle {
                    theme: pane.theme; font: pane.font
                    label: "Show the layout's name when it changes"
                    checked: LayoutService.status.notify !== false
                    onToggled: v => LayoutService.option("notify", v ? "true" : "false")
                }
                // the border of windows on Aequalyn's layouts ("As set": Settings -> Hyprland's)
                ChoiceRow {
                    theme: pane.theme; font: pane.font
                    label: "Outline"
                    options: ["theme", "0", "1", "2", "3", "4", "6", "8", "10"]
                    labels: ({ theme: "As set", "0": "None" })
                    value: String(LayoutService.status.outline === undefined ? "theme" : LayoutService.status.outline)
                    onPicked: v => LayoutService.option("outline", v)
                }
                ChoiceRow {
                    theme: pane.theme; font: pane.font
                    label: "Other windows"
                    options: ["theme", "same", "hidden"]
                    labels: ({ theme: "Theme's inactive", same: "Same as focused", hidden: "No outline" })
                    value: LayoutService.status.others || "theme"
                    onPicked: v => LayoutService.option("others", v)
                }
            }
        }
    }
}
