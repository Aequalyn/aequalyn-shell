// A keyboard-first re-reader for the notification log, drawn with the Control
// Center's own controls. It does not restore a live notification (its actions
// and timeout are gone); it shows the saved text again so a message you could
// not screenshot can still be read, copied or deleted. Opened from the quick
// panel's Notifications ›, Super + Ctrl + N, the command palette or IPC.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "root:/settings"
import "root:/settings/center"
import "js/History.js" as History

Scope {
    id: root
    property bool open: false
    readonly property bool panelOpen: open

    // the monitor that asked for the panel: it never follows the focus later.
    // The quick panel passes its own screen; otherwise Hyprland's focus (or the
    // first screen) is used as a fallback.
    readonly property string monitor: NotificationService.historyMonitor !== "" ? NotificationService.historyMonitor
        : (Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name
           : (Quickshell.screens.length ? Quickshell.screens[0].name : ""))
    property string mode: "app"        // app | dnd | all
    property string appFilter: ""      // "" = every app
    property string selectedId: ""
    property string query: ""

    function close() { NotificationService.closeHistory() }
    function step(delta) {
        const total = root.rows.length
        if (total === 0) return
        root.selectedId = root.rows[(root.rows.findIndex(r => r.entryId === root.selectedId)
            + delta + total) % total].entryId
    }
    function copy(id) { if (id) NotificationService.copyHistoryEntry(id) }
    function remove(id) {
        if (!id) return
        NotificationService.removeHistoryEntry(id)
        if (root.selectedId === id) root.selectedId = ""
    }

    readonly property var appNames: {
        const seen = {}
        NotificationService.history.forEach(function(e) {
            const name = e.appName || "Other apps"
            seen[name] = true
        })
        return Object.keys(seen).sort(function(a, b) { return a.localeCompare(b) })
    }
    readonly property var rows: {
        let list = NotificationService.history
        if (root.mode === "dnd") list = list.filter(function(e) { return e.suppressed === true })
        if (root.appFilter !== "")
            list = list.filter(function(e) { return (e.appName || "Other apps") === root.appFilter })
        list = History.search(list, root.query)
        const rowOf = function(e) {
            return {
                entryId: e.id,
                group: root.mode === "app" ? (e.appName || "Other apps") : "While in DND",
                icon: e.suppressed ? "\u{F00D5}" : (e.urgency === 2 ? "\u{F0211}" : "\u{F009A}"),
                title: e.summary || e.body.slice(0, 60) || "Notification",
                sub: (e.appName || "An app") + "  ·  " + History.timeLabel(e.at)
                     + (e.suppressed ? "  ·  received during Do not disturb" : "")
                     + (e.body ? "  ·  " + e.body.replace(/\n/g, " ").slice(0, 70) : "")
            };
        };
        return list.map(rowOf).sort(function(a, b) {
            const g = a.group.localeCompare(b.group)
            const ea = NotificationService.historyEntry(a.entryId)
            const eb = NotificationService.historyEntry(b.entryId)
            return g !== 0 ? g : ((eb && eb.at) - (ea && ea.at))
        });
    }

    onOpenChanged: {
        if (open) {
            root.selectedId = root.rows.length ? root.rows[0].entryId : ""
        } else {
            root.query = ""
            root.appFilter = ""
            root.mode = "app"
            root.selectedId = ""
        }
    }
    onRowsChanged: {
        if (root.selectedId === "" && root.rows.length) root.selectedId = root.rows[0].entryId
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            visible: root.open && modelData.name === root.monitor
            focusable: visible
            color: "transparent"

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            WlrLayershell.namespace: "aequalyn-notification-history"
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true; right: true }

            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) { root.close(); event.accepted = true }
                else if (event.key === Qt.Key_Up) { root.step(-1); event.accepted = true }
                else if (event.key === Qt.Key_Down) { root.step(1); event.accepted = true }
            }
            onVisibleChanged: if (visible) Qt.callLater(function() { field.forceActiveFocus() })

            MouseArea {
                anchors.fill: parent
                onClicked: root.close()
            }

            Rectangle {
                id: card
                anchors.centerIn: parent
                width: Math.min(700, parent.width - 48)
                height: Math.min(580, parent.height - 48)
                radius: 14
                color: Cc.theme.bgBase
                border.width: 1
                border.color: Cc.theme.bgBorder
                MouseArea { anchors.fill: parent; onClicked: field.forceActiveFocus() }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 10

                    Text {
                        text: "NOTIFICATION HISTORY"
                        color: Cc.theme.textSecondary
                        font.family: Cc.sans
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1
                        Layout.fillWidth: true
                    }

                    CcChoice {
                        options: [
                            { key: "app", label: "By application" },
                            { key: "dnd", label: "While in DND" },
                            { key: "all", label: "All" }
                        ]
                        current: root.mode
                        onChosen: key => { root.mode = key; root.selectedId = root.rows.length ? root.rows[0].entryId : "" }
                    }

                    CcChoice {
                        visible: root.mode !== "dnd" && root.appNames.length > 0
                        options: [{ key: "", label: "All apps" }].concat(root.appNames.map(function(name) {
                            return { key: name, label: name }
                        }))
                        current: root.appFilter
                        onChosen: key => { root.appFilter = key; root.selectedId = root.rows.length ? root.rows[0].entryId : "" }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 38
                        radius: 8
                        color: Cc.alpha(Cc.theme.textPrimary, 0.05)
                        border.width: 1
                        border.color: Cc.alpha(Cc.theme.textPrimary, field.activeFocus ? 0.28 : 0.08)
                        TextInput {
                            id: field
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            verticalAlignment: TextInput.AlignVCenter
                            color: Cc.theme.textPrimary
                            font.family: Cc.sans
                            font.pixelSize: 12
                            Keys.onEscapePressed: root.close()
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: field.text === "" && !field.activeFocus
                                text: "Search notifications"
                                color: Cc.alpha(Cc.theme.textPrimary, 0.4)
                                font: field.font
                            }
                        }
                        Connections {
                            target: field
                            function onTextChanged() { root.query = field.text }
                        }
                    }

                    CcNote {
                        text: root.rows.length + (root.rows.length === 1 ? " message" : " messages")
                              + "  ·  " + NotificationService.history.length + " saved until you clear them"
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: root.rows
                        section.property: "group"
                        section.criteria: ViewSection.FullString
                        section.delegate: Text {
                            width: ListView.view.width
                            height: 26
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: 4
                            text: section.toUpperCase()
                            color: Cc.theme.textSecondary
                            font.family: Cc.sans
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                            font.letterSpacing: 1
                            opacity: 0.45
                        }
                        delegate: CcRow {
                            required property var modelData
                            required property int index
                            width: ListView.view.width
                            icon: modelData.icon
                            title: modelData.title
                            sub: modelData.sub
                            highlight: modelData.entryId === root.selectedId
                            clickable: true
                            action: "Copy"
                            action2: "Delete"
                            danger2: true
                            onClicked: root.selectedId = modelData.entryId
                            onActivated: root.copy(modelData.entryId)
                            onActivated2: root.remove(modelData.entryId)
                        }
                    }

                    CcNote {
                        visible: root.rows.length === 0
                        text: "No notifications match this view."
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text {
                            text: "↑ ↓ select    ⏎ read the saved text"
                            color: Cc.theme.textMuted
                            font.family: Cc.sans
                            font.pixelSize: 9
                            Layout.fillWidth: true
                        }
                        CcButton { text: "Clear all"; danger: true; onClicked: NotificationService.clearHistory() }
                        CcButton { text: "Close"; onClicked: root.close() }
                    }
                }
            }
        }
    }
}
