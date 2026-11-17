// Everyday tools: the settings of the built-in pack's plugins that have any (weather,
// night light, battery guard, break reminder, disk watch, and which AI agent the AI
// plugins ask). Each part has its plugin's switch; while a plugin is off, its part
// waits. The plugins themselves are on the Plugins page, with their keys.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/settings"
import "root:/plugins/kit"
import ".."

CcPage {
    id: page
    title: "Everyday tools"
    sub: "The built-in pack: small tools for every day, each a plugin you turn on when you want it. Their keys are on the Plugins page."
    tabs: ["Around you", "Your health", "AI helpers"]

    function on(id) { return AequalynSettings.enabledPlugins.indexOf(id) >= 0 }
    function store(id) { const s = KitHost.get(id); return s ? s.settingsStore : null }
    function val(id, key, fallback) { const s = page.store(id); return s ? s.get(key) : fallback }
    function put(id, key, value) { const s = page.store(id); if (s) s.set(key, value) }

    // the AI agent all the AI plugins ask
    KitStore { id: aiStore; pluginId: "ai"; defaults: ({ agent: "auto" }) }
    KitAi { id: aiProbe }

    component PluginSwitch: CcToggle {
        property string plugin: ""
        checked: page.on(plugin)
        onToggled: v => AequalynSettings.togglePlugin(plugin, v)
    }

    // ---- around you -----------------------------------------------------------------
    CcSection {
        visible: page.tab === 0
        title: "Weather"
        hint: "On the bar's weather widget, from wttr.in. Add the widget on the Bar page."
        PluginSwitch { plugin: "weather"; title: "Weather"; sub: "The temperature and the sky where you are, and the next days." }
        RowLayout {
            visible: page.on("weather")
            Layout.fillWidth: true
            spacing: 8
            CcField {
                id: placeField
                Layout.fillWidth: true
                placeholder: "A town, like Bucharest (empty: where your connection says you are)"
                text: String(page.val("weather", "place", ""))
                onAccepted: page.put("weather", "place", placeField.text.trim())
            }
            CcButton { text: "Set"; primary: true; onClicked: page.put("weather", "place", placeField.text.trim()) }
        }
        CcChoice {
            visible: page.on("weather")
            options: [{ key: "c", label: "Celsius" }, { key: "f", label: "Fahrenheit" }]
            current: String(page.val("weather", "units", "c"))
            onChosen: key => page.put("weather", "units", key)
        }
    }
    CcSection {
        visible: page.tab === 0
        title: "Disk watch"
        hint: "A message when a disk is nearly full, once, until it has room again."
        PluginSwitch { plugin: "diskWatch"; title: "Disk watch"; sub: "Watches /, /home, /boot and /var." }
        CcSlider {
            visible: page.on("diskWatch")
            title: "Tell me when less is free than"
            value: Number(page.val("diskWatch", "percent", 10))
            from: 3; to: 30; step: 1
            format: v => Math.round(v) + "%"
            onCommitted: v => page.put("diskWatch", "percent", Math.round(v))
        }
    }
    CcSection {
        visible: page.tab === 0
        title: "Battery guard"
        hint: "A message when the battery runs low, again when it is nearly empty, and when it is full while charging."
        PluginSwitch { plugin: "batteryGuard"; title: "Battery guard"; sub: "Quiet on a computer without a battery." }
        CcSlider {
            visible: page.on("batteryGuard")
            title: "Low"
            value: Number(page.val("batteryGuard", "low", 20))
            from: 10; to: 50; step: 5
            format: v => Math.round(v) + "%"
            onCommitted: v => page.put("batteryGuard", "low", Math.round(v))
        }
        CcSlider {
            visible: page.on("batteryGuard")
            title: "Nearly empty"
            value: Number(page.val("batteryGuard", "critical", 10))
            from: 3; to: 20; step: 1
            format: v => Math.round(v) + "%"
            onCommitted: v => page.put("batteryGuard", "critical", Math.round(v))
        }
        CcToggle {
            visible: page.on("batteryGuard")
            title: "Say when it is full"
            sub: "While charging, so you can unplug it."
            checked: page.val("batteryGuard", "full", true) === true
            onToggled: v => page.put("batteryGuard", "full", v)
        }
    }

    // ---- your health ----------------------------------------------------------------
    CcSection {
        visible: page.tab === 1
        title: "Night light"
        hint: "Warmer colours in the evening, easier on the eyes and on sleep."
        PluginSwitch { plugin: "nightLight"; title: "Night light"; sub: "Drawn by Hyprland itself; needs nothing extra." }
        CcChoice {
            visible: page.on("nightLight")
            options: [{ key: "schedule", label: "On a schedule" }, { key: "on", label: "On now" }, { key: "off", label: "Off now" }]
            current: String(page.val("nightLight", "mode", "schedule"))
            onChosen: key => page.put("nightLight", "mode", key)
        }
        CcSlider {
            visible: page.on("nightLight") && page.val("nightLight", "mode", "schedule") === "schedule"
            title: "From"
            value: Number(page.val("nightLight", "from", 20))
            from: 0; to: 23; step: 1
            format: v => Math.round(v) + ":00"
            onCommitted: v => page.put("nightLight", "from", Math.round(v))
        }
        CcSlider {
            visible: page.on("nightLight") && page.val("nightLight", "mode", "schedule") === "schedule"
            title: "Until"
            value: Number(page.val("nightLight", "to", 7))
            from: 0; to: 23; step: 1
            format: v => Math.round(v) + ":00"
            onCommitted: v => page.put("nightLight", "to", Math.round(v))
        }
        CcSlider {
            visible: page.on("nightLight")
            title: "Warmth"
            value: Number(page.val("nightLight", "warmth", 50))
            from: 10; to: 100; step: 5
            format: v => Math.round(v) + "%"
            onCommitted: v => page.put("nightLight", "warmth", Math.round(v))
        }
    }
    CcSection {
        visible: page.tab === 1
        title: "Break reminder"
        hint: "Look at something far away for twenty seconds, every so often. Quiet while you are away."
        PluginSwitch { plugin: "breaks"; title: "Break reminder"; sub: "The 20-20-20 rule against tired eyes." }
        CcSlider {
            visible: page.on("breaks")
            title: "Every"
            value: Number(page.val("breaks", "minutes", 20))
            from: 10; to: 90; step: 5
            format: v => Math.round(v) + " min"
            onCommitted: v => page.put("breaks", "minutes", Math.round(v))
        }
    }
    CcNote {
        visible: page.tab === 1
        text: "Focus (Super + Alt + F) and the Timer's pomodoro (Super + Alt + T) are on the Plugins page."
    }

    // ---- AI helpers -----------------------------------------------------------------
    CcSection {
        visible: page.tab === 2
        title: "Which AI agent answers"
        hint: aiProbe.installed.length === 0
            ? "None is installed yet. Install one on the AI tools page; the AI helpers use it at once."
            : "The AI helpers ask one of the agents installed here, as you, on this computer."
        CcChoice {
            options: [{ key: "auto", label: "The first installed" }].concat(aiProbe.installed.map(a => ({ key: a, label: aiProbe.labels[a] })))
            current: String(aiStore.get("agent"))
            onChosen: key => aiStore.set("agent", key)
        }
        CcButton {
            text: "AI tools"; icon: "\u{F06A9}"
            onClicked: Cc.go("aiTools")
        }
    }
    CcSection {
        visible: page.tab === 2
        title: "The helpers"
        hint: "Each sends only what you give it, when you press Enter: a question, a task, the text you copied, or file names (never what is in them)."
        PluginSwitch { plugin: "aiAsk"; title: "AI ask · Super + Alt + Space"; sub: "A question, answered without a terminal." }
        PluginSwitch { plugin: "aiCommand"; title: "AI command · Super + Alt + E"; sub: "Say what to do; it writes the command. It runs only when you press Ctrl + Enter." }
        PluginSwitch { plugin: "aiClipboard"; title: "AI clipboard · Super + Alt + V"; sub: "Sum up, explain, translate or fix the text you copied." }
        PluginSwitch { plugin: "aiTidy"; title: "AI tidy · Super + Alt + D"; sub: "Sorts Downloads into folders after you approve the plan. Files only move, never get deleted, and Undo puts them back." }
    }
}
