// The built-in pack's panel: a keyboard-first window over the shell's backdrop, the
// same for every plugin that uses it. A line to type in, a list to move through, and
// keys at the bottom:
//   type        search, or the plugin's own input     ↑ ↓ / Tab   move
//   Enter       the plugin's action on the row        Esc         clear, then close
// A plugin sets `items` ({ icon, title, sub, hint, swatch }) and answers `activated`;
// one that needs more shows its own `body` under the line instead of the list.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "root:/style/backdrop"

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
    property real panelWidth: 660
    property real panelHeight: 480
    property bool multiline: false               // Enter adds a line; Ctrl + Enter is the action
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
            Backdrop { id: veil; open: kp.open; theme: kp.theme; tintAlpha: 0.35 }
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

                // the line: the plugin's name, and what you type
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Text {
                        text: kp.icon
                        color: kp.c_accent
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 18
                    }
                    Text {
                        visible: !kp.input
                        Layout.fillWidth: true
                        text: kp.title
                        color: kp.c_text
                        font.family: "sans-serif"
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                    }
                    Rectangle {
                        visible: kp.input
                        Layout.fillWidth: true
                        implicitHeight: kp.multiline ? 0 : 38
                        radius: 10
                        color: kp.c_surface
                        border.width: 1
                        border.color: field.activeFocus ? kp.c_accent : kp.c_border
                        TextInput {
                            id: field
                            visible: !kp.multiline
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            verticalAlignment: TextInput.AlignVCenter
                            color: kp.c_text
                            selectionColor: kp.tint(kp.c_accent, 0.4)
                            font.family: "sans-serif"
                            font.pixelSize: 14
                            clip: true
                            text: kp.query
                            onTextEdited: kp.query = text
                            Keys.onPressed: event => kp.handle(event)
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: field.text === ""
                                text: kp.placeholder
                                color: kp.c_muted
                                font: field.font
                            }
                        }
                    }
                }

                // the list
                ListView {
                    id: list
                    visible: kp.body === null
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 2
                    model: kp.items
                    currentIndex: kp.current
                    highlightMoveDuration: 80
                    boundsBehavior: Flickable.StopAtBounds
                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool on: index === kp.current
                        width: ListView.view.width
                        height: modelData.sub ? 48 : 38
                        radius: 9
                        color: on ? kp.tint(kp.c_accent, 0.16) : (rowArea.containsMouse ? kp.c_hover : "transparent")
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 12
                            spacing: 10
                            Rectangle {
                                visible: !!row.modelData.swatch
                                Layout.preferredWidth: 22
                                Layout.preferredHeight: 22
                                radius: 6
                                color: row.modelData.swatch || "transparent"
                                border.width: 1
                                border.color: kp.c_border
                            }
                            Text {
                                visible: !row.modelData.swatch && !!row.modelData.icon
                                Layout.preferredWidth: 24
                                horizontalAlignment: Text.AlignHCenter
                                text: row.modelData.icon || ""
                                color: row.on ? kp.c_accent : kp.c_muted
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 16
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text {
                                    Layout.fillWidth: true
                                    text: row.modelData.title || ""
                                    textFormat: Text.PlainText
                                    color: kp.c_text
                                    font.family: "sans-serif"
                                    font.pixelSize: 13
                                    elide: Text.ElideRight
                                }
                                Text {
                                    visible: !!row.modelData.sub
                                    Layout.fillWidth: true
                                    text: row.modelData.sub || ""
                                    textFormat: Text.PlainText
                                    color: kp.c_muted
                                    font.family: "sans-serif"
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                            }
                            Text {
                                visible: !!row.modelData.hint
                                text: row.modelData.hint || ""
                                textFormat: Text.PlainText
                                color: kp.c_muted
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                            }
                        }
                        MouseArea {
                            id: rowArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { kp.current = row.index; kp.activated(row.modelData, row.index, 0) }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: kp.items.length === 0
                        text: kp.emptyText
                        color: kp.c_muted
                        font.family: "sans-serif"
                        font.pixelSize: 13
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
                    font.family: "sans-serif"
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                }

                // the keys
                Row {
                    spacing: 14
                    Repeater {
                        model: kp.hints
                        delegate: Row {
                            required property var modelData
                            spacing: 6
                            Rectangle {
                                width: keyLabel.implicitWidth + 12
                                height: 20
                                radius: 5
                                color: kp.c_surface
                                border.width: 1
                                border.color: kp.c_border
                                Text {
                                    id: keyLabel
                                    anchors.centerIn: parent
                                    text: modelData[0]
                                    color: kp.c_text
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 10
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData[1]
                                color: kp.c_muted
                                font.family: "sans-serif"
                                font.pixelSize: 11
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
