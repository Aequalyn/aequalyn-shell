// Wallpaper side of Atelier: the wallpaper list, rotation status and every
// call into `aequalyn-wallpaper`. The script owns the logic so the same
// behaviour is available from a terminal, a keybind or an agent; this
// service only queues calls, runs the minute tick and follows workspaces.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "root:/settings"

Singleton {
    id: root

    property var wallpapers: []          // [{path, name, folder, video, generated, theme, thumb}]
    property var status: ({})            // aequalyn-wallpaper status
    property bool loading: false
    readonly property string mode: AequalynSettings.wallpaperCfg.mode || "static"
    readonly property string current: status.current || ""

    readonly property var modes: [
        { key: "static",    icon: "󰋩", name: "Static",      text: "One wallpaper until you pick another." },
        { key: "theme",     icon: "󰏘", name: "Theme set",   text: "The active theme's backgrounds. Super+Ctrl+Space steps through them." },
        { key: "slideshow", icon: "󰒝", name: "Slideshow",   text: "A new wallpaper from your folder on a timer." },
        { key: "daytime",   icon: "󰖨", name: "Time of day", text: "Dawn, day, dusk and night sets that follow the clock." },
        { key: "workspace", icon: "󰕰", name: "Workspaces",  text: "Every workspace keeps its own wallpaper." },
        { key: "live",      icon: "󰕧", name: "Live",        text: "Looping videos behind your windows (mpvpaper)." }
    ]

    function modeInfo(key) {
        for (let i = 0; i < modes.length; i++) if (modes[i].key === key) return modes[i];
        return modes[0];
    }

    // ---- command queue ---------------------------------------------------
    // One Process runs at a time; later calls wait their turn instead of
    // being dropped while an earlier one is still running.
    property var _queue: []

    // run(args, relist): relist = also re-read the wallpaper list afterwards
    // (for commands that create files, like generate).
    function run(args, relist) {
        _queue = _queue.concat([{ args: args, relist: relist === true }]);
        _next();
    }

    function _next() {
        if (worker.running || _queue.length === 0) return;
        const job = _queue[0];
        _queue = _queue.slice(1);
        worker.relist = job.relist;
        worker.command = job.args;
        worker.running = true;
    }

    Process {
        id: worker
        property bool relist: false
        running: false
        onExited: {
            if (relist) root.refresh();
            else statusProc.running = true;
            root._next();
        }
    }

    // ---- actions ---------------------------------------------------------
    function setWallpaper(path) { run(["aequalyn-wallpaper", "set", path]); }
    function next()             { run(["aequalyn-wallpaper", "next"]); }
    function prev()             { run(["aequalyn-wallpaper", "prev"]); }
    function random()           { run(["aequalyn-wallpaper", "random"]); }
    function setMode(m)         { run(["aequalyn-wallpaper", "mode", m]); }
    function generate(style)    { run(["aequalyn-wallpaper", "generate", style], true); }
    function assignWorkspace(ws, path) { run(["aequalyn-wallpaper", "assign", String(ws), path]); }
    function tick()             { run(["aequalyn-wallpaper", "tick"]); }

    function refresh() {
        if (listProc.running) return;
        root.loading = true;
        listProc.running = true;
        statusProc.running = true;
    }

    // After a settings write: give the file a moment to land first.
    function refreshLater() { refreshSoon.restart(); }

    Timer {
        id: refreshSoon
        interval: 1500
        onTriggered: root.refresh()
    }

    Process {
        id: listProc
        running: false
        command: ["aequalyn-wallpaper", "list", "--all", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.wallpapers = JSON.parse(text || "[]"); }
                catch (e) { console.error("aequalyn-wallpaper list:", e); }
                root.loading = false;
            }
        }
    }

    Process {
        id: statusProc
        running: true
        command: ["aequalyn-wallpaper", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.status = JSON.parse(text || "{}"); } catch (e) {}
            }
        }
    }

    // ---- time-driven modes -----------------------------------------------
    // Slideshow, time of day and automatic light/dark need a clock; the
    // script decides whether anything is due, so a tick is cheap.
    Timer {
        interval: 60 * 1000
        repeat: true
        running: root.mode === "slideshow" || root.mode === "daytime"
                 || (AequalynSettings.paletteCfg.mode || "dark") === "auto"
        triggeredOnStart: true
        onTriggered: root.tick()
    }

    // ---- per-workspace wallpapers ----------------------------------------
    Connections {
        target: Hyprland
        enabled: root.mode === "workspace"
        function onFocusedWorkspaceChanged() {
            const ws = Hyprland.focusedWorkspace;
            if (ws) root.run(["aequalyn-wallpaper", "workspace", String(ws.name || ws.id)]);
        }
    }

    readonly property string focusedWorkspace: Hyprland.focusedWorkspace ? String(Hyprland.focusedWorkspace.name || Hyprland.focusedWorkspace.id) : ""
}
