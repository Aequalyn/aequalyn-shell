// Backup: save the setup to a file in your home folder, or bring one back.
// The file holds settings.json, pinned apps, the Hyprland settings and the installed
// packages (Arch and AUR).
import QtQuick
import Quickshell.Io

QtObject {
    id: svc
    property string status: ""
    property string lastFile: ""
    readonly property bool busy: exportProc.running || importProc.running

    function refresh() { if (!findProc.running) findProc.running = true; }
    function save() { status = ""; exportProc.running = true; }
    function restore() { status = ""; importProc.running = true; }

    property Process findProc: Process {
        command: ["bash", "-lc", "ls -1t \"$HOME\"/Aequalyn-export-*.json 2>/dev/null | head -n1 || true"]
        stdout: StdioCollector { onStreamFinished: svc.lastFile = text.trim() }
    }
    property Process exportProc: Process {
        command: ["aequalyn-export-settings"]
        stdout: StdioCollector {
            onStreamFinished: { const p = text.trim(); if (p.length > 0) svc.status = "Saved to " + p; }
        }
        stderr: StdioCollector {
            onStreamFinished: { const e = text.trim(); if (e.length > 0 && svc.status === "") svc.status = "Couldn't save: " + e; }
        }
        onExited: (code, status) => {
            if (code !== 0 && svc.status === "") svc.status = "Couldn't save (exit " + code + ")";
            if (code === 0) svc.refresh();
        }
    }
    property Process importProc: Process {
        command: ["bash", "-lc", "file=$(zenity --file-selection --title='Bring back an Aequalyn setup' --file-filter='JSON files (*.json) | *.json' --file-filter='All files | *' 2>/dev/null || kdialog --getopenfilename \"$HOME\" '*.json' 2>/dev/null || true); if [ -n \"$file\" ]; then aequalyn-import-settings \"$file\"; else echo '__CANCELLED__'; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = text.trim();
                svc.status = out === "__CANCELLED__" || out.length === 0 ? "Nothing brought back." : out;
            }
        }
        stderr: StdioCollector {
            onStreamFinished: { const e = text.trim(); if (e.length > 0 && svc.status.indexOf("Couldn't") !== 0) svc.status = "Couldn't bring it back: " + e; }
        }
        onExited: (code, status) => {
            if (code !== 0 && svc.status === "") svc.status = "Couldn't bring it back (exit " + code + ")";
            if (code === 0) svc.refresh();
        }
    }
}
