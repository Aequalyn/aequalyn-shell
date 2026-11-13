// Window layouts for Atelier: the catalogue (~/.config/aequalyn/layouts.json,
// generated from the same geometry Hyprland runs) and every call into
// `aequalyn-layout`, which owns saving and applying.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root

    property var catalogue: []
    property var status: ({})   // aequalyn-layout status
    readonly property var groups: ["Focus", "Panes", "Grids", "Flow", "Hyprland"]
    readonly property string focusedWorkspace: Hyprland.focusedWorkspace ? String(Hyprland.focusedWorkspace.id) : (status.focused || "1")

    function layoutOf(ws) {
        const w = status.workspaces || {};
        return w[String(ws)] || status.default || "dwindle";
    }
    function inCycle(id) {
        const c = status.cycle || [];
        return c.length === 0 || c.indexOf(id) >= 0;
    }
    function find(id) {
        for (let i = 0; i < catalogue.length; i++) if (catalogue[i].id === id) return catalogue[i];
        return null;
    }

    // ---- actions (queued, like AtelierService) --------------------------
    property var _queue: []
    function run(args) { _queue = _queue.concat([args]); _next(); }
    function _next() {
        if (worker.running || _queue.length === 0) return;
        worker.command = _queue[0];
        _queue = _queue.slice(1);
        worker.running = true;
    }
    Process {
        id: worker
        running: false
        onExited: { statusProc.running = true; root._next(); }
    }

    function set(id, ws) { run(["aequalyn-layout", "set", id, "--workspace", String(ws)]); }
    function option(key, value) { run(["aequalyn-layout", "option", key, String(value)]); }
    function toggleCycle(id) {
        let c = (status.cycle || []).slice();
        if (c.length === 0) c = catalogue.map(l => l.id);
        const at = c.indexOf(id);
        if (at >= 0) { if (c.length <= 2) return; c.splice(at, 1); }
        else {
            // keep catalogue order
            c.push(id);
            const order = catalogue.map(l => l.id);
            c.sort((a, b) => order.indexOf(a) - order.indexOf(b));
        }
        run(["aequalyn-layout", "cycle"].concat(c));
    }
    function refresh() { statusProc.running = true; }

    FileView {
        path: Quickshell.env("HOME") + "/.config/aequalyn/layouts.json"
        watchChanges: true
        onFileChanged: reload()
        onTextChanged: {
            try { root.catalogue = JSON.parse(text() || "[]"); } catch (e) { console.error("layouts.json:", e); }
        }
    }

    Process {
        id: statusProc
        running: true
        command: ["aequalyn-layout", "status"]
        stdout: StdioCollector {
            onStreamFinished: { try { root.status = JSON.parse(text || "{}"); } catch (e) {} }
        }
    }

    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() { root.refresh(); }
    }
}
