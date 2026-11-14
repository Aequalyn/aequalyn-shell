// Updates: which commit this machine runs, whether GitHub has newer ones, and the
// update itself.
//
// Aequalyn on this machine is two git clones, both owned by root: the system tree
// (/usr/share/aequalyn, from Aequalyn/aequalyn) and the shell inside it (shell/, from
// Aequalyn/aequalyn-shell). Reading them as the user needs git's safe.directory, given
// per command so nothing has to be set up first.
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: svc
    property string systemCommit: ""
    property string systemDate: ""
    property string shellCommit: ""
    // "" (not checked) | "checking" | "same" | "behind" | "failed" | "running"
    property string state: ""
    property var behind: []

    readonly property string status: state === "checking" ? "Checking…"
        : state === "same" ? "Aequalyn is up to date"
        : state === "behind" ? "An update is ready"
        : state === "failed" ? "Couldn't reach GitHub"
        : state === "running" ? "Updating in the terminal…"
        : "Not checked yet"

    function refresh() { if (!commitProc.running) commitProc.running = true; }
    function check() {
        state = "checking";
        refresh();
        if (!checkProc.running) checkProc.running = true;
    }

    // The update needs your password (the clones belong to root), so it runs in a
    // terminal you can type it into. Started detached: aequalyn-update restarts this
    // shell at the end, which would take a terminal started as its child down with it.
    function update() {
        state = "running";
        Quickshell.execDetached(["sh", "-c",
            't=kitty; command -v kitty >/dev/null 2>&1 || t=foot; '
            + 'exec "$t" --title "Aequalyn update" sh -c \'aequalyn-update; s=$?; echo; '
            + 'if [ $s -eq 0 ]; then echo "Aequalyn is up to date."; else echo "The update failed (exit $s)."; fi; '
            + 'printf "Press Enter to close. "; read _\'']);
    }

    property Process commitProc: Process {
        // one line per clone: short hash | commit date
        command: ["sh", "-c", 'for d in /usr/share/aequalyn /usr/share/aequalyn/shell; do '
            + 'git -c safe.directory="$d" -C "$d" log -1 --format="%h|%ci" 2>/dev/null || echo "unknown|"; done']
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                const sys = (lines[0] || "unknown|").split("|"), sh = (lines[1] || "unknown|").split("|");
                svc.systemCommit = sys[0];
                svc.systemDate = sys[1] || "";
                svc.shellCommit = sh[0];
            }
        }
    }
    // compares each clone with GitHub's main (git ls-remote: no API rate limit)
    property Process checkProc: Process {
        command: ["sh", "-c", 'check() { l=$(git -c safe.directory="$1" -C "$1" rev-parse HEAD 2>/dev/null); '
            + 'r=$(git ls-remote "$2" refs/heads/main 2>/dev/null | cut -f1); '
            + 'if [ -z "$r" ]; then echo "$3 failed"; elif [ "$l" = "$r" ]; then echo "$3 same"; else echo "$3 behind"; fi; }; '
            + 'check /usr/share/aequalyn https://github.com/Aequalyn/aequalyn.git system; '
            + 'check /usr/share/aequalyn/shell https://github.com/Aequalyn/aequalyn-shell.git shell']
        stdout: StdioCollector {
            onStreamFinished: {
                const behind = [];
                let failed = false;
                for (const line of text.trim().split("\n")) {
                    const [what, st] = line.split(" ");
                    if (st === "behind") behind.push(what);
                    else if (st !== "same") failed = true;
                }
                svc.behind = behind;
                svc.state = failed ? "failed" : behind.length > 0 ? "behind" : "same";
            }
        }
    }
}
