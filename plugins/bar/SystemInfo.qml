pragma Singleton
// System metrics polling singleton for bar widgets.
// Samples CPU, memory, network, battery, and temperature and exposes the results as
// reactive properties.

import Quickshell
import Quickshell.Io
import QtQuick

// Values are plain properties so the bar can bind to them reactively.
Singleton {
  id: root

  property string cpuUsage: "0%"
  property string memoryUsage: "0%"
  property string networkInfo: "Disconnected"
  property string networkType: "disconnected"
  property int batteryLevelRaw: 0
  property string batteryLevel: "0%"
  property string batteryIcon: "󰂎"
  property bool batteryCharging: false
  property string temperature: "0°C"

  // CPU, memory, battery and temperature come straight from the kernel's files: no
  // program is started for them, which is most of what a resting bar used to cost.
  FileView { id: statFile; path: "/proc/stat"; blockLoading: true; printErrors: false }
  FileView { id: memFile; path: "/proc/meminfo"; blockLoading: true; printErrors: false }
  function fresh(file) {
    file.reload()
    file.waitForJob()
    return file.text() || ""
  }
  property var cpuBefore: null            // [busy, all], from the last time
  function readCpu() {
    const t = root.fresh(statFile).split("\n")[0].trim().split(/\s+/).slice(1, 9).map(Number)
    if (t.length < 4 || t.some(v => !isFinite(v))) return
    const all = t.reduce((x, y) => x + y, 0), idle = t[3] + (t[4] || 0), was = root.cpuBefore
    root.cpuBefore = [all - idle, all]
    if (was && all > was[1]) root.cpuUsage = Math.round(1000 * Math.max(0, all - idle - was[0]) / (all - was[1])) / 10 + "%"
  }
  function readMemory() {
    const t = root.fresh(memFile)
    const of = k => { const m = new RegExp("^" + k + ":\\s+(\\d+)", "m").exec(t); return m ? Number(m[1]) : 0 }
    const total = of("MemTotal")
    if (total > 0) root.memoryUsage = ((total - of("MemAvailable")) / total * 100).toFixed(1) + "%"
  }

  // Network Info (ethernet takes priority over wifi). Read from the devices' connection
  // state: the wifi scan list's "active" flag drops out while NetworkManager rescans, which
  // showed "Disconnected" while connected. The name is the connection's (normally the SSID);
  // terse output escapes ":" in it as "\:".
  Process {
    id: netProc
    command: ["sh", "-c", "dev=$(nmcli -t -f TYPE,STATE,CONNECTION dev 2>/dev/null); if printf '%s\\n' \"$dev\" | grep -q '^ethernet:connected'; then echo 'ethernet:Ethernet'; else wifi=$(printf '%s\\n' \"$dev\" | grep '^wifi:connected:' | head -1 | cut -d: -f3- | sed 's/\\\\:/:/g'); if [ -n \"$wifi\" ]; then echo \"wifi:$wifi\"; else echo 'disconnected:'; fi; fi"]
    running: true

    stdout: StdioCollector {
      onStreamFinished: {
        const result = text.trim()
        const colonIdx = result.indexOf(':')
        const type = result.substring(0, colonIdx)
        const info = result.substring(colonIdx + 1)
        root.networkType = type
        root.networkInfo = info || "Disconnected"
      }
    }
  }

  // which batteries and thermal zones there are, asked once
  property var batteries: []
  property var zones: []
  Process {
    running: true
    command: ["sh", "-c", "ls -d /sys/class/power_supply/BAT* /sys/class/thermal/thermal_zone*/temp 2>/dev/null"]
    stdout: StdioCollector {
      onStreamFinished: {
        const all = text.trim().split("\n")
        root.batteries = all.filter(p => p.indexOf("/power_supply/") > 0).slice(0, 1)
        root.zones = all.filter(p => p.indexOf("/thermal/") > 0)
        root.readSlow()
      }
    }
  }
  Instantiator {
    id: zoneFiles
    model: root.zones
    delegate: FileView { required property string modelData; path: modelData; blockLoading: true; printErrors: false }
  }
  FileView { id: levelFile; path: root.batteries.length ? root.batteries[0] + "/capacity" : ""; blockLoading: true; printErrors: false }
  FileView { id: stateFile; path: root.batteries.length ? root.batteries[0] + "/status" : ""; blockLoading: true; printErrors: false }

  function readBattery() {
    const has = root.batteries.length > 0
    const level = has ? parseInt(root.fresh(levelFile)) || 0 : 99
    const status = has ? root.fresh(stateFile).trim() : "Discharging"
    root.batteryLevelRaw = level
    root.batteryLevel = level + "%"
    root.batteryCharging = status === "Charging"
    if (root.batteryCharging) root.batteryIcon = ""
    else if (level >= 90) root.batteryIcon = "󰁹"
    else if (level >= 80) root.batteryIcon = "󰂂"
    else if (level >= 70) root.batteryIcon = "󰂁"
    else if (level >= 60) root.batteryIcon = "󰂀"
    else if (level >= 50) root.batteryIcon = "󰁿"
    else if (level >= 40) root.batteryIcon = "󰁾"
    else if (level >= 30) root.batteryIcon = "󰁽"
    else if (level >= 20) root.batteryIcon = "󰁼"
    else if (level >= 10) root.batteryIcon = "󰁻"
    else root.batteryIcon = "󰁺"
  }

  // the hottest zone; where the kernel has none that say anything, aequalyn-temperature
  // asks `sensors`
  function readTemperature() {
    let max = 0
    for (let i = 0; i < zoneFiles.count; i++) {
      const f = zoneFiles.objectAt(i)
      const t = f ? parseInt(root.fresh(f)) : 0
      if (t > max) max = t
    }
    if (max > 1000) root.temperature = Math.round(max / 1000) + "°C"
    else if (!tempProc.running) tempProc.running = true
  }
  Process {
    id: tempProc
    command: ["aequalyn-temperature"]
    stdout: StdioCollector { onStreamFinished: root.temperature = text.trim() || "N/A" }
  }

  // The network is NetworkManager's to say, which takes a program: asked when the routes
  // change, and now and then.
  FileView { id: routeFile; path: "/proc/net/route"; blockLoading: true; printErrors: false }
  property string routes: ""
  property int round: 0
  function readSlow() {
    root.readBattery()
    root.readTemperature()
  }
  Timer {
    interval: 2000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      root.readCpu()
      root.readMemory()
      const routes = root.fresh(routeFile)
      if (routes !== root.routes || root.round % 8 === 0) {
        root.routes = routes
        if (!netProc.running) netProc.running = true
      }
      if (root.round % 2 === 0) root.readSlow()
      root.round++
    }
  }
}
