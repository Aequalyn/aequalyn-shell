// Web apps: websites in their own window. The `aequalyn-webapp` command owns the
// state (~/.config/aequalyn/webapps.json, desktop entries, the Hyprland binds);
// this service just shows it and runs it. Lives as long as the control center,
// so `qs ipc call aequalyn webapps` can open the page with the window closed.
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: svc
    property var apps: []
    property var browsers: []
    property var categories: []      // [{ id, label, count }]: your categories, in order
    property string browser: "auto"
    property string resolved: ""
    property string resolvedLabel: ""
    property string pendingInstall: ""
    property bool busy: false
    property string error: ""
    property string note: ""
    signal added()
    signal categoryAdded()

    function refresh() { if (!listProc.running) listProc.running = true; }

    function setBrowser(id) {
        if (!id || id === browser) return;
        run("browser", ["set-browser", id], "")
    }

    function installBrowser(id) {
        const b = (svc.browsers || []).find(x => x.id === id);
        if (!b || b.available) return;
        const pkg = b.package || "";
        if (!pkg) return;
        const cmd = (b.aur ? "yay -S --noconfirm " : "sudo pacman -S --noconfirm ") + pkg;
        svc.pendingInstall = id;
        svc.error = "";
        svc.note = "Installing " + b.label + " in a terminal...";
        terminalProc.command = ["xdg-terminal-exec", "bash", "-c",
            cmd + "; echo; read -n1 -s -r -p 'Press any key to close...'"];
        terminalProc.running = true;
    }

    // category: an id from `categories`, or "" for none
    function add(name, url, category) {
        const args = ["add", "--name", name, "--url", url];
        if (category) args.push("--category", category);
        run("add", args, "")
    }
    function setCategory(slug, category) {
        run("category", ["set-category", slug, category || "none"], "")
    }
    // your categories: a new (empty) one, a new name, or gone (its web apps then
    // have no category)
    function addCategory(label) {
        run("catadd", ["category-add", label], "Added " + label + ".")
    }
    function renameCategory(id, label) {
        run("catrename", ["category-rename", id, label], "")
    }
    function removeCategory(id) {
        run("catremove", ["category-remove", id], "")
    }

    function remove(slug) {
        run("remove", ["remove", slug], "")
    }

    function open(slug) {
        Quickshell.execDetached(["aequalyn-webapp", "launch", slug]);
    }

    // one action at a time; `kind` decides what to do when it succeeds
    function run(kind, args, done) {
        if (action.running) return;
        error = "";
        note = "";
        pending = kind;
        lastKind = kind;
        pendingNote = done;
        action.command = ["sh", "-c", command(args)];
        action.running = true;
    }

    property string pending: ""
    property string lastKind: ""     // the last action run ("add", "catadd", ...), for where its message shows
    property string pendingNote: ""

    function command(args) {
        const q = s => "'" + String(s).replace(/'/g, "'\\''") + "'";
        return "aequalyn-webapp " + args.map(q).join(" ") + " 2>&1";
    }

    property Process listProc: Process {
        command: ["aequalyn-webapp", "list", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text.trim());
                    svc.apps = j.apps || [];
                    svc.browsers = j.browsers || [];
                    svc.categories = j.categories || [];
                    svc.browser = j.browser || "auto";
                    svc.resolved = j.resolved || "";
                    svc.resolvedLabel = j.resolvedLabel || "";
                    if (svc.pendingInstall !== "") {
                        const bid = svc.pendingInstall;
                        const bb = (j.browsers || []).find(x => x.id === bid);
                        if (bb && bb.available) {
                            svc.note = "Installed " + bb.label + ".";
                            svc.setBrowser(bid);
                        } else {
                            svc.note = "Install did not complete.";
                        }
                        svc.pendingInstall = "";
                    }
                } catch (e) {
                    console.log("web apps: " + e);
                }
            }
        }
    }

    property Process action: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                svc.busy = false;
                if (action.exitCode === 0) {
                    svc.note = svc.pendingNote;
                    if (svc.pending === "add") svc.added();
                    if (svc.pending === "catadd") svc.categoryAdded();
                } else {
                    const msg = text.trim().split("\n")[0]
                        .replace(/^aequalyn-webapp:\s*/, "");
                    svc.error = msg || "That did not work.";
                }
                svc.pending = "";
                svc.pendingNote = "";
                svc.refresh();
            }
        }
        onRunningChanged: svc.busy = running
    }

    property Process terminalProc: Process {
        onExited: (code) => {
            svc.refresh();
        }
    }
}
