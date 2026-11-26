// Night light: warmer colours in the evening, easier on the eyes and on sleep. From
// the hour you set to the one you set (8 pm to 7 am at first), or on and off by hand.
// Drawn by Hyprland's screen shader, so it needs nothing extra.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "root:/plugins/kit"

Scope {
    id: root
    property var theme: null
    KitStore { id: store; pluginId: "nightLight"; defaults: ({ from: 20, to: 7, warmth: 50, mode: "schedule" }) }
    readonly property var settingsStore: store      // for its settings on the Plugins page
    property bool applied: false
    // schedule | on | off
    readonly property string mode: String(store.get("mode"))
    function inWindow() {
        const h = new Date().getHours(), from = Number(store.get("from")), to = Number(store.get("to"))
        return from === to ? false : (from < to ? h >= from && h < to : h >= from || h < to)
    }
    readonly property string shaderPath: store.dir + "/warm.frag"
    function shader(w) {
        const k = Math.max(0, Math.min(100, w)) / 100
        const g = (1 - 0.22 * k).toFixed(3), b = (1 - 0.55 * k).toFixed(3)
        return "#version 300 es\nprecision highp float;\nin vec2 v_texcoord;\nuniform sampler2D tex;\nout vec4 fragColor;\n" +
               "void main() {\n    vec4 c = texture(tex, v_texcoord);\n    fragColor = vec4(c.r, c.g * " + g + ", c.b * " + b + ", c.a);\n}\n"
    }
    FileView { id: shaderFile; path: root.shaderPath; printErrors: false }
    function update() {
        if (!store.loaded) return
        const want = root.mode === "on" || (root.mode === "schedule" && root.inWindow())
        if (want) {
            shaderFile.setText(root.shader(Number(store.get("warmth"))))
            apply.restart()
        } else if (root.applied) {
            Quickshell.execDetached(["hyprctl", "eval", 'hl.config({ decoration = { screen_shader = "" } })'])
            root.applied = false
        }
    }
    Timer {
        id: apply
        interval: 300
        onTriggered: {
            Quickshell.execDetached(["hyprctl", "eval", "hl.config({ decoration = { screen_shader = \"" + root.shaderPath + "\" } })"])
            root.applied = true
        }
    }
    Timer { interval: 60000; repeat: true; running: true; onTriggered: root.update() }
    // a reload of Hyprland's config (a theme change, a key changed) clears the screen
    // shader: put it back at once, so the night light stays on through it
    Connections {
        target: Hyprland
        // the shader file is already written: no need to wait for it
        function onRawEvent(event) { if (event.name === "configreloaded" && root.applied) apply.triggered() }
    }
    Connections { target: store; function onValuesChanged() { root.update() } function onLoadedChanged() { root.update() } }

    IpcHandler {
        target: "nightLight"
        function on(): void { store.set("mode", "on") }
        function off(): void { store.set("mode", "off") }
        function schedule(): void { store.set("mode", "schedule") }
        function toggle(): void { store.set("mode", root.applied ? "off" : "on") }
    }
    Component.onCompleted: KitHost.register("nightLight", root)
    Component.onDestruction: {
        if (root.applied) Quickshell.execDetached(["hyprctl", "eval", 'hl.config({ decoration = { screen_shader = "" } })'])
        KitHost.unregister("nightLight", root)
    }
}
