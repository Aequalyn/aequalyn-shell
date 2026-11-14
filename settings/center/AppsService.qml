// Default apps: which app opens web pages, folders, text, videos and the terminal.
// Lives as long as the control center, so `qs ipc call aequalyn setDefault` works
// with the window closed.
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: svc
    // category -> [{ id, name }], and category -> the id in use
    property var apps: ({})
    property var current: ({})
    readonly property var categories: [
        { key: "browser",     label: "Web pages",      hint: "Super + B opens it" },
        { key: "fileManager", label: "Folders",        hint: "Super + E opens it" },
        { key: "terminal",    label: "Terminal",       hint: "Super + Enter opens it" },
        { key: "textEditor",  label: "Text files",     hint: "" },
        { key: "videoPlayer", label: "Videos",         hint: "" }
    ]

    function refresh() { if (!listProc.running) listProc.running = true; }

    function set(category, appId, appName) {
        if (!appId) return;
        const name = appName || appId;
        setProc.command = ["sh", "-c", command(category, appId, name)];
        setProc.running = true;
        const c = Object.assign({}, current);
        c[category] = appId;
        current = c;
    }

    function command(category, appId, appName) {
        const q = s => "'" + String(s).replace(/'/g, "'\\''") + "'";
        const notify = msg => "notify-send 'Default apps' " + q(msg);
        switch (category) {
        case "textEditor":  return "xdg-mime default " + q(appId) + " text/plain; " + notify(appName + " now opens text files.");
        case "browser":     return "xdg-mime default " + q(appId) + " text/html x-scheme-handler/http x-scheme-handler/https; hyprctl reload >/dev/null 2>&1 || true; " + notify(appName + " now opens web pages. Super+B opens it.");
        case "videoPlayer": return "xdg-mime default " + q(appId) + " video/mp4 video/x-matroska video/webm video/avi video/quicktime; " + notify(appName + " now plays videos.");
        case "terminal":    return "mkdir -p ~/.config && printf '%s\\n' " + q(appId) + " > ~/.config/xdg-terminals.list; hyprctl reload >/dev/null 2>&1 || true; " + notify(appName + " is now your terminal. Super+Enter opens it.");
        case "fileManager": return "xdg-mime default " + q(appId) + " inode/directory; hyprctl reload >/dev/null 2>&1 || true; " + notify(appName + " now opens folders. Super+E opens it.");
        }
        return "true";
    }

    // the apps of a category, the one in use included even when it isn't listed
    function choices(category) {
        const list = (apps[category] || []).map(a => ({ key: a.id, label: a.name }));
        const cur = current[category];
        if (cur && !list.some(a => a.key === cur)) list.push({ key: cur, label: cur });
        return list;
    }

    property Process listProc: Process {
        command: ["aequalyn-default-apps"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text.trim());
                    svc.apps = j.apps || {};
                    svc.current = j.current || {};
                } catch (e) {
                    console.log("default apps: " + e);
                }
            }
        }
    }
    property Process setProc: Process {
        onExited: svc.refresh()
    }
}
