// System monitor (Super + Shift + Esc): how busy the computer is right now: the
// processor, memory, disk and temperature, and what uses the most. Read every two
// seconds while it is open, and not at all when it is closed.
import QtQuick
import Quickshell
import Quickshell.Io
import "root:/plugins/kit"

Scope {
    id: root
    property var theme: null
    property var stats: []
    property var procs: []
    property var lastCpu: null

    function poll() {
        reader.start(["sh", "-c",
            'head -1 /proc/stat; grep -E "^(MemTotal|MemAvailable|SwapTotal|SwapFree):" /proc/meminfo; ' +
            'df -P / | tail -1; cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -n | tail -1; cut -d. -f1 /proc/uptime; ' +
            'echo ---; ps -eo pid=,comm=,%cpu=,%mem= --sort=-%cpu | head -8'])
    }
    function human(kb) { return kb > 1048576 ? (kb / 1048576).toFixed(1) + " GB" : Math.round(kb / 1024) + " MB" }
    KitRun {
        id: reader
        seconds: 5
        onDone: (code, out) => {
            const parts = String(out).split("---\n")
            const lines = parts[0].split("\n")
            const cpu = lines[0].split(/\s+/).slice(1).map(Number)
            const idle = cpu[3] + (cpu[4] || 0), total = cpu.reduce((a, b) => a + b, 0)
            let cpuPct = 0
            if (root.lastCpu) cpuPct = Math.max(0, Math.min(100, Math.round(100 * (1 - (idle - root.lastCpu.idle) / Math.max(1, total - root.lastCpu.total)))))
            root.lastCpu = { idle: idle, total: total }
            const kv = {}
            for (const l of lines.slice(1, 5)) { const m = l.match(/^(\w+):\s+(\d+)/); if (m) kv[m[1]] = Number(m[2]) }
            const df = (lines[5] || "").split(/\s+/)
            const temp = Number(lines[6]) / 1000
            const up = Number(lines[7])
            const used = kv.MemTotal - kv.MemAvailable
            root.stats = [
                { icon: "\u{F0EE0}", title: "Processor", sub: cpuPct + "% busy", hint: "▮".repeat(Math.round(cpuPct / 10)) + "▯".repeat(10 - Math.round(cpuPct / 10)) },
                { icon: "\u{F035B}", title: "Memory", sub: root.human(used) + " of " + root.human(kv.MemTotal) + " in use", hint: Math.round(100 * used / kv.MemTotal) + "%" },
                { icon: "\u{F02CA}", title: "Disk", sub: (df[4] || "?") + " full, " + root.human(Number(df[3] || 0)) + " free", hint: "/" },
                { icon: "\u{F050F}", title: "Temperature", sub: isFinite(temp) && temp > 0 ? temp.toFixed(0) + " °C" : "No sensor", hint: "" },
                { icon: "\u{F0954}", title: "Up for", sub: Math.floor(up / 3600) + " h " + Math.floor((up % 3600) / 60) + " min", hint: "" }
            ]
            root.procs = String(parts[1] || "").split("\n").filter(l => l.trim() !== "").map(l => {
                const f = l.trim().split(/\s+/)
                return { icon: "\u{F0E8D}", title: f[1], sub: "CPU " + f[2] + "%   memory " + f[3] + "%", hint: "pid " + f[0] }
            })
        }
    }
    Timer { interval: 2000; repeat: true; running: panel.open; triggeredOnStart: true; onTriggered: root.poll() }

    KitPanel {
        id: panel
        theme: root.theme
        name: "system_monitor"
        icon: "\u{F0EE0}"
        title: "System"
        input: false
        panelWidth: 640
        panelHeight: 600
        items: root.stats.concat([{ icon: "\u{F05B0}", title: "Using the most", sub: "Right now, by processor" }]).concat(root.procs)
            .concat([{ icon: "\u{F018D}", title: "Open btop in a terminal", sub: "Every process, with more detail", action: "btop" }])
        hints: [["↑ ↓", "move"], ["Enter", "open btop on its row"], ["Esc", "close"]]
        onActivated: (item) => {
            if (item && item.action === "btop") { Quickshell.execDetached(["kitty", "-e", "btop"]); panel.open = false }
        }
    }
    IpcHandler {
        target: "sysmon"
        function toggle(): void { panel.toggle() }
    }
    Component.onCompleted: KitHost.register("sysmon", root)
    Component.onDestruction: KitHost.unregister("sysmon", root)
}
