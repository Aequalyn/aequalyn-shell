// Color picker (Super + Shift + P): click anywhere on the screen and its colour is
// copied as #rrggbb. The last twenty colours stay in its panel, to copy again, as hex
// or rgb(). Picks with grim, slurp and ImageMagick, which Aequalyn ships.
import QtQuick
import Quickshell
import Quickshell.Io
import "root:/plugins/kit"

Scope {
    id: root
    property var theme: null

    KitStore { id: store; pluginId: "colorPicker"; defaults: ({ history: [] }) }
    readonly property var history: Array.isArray(store.get("history")) ? store.get("history") : []

    function rgbOf(hex) {
        const h = String(hex).replace("#", "")
        return "rgb(" + parseInt(h.slice(0, 2), 16) + ", " + parseInt(h.slice(2, 4), 16) + ", " + parseInt(h.slice(4, 6), 16) + ")"
    }
    function pick() {
        panel.open = false
        picker.start(["sh", "-c", 'p=$(slurp -p 2>/dev/null) || exit 3; grim -g "$p" -t png - | magick - -format "%[hex:p{0,0}]" info:-'])
    }
    KitRun {
        id: picker
        seconds: 60
        onDone: (code, out) => {
            const hex = "#" + String(out).trim().slice(0, 6).toLowerCase()
            if (code !== 0 || !/^#[0-9a-f]{6}$/.test(hex)) {
                if (code !== 3) KitHost.notify("Color picker", "Could not read that colour.")
                return
            }
            KitHost.copy(hex)
            store.set("history", [hex].concat(root.history.filter(c => c !== hex)).slice(0, 20))
            KitHost.notify("Colour copied", hex + "   " + root.rgbOf(hex))
        }
    }

    KitPanel {
        id: panel
        theme: root.theme
        name: "color_picker"
        icon: "\u{F0266}"
        input: false
        title: "Colours"
        panelHeight: 440
        items: [{ icon: "\u{F0485}", title: "Pick a colour on the screen", sub: "Click a pixel; it is copied as #rrggbb", action: "pick" }]
            .concat(root.history.map(c => ({ swatch: c, title: c, sub: root.rgbOf(c), hint: "Ctrl + Enter: rgb()", value: c })))
        hints: [["Enter", "copy hex"], ["Ctrl + Enter", "copy rgb()"], ["Esc", "close"]]
        onActivated: (item, index, mods) => {
            if (!item) return
            if (item.action === "pick") { root.pick(); return }
            const text = (mods & Qt.ControlModifier) ? root.rgbOf(item.value) : item.value
            KitHost.copy(text)
            panel.status = "Copied " + text
        }
    }
    IpcHandler {
        target: "colorPicker"
        function pick(): void { root.pick() }
        function toggle(): void { panel.status = ""; panel.toggle() }
    }
    Component.onCompleted: KitHost.register("colorPicker", root)
    Component.onDestruction: KitHost.unregister("colorPicker", root)
}
