// Runs a command and hands back what it printed. One at a time; `seconds` limits how
// long it may take, and only the first `maxOut` characters are kept.
import QtQuick
import Quickshell.Io

Item {
    id: run
    property int seconds: 20
    property int maxOut: 65536
    readonly property bool running: proc.running
    property string out: ""
    signal done(int code, string out, string err)

    function start(argv) {
        if (proc.running) return false
        run.out = ""
        proc.command = ["timeout", String(run.seconds)].concat(argv)
        proc.running = true
        return true
    }
    function stop() { if (proc.running) proc.signal(15) }

    Process {
        id: proc
        stdout: StdioCollector { id: outC }
        stderr: StdioCollector { id: errC }
        onExited: (code) => {
            const o = String(outC.text || "").slice(0, run.maxOut)
            run.out = o
            run.done(code, o, String(errC.text || "").slice(0, 4096))
        }
    }
}
