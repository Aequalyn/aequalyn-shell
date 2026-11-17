// Screen text (Super + Alt + X): draw a box round any text on the screen, in a
// picture, a video, an app that won't let you select, and it is copied as text.
// Reads it with tesseract; until that is installed, it says how to get it.
import QtQuick
import Quickshell
import Quickshell.Io
import "root:/plugins/kit"

Scope {
    id: root
    property var theme: null
    property bool ready: false

    KitRun { id: check; seconds: 3; onDone: (code) => root.ready = code === 0 }
    function capture() {
        if (!root.ready) {
            KitHost.notify("Screen text needs tesseract", "Install it with: sudo pacman -S tesseract tesseract-data-eng")
            check.start(["sh", "-c", "command -v tesseract"])
            return
        }
        reader.start(["sh", "-c", 'g=$(slurp 2>/dev/null) || exit 3; grim -g "$g" -t png - | tesseract - - 2>/dev/null'])
    }
    KitRun {
        id: reader
        seconds: 60
        onDone: (code, out) => {
            if (code === 3) return
            const t = String(out).replace(/\f/g, "").trim()
            if (code !== 0 || t === "") { KitHost.notify("Screen text", "No text found there."); return }
            KitHost.copy(t)
            KitHost.notify("Text copied", t.length > 120 ? t.slice(0, 117) + "…" : t)
        }
    }
    IpcHandler {
        target: "screenText"
        function capture(): void { root.capture() }
    }
    Component.onCompleted: { check.start(["sh", "-c", "command -v tesseract"]); KitHost.register("screenText", root) }
    Component.onDestruction: KitHost.unregister("screenText", root)
}
