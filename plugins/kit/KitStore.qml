// A plugin's own settings and data: one JSON file in ~/.local/state/aequalyn/<id>/,
// read once at start and written a moment after each change.
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: store
    property string pluginId: ""
    property string fileName: "settings.json"
    property var defaults: ({})
    property var values: ({})
    property bool loaded: false
    readonly property string dir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/aequalyn/" + pluginId
    readonly property string path: dir + "/" + fileName

    function get(key) { return values[key] !== undefined ? values[key] : defaults[key] }
    function set(key, value) {
        const next = Object.assign({}, values)
        next[key] = value
        values = next
        saveTimer.restart()
    }

    Timer { id: saveTimer; interval: 300; onTriggered: file.setText(JSON.stringify(store.values, null, 2) + "\n") }
    Process {
        id: mkdir
        command: ["mkdir", "-p", store.dir]
        onExited: file.reload()
    }
    Component.onCompleted: if (pluginId !== "") mkdir.running = true
    Component.onDestruction: if (saveTimer.running) file.setText(JSON.stringify(store.values, null, 2) + "\n")
    FileView {
        id: file
        path: store.pluginId !== "" ? store.path : ""
        printErrors: false
        // another part of the shell may write it too (the Plugins page)
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            let v = {}
            try { v = JSON.parse(text()) } catch (e) { v = {} }
            store.values = v && typeof v === "object" && !Array.isArray(v) ? v : {}
            store.loaded = true
        }
        onLoadFailed: store.loaded = true
    }
}
