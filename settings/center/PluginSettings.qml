// The settings of a built-in pack plugin that has some, shown on the Plugins page when
// you open that plugin (Plugins › Weather). `plugin` is its id. Each writes to the
// plugin's own file (KitStore) while it runs; while it is off, they wait.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/settings"
import "root:/plugins/kit"

ColumnLayout {
    id: ps
    property string plugin: ""
    spacing: 14
    Layout.fillWidth: true

    readonly property bool on: AequalynSettings.enabledPlugins.indexOf(plugin) >= 0
    // Sandboxed plugins own their KitStore in the watchdog process; the bridge
    // reads and writes it there, and takes the direct route for in-process ones.
    function val(key, fallback) { return SandboxSettings.value(ps.plugin, key, fallback) }
    function put(key, value) { SandboxSettings.setValue(ps.plugin, key, value) }
    // which of these has settings here
    readonly property bool has: ["weather", "diskWatch", "batteryGuard", "nightLight", "breaks"].indexOf(plugin) >= 0

    Component.onCompleted: SandboxSettings.refresh(ps.plugin)
    onPluginChanged: SandboxSettings.refresh(ps.plugin)
    onOnChanged: if (ps.on) SandboxSettings.refresh(ps.plugin)

    CcNote {
        visible: ps.has && !ps.on
        text: "Turn it on above to change its settings."
    }

    // ---- weather ----------------------------------------------------------------------
    CcSection {
        visible: ps.plugin === "weather" && ps.on
        title: "Where"
        hint: "A town, or empty for where your connection says you are. From wttr.in, every half hour."
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            CcField {
                id: placeField
                Layout.fillWidth: true
                placeholder: "A town, like Bucharest"
                text: String(ps.val("place", ""))
                onAccepted: ps.put("place", placeField.text.trim())
            }
            CcButton { text: "Set"; primary: true; onClicked: ps.put("place", placeField.text.trim()) }
        }
        CcChoice {
            options: [{ key: "c", label: "Celsius" }, { key: "f", label: "Fahrenheit" }]
            current: String(ps.val("units", "c"))
            onChosen: key => ps.put("units", key)
        }
        CcNote { text: "The weather widget shows it on the bar: add it on the Bar page." }
    }

    // ---- disk watch -------------------------------------------------------------------
    CcSection {
        visible: ps.plugin === "diskWatch" && ps.on
        title: "When to say so"
        hint: "Watches /, /home, /boot and /var: one message, until the disk has room again."
        CcSlider {
            title: "Less free than"
            value: Number(ps.val("percent", 10))
            from: 3; to: 30; step: 1
            format: v => Math.round(v) + "%"
            onCommitted: v => ps.put("percent", Math.round(v))
        }
    }

    // ---- battery guard ----------------------------------------------------------------
    CcSection {
        visible: ps.plugin === "batteryGuard" && ps.on
        title: "When to say so"
        hint: "Once each time. Quiet on a computer without a battery."
        CcSlider {
            title: "Low"
            value: Number(ps.val("low", 20))
            from: 10; to: 50; step: 5
            format: v => Math.round(v) + "%"
            onCommitted: v => ps.put("low", Math.round(v))
        }
        CcSlider {
            title: "Nearly empty"
            value: Number(ps.val("critical", 10))
            from: 3; to: 20; step: 1
            format: v => Math.round(v) + "%"
            onCommitted: v => ps.put("critical", Math.round(v))
        }
        CcToggle {
            title: "Say when it is full"
            sub: "While charging, so you can unplug it."
            checked: ps.val("full", true) === true
            onToggled: v => ps.put("full", v)
        }
    }

    // ---- night light ------------------------------------------------------------------
    CcSection {
        visible: ps.plugin === "nightLight" && ps.on
        title: "When"
        hint: "Drawn by Hyprland itself; needs nothing extra."
        CcChoice {
            options: [{ key: "schedule", label: "On a schedule" }, { key: "on", label: "On now" }, { key: "off", label: "Off now" }]
            current: String(ps.val("mode", "schedule"))
            onChosen: key => ps.put("mode", key)
        }
        CcSlider {
            visible: ps.val("mode", "schedule") === "schedule"
            title: "From"
            value: Number(ps.val("from", 20))
            from: 0; to: 23; step: 1
            format: v => Math.round(v) + ":00"
            onCommitted: v => ps.put("from", Math.round(v))
        }
        CcSlider {
            visible: ps.val("mode", "schedule") === "schedule"
            title: "Until"
            value: Number(ps.val("to", 7))
            from: 0; to: 23; step: 1
            format: v => Math.round(v) + ":00"
            onCommitted: v => ps.put("to", Math.round(v))
        }
        CcSlider {
            title: "Warmth"
            value: Number(ps.val("warmth", 50))
            from: 10; to: 100; step: 5
            format: v => Math.round(v) + "%"
            onCommitted: v => ps.put("warmth", Math.round(v))
        }
    }

    // ---- break reminder ---------------------------------------------------------------
    CcSection {
        visible: ps.plugin === "breaks" && ps.on
        title: "How often"
        hint: "Look at something far away for twenty seconds. Quiet while you are away."
        CcSlider {
            title: "Every"
            value: Number(ps.val("minutes", 20))
            from: 10; to: 90; step: 5
            format: v => Math.round(v) + " min"
            onCommitted: v => ps.put("minutes", Math.round(v))
        }
    }
}
