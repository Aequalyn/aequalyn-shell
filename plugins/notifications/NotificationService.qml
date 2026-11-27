// Singleton notification daemon/service for the Aequalyn shell.
// Registers a Quickshell NotificationServer, converts incoming notifications
// into NotificationData instances, maintains the active popup list, enforces a
// max visible count, and provides dismiss/DND helpers (also used by IPC).
//
// Every notification is also appended to a persistent log (Clipscape-style
// atomic JSON in the state dir) before it is suppressed, dismissed or expires,
// so a message you missed can be read again from the history panel.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import "root:/plugins/kit"
import "js/History.js" as History

Singleton {
    id: root

    property list<var> notifications: []
    property bool doNotDisturb: false
    readonly property int count: notifications.length
    property int _seqCounter: 0

    // ---- the persistent log ------------------------------------------------
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME")
        || Quickshell.env("HOME") + "/.local/state") + "/aequalyn"
    readonly property string historyPath: stateDir + "/notification-history.json"
    property bool dirReady: false
    property bool historyReady: false
    property var history: []
    property bool historyVisible: false
    property string historyMonitor: ""
    property string selectedId: ""

    function _historyText() {
        try {
            return String(typeof historyFile.text === "function" ? historyFile.text() : historyFile.text)
        } catch (e) { return "" }
    }

    function _loadHistory(raw) {
        root.history = History.parseStore(raw)
        root.historyReady = true
    }

    function _record(notification, suppressed) {
        if (!root.historyReady) return
        if (!notification || (!notification.summary && !notification.body
                              && !notification.appName && !notification.image)) return
        const e = History.entry(notification, root._seqCounter++, suppressed === true)
        root.history = History.add(root.history, e)
        saveTimer.restart()
    }

    function historyEntry(id) { return History.find(root.history, id) }
    function clearHistory() {
        root.history = []
        root.selectedId = ""
        saveTimer.restart()
    }
    function removeHistoryEntry(id) {
        root.history = History.remove(root.history, id)
        if (root.selectedId === id) root.selectedId = ""
        saveTimer.restart()
    }
    function copyHistoryEntry(id) {
        const e = root.historyEntry(id)
        if (!e) return false
        KitHost.copy(e.text || e.summary || "")
        return true
    }
    function openHistory(monitor) {
        root.historyMonitor = String(monitor || "")
        root.historyVisible = true
    }
    function closeHistory() { root.historyVisible = false; root.selectedId = "" }
    function toggleHistory() { if (root.historyVisible) root.closeHistory(); else root.openHistory() }

    Timer {
        id: saveTimer
        interval: 300
        onTriggered: if (root.historyReady) historyFile.setText(History.serialize(root.history))
    }
    Process {
        id: mkdir
        command: ["mkdir", "-p", root.stateDir]
        onExited: root.dirReady = true
    }
    Component.onCompleted: mkdir.running = true

    FileView {
        id: historyFile
        path: root.dirReady ? root.historyPath : ""
        atomicWrites: true
        printErrors: false
        onLoaded: root._loadHistory(root._historyText())
        onLoadFailed: root.historyReady = true
        onSaveFailed: console.warn("Aequalyn notifications: could not save history")
    }

    Component {
        id: notifDataComp
        NotificationData {}
    }

    NotificationServer {
        id: server
        actionsSupported:    true
        bodySupported:       true
        bodyMarkupSupported: true
        imageSupported:      true
        keepOnReload:        false

        onNotification: function(notification) {
            if (!notification.appName && !notification.summary
                && !notification.body && !notification.image) return;

            // Archive before DND hides it or a later dismiss destroys it.
            root._record(notification, root.doNotDisturb);
            if (root.doNotDisturb) return;

            notification.tracked = true;

            const idStr = String(notification.id || "");
            if (idStr !== "") {
                const existing = root.notifications.find(function(n) {
                    return n.notifId === idStr;
                });
                if (existing && !existing.closed) {
                    existing.closed = true;
                    root.notifications = root.notifications.filter(function(n) {
                        return n !== existing;
                    });
                    existing.destroy();
                }
            }

            const data = notifDataComp.createObject(root, {
                notification: notification,
                seqId: String(root._seqCounter++)
            });

            root.notifications = [data, ...root.notifications];

            if (root.notifications.length > 5) {
                root.notifications[root.notifications.length - 1].dismiss();
            }
        }
    }

    function _remove(notifData): void {
        root.notifications = root.notifications.filter(function(n) {
            return n !== notifData;
        });
    }

    function dismiss(notifData): void {
        if (notifData) notifData.dismiss();
    }

    function dismissAll(): void {
        const toRemove = [...root.notifications];
        root.notifications = [];
        for (const n of toRemove) {
            if (!n.closed) {
                n.closed = true;
                if (n.notification) try { n.notification.dismiss(); } catch(e) {}
                n.destroy();
            }
        }
    }
}
