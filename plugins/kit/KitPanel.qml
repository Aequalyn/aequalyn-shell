// The built-in pack's panel: a keyboard-first window over the shell's backdrop, the
// same for every plugin that uses it, and drawn like the Applications menu (its name
// in the accent colour, the search line, how many there are, the rows with a bar on
// the chosen one, and the keys at the bottom):
//   type        search, or the plugin's own input     ↑ ↓ / Tab   move
//   Enter       the plugin's action on the row        Esc         clear, then close
// A plugin sets `items` ({ icon, title, sub, hint, swatch }) and answers `activated`;
// one that needs more shows its own `body` under the line instead of the list.
// `columns` above 0 shows the items as a grid of tiles instead (each its `glyph`, or its
// icon, large): the arrows move across and down, and the line under the grid names
// the tile you are on (its title and sub).
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "root:/style/backdrop"
import "../../Plugins.js" as Registry

Scope {
    id: kp
    property var theme: null
    property string name: "kit"                 // its layer: aequalyn_panel_<name>
    property string title: ""
    property string icon: ""
    property string placeholder: "Type to search"
    property bool open: false
    property bool input: true                    // show the line to type in
    property string query: ""
    property var items: []
    property int current: 0
    property string emptyText: "Nothing here"
    property string status: ""                  // one line under the list
    property var hints: [["↑ ↓", "move"], ["Enter", "use"], ["Esc", "close"]]
    property Component body: null
    property real panelWidth: 580
    property real panelHeight: 480
    property bool multiline: false               // Enter adds a line; Ctrl + Enter is the action
    property int columns: 0                      // tiles across: a grid instead of a list
    // the line over the list ("12 results"); "" for none
    property string countText: kp.items.length + (kp.items.length === 1 ? " result" : " results")
    // small buttons at the right of the keys: [{ key, label }], answered by `action`
    property var actions: []
    signal action(string key)
    readonly property string font: "JetBrainsMono Nerd Font"
    // its name over the search line: `title`, or the plugin's own (Plugins.js)
    readonly property string heading: kp.title !== "" ? kp.title
        : ((Registry.list.find(p => p.id === kp.name) || { label: kp.name }).label)
    // the keys as the Applications menu writes them
    function keyText(k) { return ({ "Enter": "⏎", "Esc": "esc", "↑ ↓": "↑↓", "Tab": "tab" })[k] || k }
    signal activated(var item, int index, int modifiers)
    signal keyPressed(var event)

    function toggle() { kp.open = !kp.open }
    function show() { kp.open = true }
    function hide() { kp.open = false }
    onOpenChanged: if (open) { kp.current = 0; focusTimer.restart() }
    onQueryChanged: kp.current = 0
    onItemsChanged: if (kp.current >= kp.items.length) kp.current = Math.max(0, kp.items.length - 1)
    Timer { id: focusTimer; interval: 30; onTriggered: field.forceActiveFocus() }

    readonly property color c_bg: theme ? theme.bgBase : "#141414"
    readonly property color c_surface: theme ? theme.bgSurface : "#1e1e1e"
    readonly property color c_hover: theme ? theme.bgHover : "#2a2a2a"
    readonly property color c_selected: theme ? theme.bgSelected : "#283457"
    readonly property color c_text2: theme ? theme.textSecondary : "#c0c0c0"
    readonly property color c_border: theme ? theme.bgBorder : "#333333"
    readonly property color c_text: theme ? theme.textPrimary : "#e0e0e0"
    readonly property color c_muted: theme ? theme.textMuted : "#8a8a8a"
    readonly property color c_accent: theme ? theme.accentPrimary : "#7aa2f7"
    function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    function handle(event) {
        kp.keyPressed(event)
        if (event.accepted) return
        const ctrl = event.modifiers & Qt.ControlModifier
        if (event.key === Qt.Key_Escape) {
            if (kp.input && kp.query !== "" && !kp.multiline) kp.query = ""
            else kp.open = false
            event.accepted = true
        } else if (kp.columns > 0 && kp.body === null && (event.key === Qt.Key_Left || event.key === Qt.Key_Right
                   || event.key === Qt.Key_Up || event.key === Qt.Key_Down)) {
            // the grid: across with ← →, a row up or down with ↑ ↓, staying on the grid
            const n = kp.items.length
            if (n) {
                const step = event.key === Qt.Key_Left ? -1 : event.key === Qt.Key_Right ? 1
                           : event.key === Qt.Key_Up ? -kp.columns : kp.columns
                const next = kp.current + step
                if (next >= 0 && next < n) kp.current = next
                else if (step === 1 || step === -1) kp.current = (next + n) % n
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Down || (event.key === Qt.Key_Tab && !kp.multiline)) {
            if (kp.items.length) kp.current = (kp.current + 1) % kp.items.length
            event.accepted = true
        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
            if (kp.items.length) kp.current = (kp.current - 1 + kp.items.length) % kp.items.length
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (kp.multiline && !ctrl) return
            kp.activated(kp.items[kp.current] || null, kp.current, event.modifiers)
            event.accepted = true
        }
    }

    PanelWindow {
        id: win
        visible: veil.shown
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: veil.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace: veil.layerName(kp.name)
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }

        MouseArea {
            anchors.fill: parent
            onClicked: kp.open = false
            Backdrop { id: veil; open: kp.open; theme: kp.theme; tintAlpha: kp.theme ? kp.theme.bgOverlay.a : 0.35 }
        }

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: Math.min(kp.panelWidth, parent.width - 48)
            height: Math.min(kp.panelHeight, parent.height - 48)
            radius: 16
            color: kp.c_bg
            border.width: 1
            border.color: kp.c_border
            opacity: veil.progress
            scale: 0.97 + 0.03 * veil.progress
            MouseArea { anchors.fill: parent; onClicked: field.forceActiveFocus() }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                // its name
                Text {
                    Layout.fillWidth: true
                    text: (kp.icon !== "" ? kp.icon + "  " : "") + kp.heading
                    color: kp.c_accent
                    font.pixelSize: 14
                    font.family: kp.font
                    font.bold: true
                    elide: Text.ElideRight
                }

                // the search line
                Rectangle {
                    visible: kp.input && !kp.multiline
                    Layout.fillWidth: true
                    implicitHeight: 44
                    radius: 10
                    color: kp.c_surface
                    border.width: 1
                    border.color: field.activeFocus ? kp.c_accent : kp.c_border
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 10
                        Text {
                            text: "\u{F0349}"
                            color: kp.c_muted
                            font.pixelSize: 16
                            font.family: kp.font
                            Layout.alignment: Qt.AlignVCenter
                        }
                        TextInput {
                            id: field
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            color: kp.c_text
                            selectionColor: kp.tint(kp.c_accent, 0.4)
                            font.family: kp.font
                            font.pixelSize: 15
                            clip: true
                            text: kp.query
                            onTextEdited: kp.query = text
                            Keys.onPressed: event => kp.handle(event)
                            Accessible.role: Accessible.EditableText
                            Accessible.name: kp.placeholder
                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                visible: field.text === ""
                                text: kp.placeholder
                                color: kp.c_muted
                                font: field.font
                            }
                        }
                    }
                }

                // how many there are
                Text {
                    visible: kp.body === null && kp.countText !== "" && kp.items.length > 0
                    text: kp.countText
                    color: kp.c_muted
                    font.pixelSize: 11
                    font.family: kp.font
                }

                // the grid: each item a tile, its glyph large
                GridView {
                    id: grid
                    visible: kp.body === null && kp.columns > 0
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: visible ? kp.items : []
                    currentIndex: kp.current
                    cellWidth: Math.floor(width / Math.max(1, kp.columns))
                    cellHeight: cellWidth
                    highlightMoveDuration: 100
                    boundsBehavior: Flickable.StopAtBounds
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)
                    // a bar at the side whenever more tiles wait below, so it's clear the grid scrolls
                    ScrollBar.vertical: ScrollBar {
                        policy: grid.contentHeight > grid.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                        contentItem: Rectangle {
                            implicitWidth: 4
                            radius: 2
                            color: kp.c_muted
                        }
                    }
                    highlight: Rectangle {
                        width: grid.cellWidth
                        height: grid.cellHeight
                        radius: 10
                        color: kp.c_selected
                        border.width: 1
                        border.color: kp.c_accent
                    }
                    delegate: Item {
                        id: tile
                        required property var modelData
                        required property int index
                        width: grid.cellWidth
                        height: grid.cellHeight
                        Accessible.role: Accessible.Button
                        Accessible.name: modelData.title || ""
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 1
                            radius: 10
                            color: tileArea.containsMouse && tile.index !== kp.current ? kp.c_hover : "transparent"
                        }
                        Text {
                            anchors.centerIn: parent
                            text: tile.modelData.glyph || tile.modelData.icon || ""
                            textFormat: Text.PlainText
                            color: kp.c_text
                            font.pixelSize: Math.round(grid.cellWidth * 0.5)
                        }
                        MouseArea {
                            id: tileArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPositionChanged: kp.current = tile.index
                            onClicked: { kp.current = tile.index; kp.activated(tile.modelData, tile.index, 0) }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: kp.items.length === 0
                        text: kp.emptyText
                        color: kp.c_muted
                        font.family: kp.font
                        font.pixelSize: 14
                    }
                }
                // the tile you are on, by name
                Text {
                    visible: kp.body === null && kp.columns > 0 && kp.items.length > 0
                    Layout.fillWidth: true
                    readonly property var cur: kp.items[kp.current] || ({})
                    text: (cur.title || "") + (cur.sub ? "   " + cur.sub : "")
                    textFormat: Text.PlainText
                    color: kp.c_text2
                    font.family: kp.font
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                // the list
                ListView {
                    id: list
                    visible: kp.body === null && kp.columns === 0
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 2
                    model: visible ? kp.items : []
                    currentIndex: kp.current
                    highlightMoveDuration: 150
                    highlightMoveVelocity: -1
                    boundsBehavior: Flickable.StopAtBounds
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                    highlight: Rectangle {
                        radius: 8
                        color: kp.c_selected
                        Rectangle {
                            width: 3
                            height: 24
                            radius: 2
                            color: kp.c_accent
                            anchors.left: parent.left
                            anchors.leftMargin: 2
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    delegate: Item {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool on: index === kp.current
                        width: ListView.view.width
                        height: 44
                        Accessible.role: Accessible.Button
                        Accessible.name: (modelData.title || "") + (modelData.sub ? " - " + modelData.sub : "")
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 12
                            Rectangle {
                                visible: !!row.modelData.swatch
                                Layout.preferredWidth: 26
                                Layout.preferredHeight: 26
                                radius: 6
                                color: row.modelData.swatch || "transparent"
                                border.width: 1
                                border.color: kp.c_border
                            }
                            Text {
                                visible: !row.modelData.swatch
                                Layout.preferredWidth: 28
                                horizontalAlignment: Text.AlignHCenter
                                text: row.modelData.icon || ""
                                color: kp.c_accent
                                font.family: kp.font
                                font.pixelSize: 20
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 1
                                Text {
                                    Layout.fillWidth: true
                                    text: row.modelData.title || ""
                                    textFormat: Text.PlainText
                                    color: row.on ? kp.c_text : kp.c_text2
                                    font.family: kp.font
                                    font.pixelSize: 13
                                    font.bold: row.on
                                    elide: Text.ElideRight
                                }
                                Text {
                                    visible: !!row.modelData.sub
                                    Layout.fillWidth: true
                                    text: row.modelData.sub || ""
                                    textFormat: Text.PlainText
                                    color: kp.c_muted
                                    font.family: kp.font
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                            }
                            Text {
                                visible: !!row.modelData.hint
                                text: row.modelData.hint || ""
                                textFormat: Text.PlainText
                                color: kp.c_muted
                                font.family: kp.font
                                font.pixelSize: 11
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPositionChanged: kp.current = row.index
                            onClicked: { kp.current = row.index; kp.activated(row.modelData, row.index, 0) }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: kp.items.length === 0
                        text: kp.emptyText
                        color: kp.c_muted
                        font.family: kp.font
                        font.pixelSize: 14
                    }
                }

                // or the plugin's own content
                Loader {
                    id: bodyLoader
                    visible: kp.body !== null
                    active: kp.body !== null && kp.open
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    sourceComponent: kp.body
                    focus: true
                }

                Text {
                    visible: kp.status !== ""
                    Layout.fillWidth: true
                    text: kp.status
                    textFormat: Text.PlainText
                    color: kp.c_muted
                    font.family: kp.font
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                }

                // the keys, and its small buttons
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16
                    Repeater {
                        model: kp.hints
                        delegate: Row {
                            required property var modelData
                            spacing: 4
                            Rectangle {
                                width: keyLabel.implicitWidth + 8
                                height: 18
                                radius: 4
                                color: kp.c_surface
                                Text {
                                    id: keyLabel
                                    anchors.centerIn: parent
                                    text: kp.keyText(modelData[0])
                                    color: kp.c_muted
                                    font.family: kp.font
                                    font.pixelSize: 10
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData[1]
                                color: kp.c_muted
                                font.family: kp.font
                                font.pixelSize: 10
                            }
                        }
                    }
                    Item { Layout.fillWidth: true }
                    Repeater {
                        model: kp.actions
                        delegate: Rectangle {
                            id: act
                            required property var modelData
                            width: actLabel.implicitWidth + 16
                            height: 20
                            radius: 6
                            color: actArea.containsMouse ? kp.c_hover : kp.c_surface
                            Text {
                                id: actLabel
                                anchors.centerIn: parent
                                text: act.modelData.label
                                color: kp.c_accent
                                font.family: kp.font
                                font.pixelSize: 10
                            }
                            MouseArea {
                                id: actArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: kp.action(act.modelData.key)
                            }
                        }
                    }
                }
            }
            // keys work wherever the focus is in the panel
            Keys.onPressed: event => kp.handle(event)
        }
    }

    // the text field, for a plugin's body to give focus back to
    function focusField() { field.forceActiveFocus() }
}
