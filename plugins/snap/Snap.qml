// Snap flyout for floating workspaces.
//
// Super+G opens a compact grid of snap arrangements. Clicking a layout places
// the active window in the highlighted zone and the other floating windows of
// the workspace in the remaining ones.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

Scope {
    id: root
    property var theme: null
    readonly property string font: "JetBrainsMono Nerd Font"

    property bool open: false
    property real anchorX: 0
    property real anchorY: 0
    property int targetMonitor: 0
    property double openedAt: 0
    property var layoutStatus: ({})
    readonly property int zoneGap: 12
    // hyprbars draws the titlebar above the geometry hyprctl reports for the
    // window, so it has to be reserved inside each zone, not added on top.
    property int titleHeight: 0
    readonly property bool decorationsEnabled:
        Quickshell.env("AEQUALYN_NO_FLOAT_DECORATIONS") !== "1"

    property real cursorX: -1
    property real cursorY: -1
    // Hyprland 0.57 no longer puts a focused flag in `clients`, and Quickshell's
    // activeToplevel can be null in Lua mode, so poll the active window too.
    property string focusedAddress: ""
    property var clients: []
    property var monitors: []
    property var active: null
    // remember the last snap so the windows can follow a bar that changes edge
    property var lastSnap: null
    // previous per-monitor geometry/reservation, to map free floaters across a bar move
    property var monitorState: ({})
    property string reservedKey: ""
    property double lastLayoutPoll: 0

    // pointer position captured when the picker opens; it preselects the zone
    // inside the layout, which can then be changed before applying.
    property real pickX: -1
    property real pickY: -1
    property var selectedPreset: null
    property int chosenZone: 0

    // Normalized zones; the first one is where the focused window goes.
    // Each entry is a distinct partition, and the later ones cover sessions
    // with many windows instead of repeating the same halves/quarters/thirds
    // with the zone order shuffled.
    readonly property var presets: [
        { name: "Halves",        icon: "󰉝", zones: [[0, 0, .5, 1], [.5, 0, .5, 1]] },
        { name: "Stack",         icon: "󰉟", zones: [[0, 0, 1, .5], [0, .5, 1, .5]] },
        { name: "Thirds",        icon: "󰉥", zones: [[0, 0, .3333, 1], [.3333, 0, .3334, 1], [.6667, 0, .3333, 1]] },
        { name: "Rows",          icon: "󰉧", zones: [[0, 0, 1, .3333], [0, .3333, 1, .3334], [0, .6667, 1, .3333]] },
        { name: "Quarters",      icon: "󰉡", zones: [[0, 0, .5, .5], [.5, 0, .5, .5], [0, .5, .5, .5], [.5, .5, .5, .5]] },
        { name: "Columns",       icon: "󰉫", zones: [[0, 0, .25, 1], [.25, 0, .25, 1], [.5, 0, .25, 1], [.75, 0, .25, 1]] },
        { name: "Rails",         icon: "󰉭", zones: [[0, 0, 1, .25], [0, .25, 1, .25], [0, .5, 1, .25], [0, .75, 1, .25]] },
        { name: "Focus left",    icon: "󰉮", zones: [[0, 0, .66, 1], [.66, 0, .34, .5], [.66, .5, .34, .5]] },
        { name: "Focus right",   icon: "󰉯", zones: [[.34, 0, .66, 1], [0, 0, .34, .5], [0, .5, .34, .5]] },
        { name: "Focus top",     icon: "󰉰", zones: [[0, 0, 1, .6], [0, .6, .3333, .4], [.3333, .6, .3334, .4], [.6667, .6, .3333, .4]] },
        { name: "Focus bottom",  icon: "󰉱", zones: [[0, .4, 1, .6], [0, 0, .3333, .4], [.3333, 0, .3334, .4], [.6667, 0, .3333, .4]] },
        { name: "Center stage",  icon: "󰉨", zones: [[.2, .15, .6, .7], [0, 0, .2, 1], [.8, 0, .2, 1]] },
        { name: "Gallery",       icon: "󰉲", zones: [[0, 0, .3333, .5], [.3333, 0, .3334, .5], [.6667, 0, .3333, .5], [0, .5, .3333, .5], [.3333, .5, .3334, .5], [.6667, .5, .3333, .5]] },
        { name: "Master stack",  icon: "󰉳", zones: [[0, 0, .6, 1], [.6, 0, .4, .3333], [.6, .3333, .4, .3334], [.6, .6667, .4, .3333]] },
        { name: "Sidebar grid",  icon: "󰉴", zones: [[0, 0, .25, 1], [.25, 0, .375, .5], [.625, 0, .375, .5], [.25, .5, .375, .5], [.625, .5, .375, .5]] },
        { name: "Top strip",     icon: "󰉵", zones: [[0, 0, 1, .25], [0, .25, .5, .375], [.5, .25, .5, .375], [0, .625, .5, .375], [.5, .625, .5, .375]] },
        { name: "Bento",         icon: "󰉶", zones: [[0, 0, .4, .66], [0, .66, .4, .34], [.4, 0, .3, .5], [.4, .5, .3, .5], [.7, 0, .3, .5], [.7, .5, .3, .5]] },
        { name: "Crosshair",     icon: "󰉷", zones: [[.3, .25, .4, .5], [0, 0, 1, .25], [0, .75, 1, .25], [0, .25, .3, .5], [.7, .25, .3, .5]] },
        { name: "Filmstrip",     icon: "󰉸", zones: [[0, 0, 1, .55], [0, .55, .25, .45], [.25, .55, .25, .45], [.5, .55, .25, .45], [.75, .55, .25, .45]] },
        { name: "Mosaic",        icon: "󰉹", zones: [[0, 0, .5, .6], [0, .6, .5, .4], [.5, 0, .25, 1], [.75, 0, .25, .5], [.75, .5, .25, .5]] }
    ]

    function norm(a) { return String(a || "").replace(/^0x/, "").toLowerCase() }

    // Repeater hands the click handler a copy of the preset object, so identity
    // comparisons like indexOf() fail. The name is the stable key.
    function presetIndexOf(p) {
        if (!p) return -1
        const name = String(p.name || "")
        for (let i = 0; i < root.presets.length; i++)
            if (root.presets[i].name === name) return i
        return -1
    }

    // hyprctl reports window geometry as `at: [x, y]` and `size: [w, h]`.
    function geom(c) {
        const at = Array.isArray(c.at) ? c.at : [0, 0]
        const size = Array.isArray(c.size) ? c.size : [0, 0]
        return { x: Number(at[0]) || 0, y: Number(at[1]) || 0,
                 w: Number(size[0]) || 0, h: Number(size[1]) || 0 }
    }

    function refresh() {
        if (!clientsProc.running) clientsProc.running = true
        if (!monitorsProc.running) monitorsProc.running = true
    }
    function refreshLayout() { layoutProc.running = true }

    function activeIndex() {
        let addr = norm(root.focusedAddress)
        if (!addr) {
            try { addr = norm(Hyprland.activeToplevel && Hyprland.activeToplevel.address) } catch (e) {}
        }
        if (!addr) {
            const focused = root.clients.find(c => c.focused === true)
            addr = focused ? norm(focused.address) : ""
        }
        if (!addr) return -1
        return root.clients.findIndex(c => norm(c.address) === addr)
    }

    function wsId(c) {
        const w = c.workspace
        return String(w && typeof w === "object" ? w.id : (w || ""))
    }

    // the floating windows of the focused window's workspace, in stack order
    function floaters() {
        const wanted = norm(root.active && root.active.address)
        let i = wanted ? root.clients.findIndex(c => norm(c.address) === wanted) : -1
        if (i < 0) i = activeIndex()
        if (i < 0 || !root.clients[i]) return []
        const focused = root.clients[i]
        const ws = root.wsId(focused)
        const addr = norm(focused.address)
        const others = root.clients.filter(c => c.floating === true && root.wsId(c) === ws
                                                 && c.mapped !== false && norm(c.address) !== addr)
        return [focused].concat(others)
    }

    function layoutOfFocused() {
        const ws = Hyprland.focusedWorkspace ? String(Hyprland.focusedWorkspace.id)
                                              : String(root.layoutStatus.focused || "")
        const map = root.layoutStatus.workspaces || {}
        return (ws && map[ws]) || root.layoutStatus.default || ""
    }
    function onFloatingWorkspace() { return root.layoutOfFocused() === "floating" }

    function monitorIndex(id) {
        const wanted = Number(id)
        for (let i = 0; i < root.monitors.length; i++)
            if (Number(root.monitors[i].id) === wanted) return i
        return 0
    }

    // Which monitor the cursor is actually on; the active window can be on a
    // different one when the pointer sits over a top bar or dock.
    function monitorAtCursor() {
        const px = root.cursorX, py = root.cursorY
        if (px < 0 || py < 0) return -1
        for (let i = 0; i < root.monitors.length; i++) {
            const mon = root.monitors[i]
            const scale = Number(mon.scale) > 0 ? Number(mon.scale) : 1
            const x = Number(mon.x) || 0, y = Number(mon.y) || 0
            const w = Number(mon.width) / scale, h = Number(mon.height) / scale
            if (px >= x && px <= x + w && py >= y - 12 && py <= y + h) return i
        }
        return -1
    }

    function clamp(v, lo, hi) { return Math.max(lo, Math.min(Math.max(lo, hi), v)) }
    function sameRect(a, b) {
        return !!a && !!b && Math.abs(a.x - b.x) < 1 && Math.abs(a.y - b.y) < 1
            && Math.abs(a.w - b.w) < 1 && Math.abs(a.h - b.h) < 1
    }

    // Which monitor a floating window is actually on. Its workspace can differ
    // from the picker's, so snap and reflow must not assume targetMonitor.
    function clientMonitor(c) {
        const g = root.geom(c)
        const cx = g.x + g.w / 2, cy = g.y + g.h / 2
        let best = -1, bestD = Infinity
        for (let i = 0; i < root.monitors.length; i++) {
            const f = root.fullGeometry(root.monitors[i], i)
            if (cx >= f.x && cx <= f.x + f.w && cy >= f.y && cy <= f.y + f.h) return i
            const dx = cx - (f.x + f.w / 2), dy = cy - (f.y + f.h / 2)
            const d = dx * dx + dy * dy
            if (d < bestD) { bestD = d; best = i }
        }
        return best
    }

    // hyprctl reports the client area; hyprbars draws its titlebar above it.
    function visualGeometry(c) {
        const g = root.geom(c)
        return { x: g.x, y: g.y - root.titleHeight, w: g.w, h: g.h + root.titleHeight }
    }

    // Physical monitor data -> the logical coordinates windows and pointers use.
    function fullGeometry(mon, idx) {
        if (mon && Number(mon.width) > 0 && Number(mon.height) > 0) {
            // hyprctl reports physical pixels; window and cursor coordinates,
            // and the layer surfaces, use logical pixels (physical / scale).
            const scale = Number(mon.scale) > 0 ? Number(mon.scale) : 1
            return { x: Number(mon.x) || 0, y: Number(mon.y) || 0,
                     w: Number(mon.width) / scale, h: Number(mon.height) / scale }
        }
        const at = idx === undefined ? root.targetMonitor : idx
        const screen = Quickshell.screens[at]
        if (screen && Number(screen.width) > 0)
            return { x: Number(screen.x) || 0, y: Number(screen.y) || 0,
                     w: Number(screen.width), h: Number(screen.height) }
        return { x: 0, y: 0, w: 1920, h: 1080 }
    }

    // Global geometry of the screen the flyout is on, from live monitor data.
    function targetGeometry() {
        return root.fullGeometry(root.monitors[root.targetMonitor], root.targetMonitor)
    }

    // Usable area for one monitor, in the same global logical coordinates as
    // windows. `reserved` is [left, top, right, bottom] from the live monitor,
    // so a bar on any side is handled without hard-coding its position.
    function usableGeometry(mon, idx) {
        const full = root.fullGeometry(mon, idx)
        const res = mon && Array.isArray(mon.reserved) ? mon.reserved : [0, 0, 0, 0]
        const l = Math.max(0, Number(res[0]) || 0)
        // Fall back to a small top margin when no exclusive zone is reported,
        // so snapped windows (and their titlebars) never slide under an
        // overlay bar.
        const t = Math.max(Math.max(0, Number(res[1]) || 0), (Number(res[1]) || 0) === 0 ? 20 : 0)
        const r = Math.max(0, Number(res[2]) || 0)
        const b = Math.max(0, Number(res[3]) || 0)
        const gap = root.zoneGap
        return {
            x: full.x + l + gap,
            y: full.y + t + gap,
            w: Math.max(100, full.w - l - r - gap * 2),
            h: Math.max(100, full.h - t - b - gap * 2)
        }
    }
    function zoneGeometryFor(idx) {
        return root.usableGeometry(root.monitors[idx], idx)
    }
    function zoneGeometry() {
        const g = root.zoneGeometryFor(root.targetMonitor)
        return g
    }

    // zones rotated so the chosen zone is first (where the focused window lands)
    function zonesFor(preset, chosen) {
        const z = preset.zones
        const k = Math.max(0, Math.min(chosen || 0, z.length - 1))
        return z.slice(k).concat(z.slice(0, k))
    }

    // The zone under the pointer when the picker opened. Each arrangement has
    // its own zone rectangles, so this is resolved at click time.
    function zoneAt(preset, px, py) {
        if (!preset) return 0
        const g = root.zoneGeometry()
        for (let i = 0; i < preset.zones.length; i++) {
            const z = preset.zones[i]
            if (px >= g.x + z[0] * g.w && px <= g.x + (z[0] + z[2]) * g.w
                && py >= g.y + z[1] * g.h && py <= g.y + (z[1] + z[3]) * g.h) return i
        }
        return 0
    }

    function place(win, x, y, w, h) {
        // Resizing a floating window keeps its centre, so resize first and move
        // afterwards. Both go in one eval so their order cannot race.
        const cmd = 'hl.dispatch(hl.dsp.window.resize({ x = ' + w + ', y = ' + h +
                    ', window = "' + win + '" })); ' +
                    'hl.dispatch(hl.dsp.window.move({ x = ' + x + ', y = ' + y +
                    ', window = "' + win + '" }))'
        Quickshell.execDetached(["hyprctl", "eval", cmd])
    }

    // Shared by a fresh snap and by re-snapping after the usable area changes.
    function placeZones(preset, chosen, list, monIdx) {
        const g = root.zoneGeometryFor(monIdx === undefined ? root.targetMonitor : monIdx)
        const zones = zonesFor(preset, chosen)
        for (let i = 0; i < zones.length && i < list.length; i++) {
            const z = zones[i]
            const zx = g.x + z[0] * g.w
            const zy = g.y + z[1] * g.h
            // The titlebar sits above the window geometry hyprctl reports, so
            // reserve its height inside the rectangle the preview drew.
            const px = Math.round(zx)
            const py = Math.round(zy + root.titleHeight)
            const pw = Math.round(Math.max(100, z[2] * g.w - root.zoneGap))
            const ph = Math.round(Math.max(100, z[3] * g.h - root.zoneGap - root.titleHeight))
            const win = "address:" + String(list[i].address || "")
            // hyprctl's legacy `dispatch` command is not usable with a Lua
            // config; go through the Lua dispatcher directly.
            root.place(win, px, py, pw, ph)
        }
    }

    function apply(preset, chosen) {
        if (!preset || !root.active) {
            root.open = false
            return
        }
        const presetIndex = root.presetIndexOf(preset)
        if (presetIndex < 0) return
        const chosenPreset = root.presets[presetIndex]
        const list = floaters()
        const idx = root.clientMonitor(root.active)
        const monIdx = idx >= 0 ? idx : root.targetMonitor
        // Only the windows that got a zone are snapped. Any extra floaters stay
        // free, so a later bar move can still slide them out of the new strip.
        const placed = list.slice(0, chosenPreset.zones.length)
        placeZones(chosenPreset, chosen, placed, monIdx)
        root.lastSnap = {
            preset: presetIndex,
            chosen: chosen,
            addresses: placed.map(c => String(c.address || "")),
            monitor: monIdx
        }
        root.selectedPreset = null
        root.open = false
    }

    // When the bar moves to another edge, Hyprland changes the monitor's
    // reserved sides. Re-run the last snap so the windows follow the new area.
    function reapplySnap() {
        const s = root.lastSnap
        if (!s || !(s.preset >= 0) || !s.addresses || !s.addresses.length) return
        const preset = root.presets[s.preset]
        if (!preset) return
        const list = []
        for (const a of s.addresses) {
            const c = root.clients.find(x => norm(x.address) === norm(a) &&
                                              x.floating === true && x.mapped !== false)
            if (c) list.push(c)
        }
        const monIdx = Number.isInteger(s.monitor) ? s.monitor : root.targetMonitor
        if (list.length) placeZones(preset, s.chosen, list, monIdx)
    }

    // Windows that were never snapped still have to stay clear of a bar that
    // moves to a new edge. Map their visible rectangle from the old usable area
    // to the new one, keeping the titlebar out of the reserved strip as well.
    function reflowFloating(previous, changed) {
        if (!previous || !changed || changed.length === 0) return
        const s = root.lastSnap
        const validSnap = s && s.preset >= 0 && root.presets[s.preset] && s.addresses
        const snapped = validSnap ? s.addresses.map(a => root.norm(a)) : []
        for (const c of root.clients) {
            if (!c || c.floating !== true || c.mapped === false) continue
            const addr = root.norm(c.address)
            if (snapped.indexOf(addr) >= 0) continue
            const idx = root.clientMonitor(c)
            if (idx < 0 || !root.monitors[idx]) continue
            const id = String(root.monitors[idx].id)
            if (changed.indexOf(id) < 0) continue
            const before = previous[id], after = root.monitorState[id]
            if (!before || !after || !before.usable || !after.usable) continue
            const oldU = before.usable, newU = after.usable
            const v = root.visualGeometry(c)
            const rw = v.w / Math.max(1, oldU.w)
            const rh = v.h / Math.max(1, oldU.h)
            const rx = (v.x - oldU.x) / Math.max(1, oldU.w)
            const ry = (v.y - oldU.y) / Math.max(1, oldU.h)
            const maxW = Math.max(100, newU.w)
            const maxH = Math.max(100 + root.titleHeight, newU.h)
            const w = Math.round(root.clamp(rw * newU.w, 100, maxW))
            const hVis = Math.round(root.clamp(rh * newU.h, 100 + root.titleHeight, maxH))
            const x = Math.round(root.clamp(newU.x + rx * newU.w, newU.x,
                                            newU.x + maxW - w))
            const yVis = Math.round(root.clamp(newU.y + ry * newU.h, newU.y,
                                               newU.y + maxH - hVis))
            if (Math.abs(v.x - x) < 1 && Math.abs(v.y - yVis) < 1
                && Math.abs(v.w - w) < 1 && Math.abs(v.h - hVis) < 1) continue
            root.place("address:" + String(c.address || ""), x, yVis + root.titleHeight, w,
                       Math.max(100, hVis - root.titleHeight))
        }
    }

    function showAt(x, y, monitor) {
        root.targetMonitor = Math.max(0, Math.min(monitor || 0, root.monitors.length - 1))
        root.anchorX = x
        root.anchorY = y
        root.selectedPreset = null
        root.chosenZone = 0
        root.pickX = x
        root.pickY = y
        root.openedAt = Date.now()
        root.open = true
        refresh()
    }

    function show() {
        refresh()
        refreshLayout()
        root.active = root.clients[activeIndex()] || null
        const i = activeIndex()
        if (i >= 0 && root.active) {
            const mon = monitorIndex(root.active.monitor)
            const geom = root.monitors[mon] || { x: 0, y: 0, width: 1920 }
            showAt(root.cursorX >= 0 ? root.cursorX : Number(geom.x) + Number(geom.width) / 2,
                   root.cursorY >= 0 ? root.cursorY : Number(geom.y) + 40, mon)
        } else {
            const mon = root.monitors[0] || { x: 0, y: 0, width: 1920 }
            showAt(Number(mon.x) + Number(mon.width) / 2, Number(mon.y) + 40, 0)
        }
    }
    function hide() {
        root.selectedPreset = null
        root.open = false
    }

    // ---- pointer -----------------------------------------------------------
    function ask() {
        // exec() restarts the command every tick; a plain running=true can
        // leave a finished Process latched and the cursor stuck at -1.
        cursorProc.exec(cursorProc.command)
    }

    Timer {
        interval: 90
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            root.ask()
            // Layout changes made outside the shell must reach the picker.
            if (Date.now() - root.lastLayoutPoll > 2000) {
                root.lastLayoutPoll = Date.now()
                root.refreshLayout()
            }
            root.refresh()
            root.active = root.clients[activeIndex()] || null
            if (root.open) {
                const g = root.targetGeometry()
                const mx = g.x, my = g.y, mw = g.w, mh = g.h
                const cw = Math.min(1400, mw - 32)
                const ch = Math.min(root.selectedPreset ? 208 : 120, mh - 16)
                const left = Math.max(mx + 8, Math.min(root.anchorX - cw / 2, mx + mw - cw - 8))
                const top = Math.max(my + 8, Math.min(root.anchorY + 18, my + mh - ch - 8))
                const away = root.cursorX < left - 40 || root.cursorX > left + cw + 40
                             || root.cursorY < top - 40 || root.cursorY > top + ch + 40

                // The pointer walking away dismisses the picker, so it never
                // lingers after it was opened with the key.
                if (away && root.cursorX >= 0 && Date.now() - root.openedAt > 1200) root.hide()
                else refresh()
            }
        }
    }

    // ---- data --------------------------------------------------------------
    Process {
        id: clientsProc
        command: ["sh", "-c", "hyprctl -j clients 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const v = JSON.parse(text || "[]")
                    if (Array.isArray(v)) root.clients = v
                } catch (e) {}
            }
        }
    }
    Process {
        id: layoutProc
        command: ["aequalyn-layout", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const v = JSON.parse(text || "{}")
                    if (v && typeof v === "object") root.layoutStatus = v
                } catch (e) {}
            }
        }
    }
    Process {
        id: monitorsProc
        command: ["sh", "-c", "hyprctl -j monitors 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const v = JSON.parse(text || "[]")
                    if (!Array.isArray(v)) return
                    const key = JSON.stringify(v.map(m => [m.id, m.x, m.y, m.width,
                                                           m.height, m.scale, m.reserved]))
                    const previous = root.monitorState
                    const current = {}
                    const changed = []
                    for (let i = 0; i < v.length; i++) {
                        const id = String(v[i].id)
                        current[id] = { usable: root.usableGeometry(v[i], i) }
                    }
                    for (const id of Object.keys(current)) {
                        const was = previous[id] && previous[id].usable
                        const now = current[id].usable
                        if (!was || !root.sameRect(was, now)) changed.push(id)
                    }
                    const moved = root.reservedKey !== "" && key !== root.reservedKey
                    root.monitors = v
                    root.monitorState = current
                    root.reservedKey = key
                    if (moved) {
                        // snapped windows get their exact zones back; every other
                        // floater is mapped out from under the new bar position
                        root.reflowFloating(previous, changed)
                        root.reapplySnap()
                    }
                } catch (e) {}
            }
        }
    }
    Process {
        id: cursorProc
        command: ["sh", "-c", "hyprctl -j cursorpos 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const p = JSON.parse(text || "{}")
                    if (Number.isFinite(Number(p.x)) && Number.isFinite(Number(p.y))) {
                        root.cursorX = Number(p.x)
                        root.cursorY = Number(p.y)
                    }
                } catch (e) {}
            }
        }
    }
    Process {
        id: activeProc
        command: ["sh", "-c", "hyprctl activewindow -j 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const v = JSON.parse(text || "{}")
                    root.focusedAddress = norm(v.address)
                } catch (e) {}
            }
        }
    }
    Timer {
        interval: 300
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: activeProc.exec(activeProc.command)
    }
    Process {
        id: decoProc
        command: ["sh", "-c", "hyprctl getoption plugin:hyprbars:bar_height -j 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                let h = 0
                try {
                    const v = JSON.parse(text || "{}")
                    if (root.decorationsEnabled && Number(v.int) > 0) h = Number(v.int) + 2
                } catch (e) {}
                root.titleHeight = h
            }
        }
    }
    Connections {
        target: Hyprland
        ignoreUnknownSignals: true
        function onFocusedWorkspaceChanged() { root.refresh(); root.refreshLayout() }
        function onActiveToplevelChanged() { root.refresh() }
    }
    Component.onCompleted: { decoProc.running = true; root.refresh(); root.refreshLayout() }

    IpcHandler {
        target: "snap"
        function show(): void { root.show() }
        function hide(): void { root.hide() }
        function toggle(): void { root.open ? root.hide() : root.show() }
    }

    readonly property color c_bg: theme ? theme.bgBase : "#17171b"
    readonly property color c_surface: theme ? theme.bgSurface : "#24242b"
    readonly property color c_border: theme ? theme.bgBorder : "#3a3a44"
    readonly property color c_text: theme ? theme.textPrimary : "#f2f2f5"
    readonly property color c_muted: theme ? theme.textSecondary : "#b8b8c0"
    readonly property color c_accent: theme ? theme.accentPrimary : "#7aa2f7"

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: win
            required property var modelData
            readonly property int index: {
                for (let i = 0; i < Quickshell.screens.length; i++)
                    if (Quickshell.screens[i] === modelData) return i
                return -1
            }
            screen: modelData
            visible: root.open && index === root.targetMonitor
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "aequalyn_snap"
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true; right: true }

            // Clicking anywhere outside the card cancels the picker.
            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: root.hide()
            }

            Rectangle {
                id: card
                width: Math.min(1400, win.width - 32)
                height: Math.min(root.selectedPreset ? 208 : 120, win.height - 16)
                x: Math.max(8, Math.min(root.anchorX - (modelData.x || 0) - width / 2, win.width - width - 8))
                y: Math.max(8, Math.min(root.anchorY - (modelData.y || 0) + 18, win.height - height - 8))
                radius: 14
                color: root.c_bg
                border.width: 1
                border.color: root.c_border

                // Clicks on the card's own background must not fall through to
                // the outside catcher and dismiss the picker.
                MouseArea {
                    anchors.fill: parent
                    z: -1
                    onClicked: {}
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Item {
                        width: parent.width
                        height: 16

                        Text {
                            anchors.left: parent.left
                            text: root.selectedPreset ? root.selectedPreset.name : "Snap layouts"
                            color: root.c_accent
                            font.family: root.font
                            font.pixelSize: 12
                            font.bold: true
                        }

                        Text {
                            anchors.right: parent.right
                            visible: root.selectedPreset !== null
                            text: "‹ Back"
                            color: root.c_muted
                            font.family: root.font
                            font.pixelSize: 10

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    root.selectedPreset = null
                                    root.chosenZone = 0
                                }
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        height: root.selectedPreset === null ? 32 : 0
                        visible: root.selectedPreset === null
                        spacing: 4
                        Repeater {
                            model: root.presets
                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                width: Math.max(16,
                                    (parent.width - (root.presets.length - 1) * 4) / root.presets.length)
                                height: 32
                                radius: 7
                                color: hovered ? root.c_surface : "transparent"
                                border.width: hovered ? 1 : 0
                                border.color: root.c_accent
                                property bool hovered: false

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: parent.hovered = true
                                    onExited: parent.hovered = false
                                    onClicked: {
                                        root.selectedPreset = modelData
                                        root.chosenZone = root.zoneAt(modelData, root.pickX, root.pickY)
                                    }
                                }

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: Math.min(36, parent.width - 8)
                                    height: 20
                                    color: "transparent"
                                    Repeater {
                                        model: modelData.zones
                                        delegate: Rectangle {
                                            required property var modelData
                                            required property int index
                                            x: modelData[0] * parent.width
                                            y: modelData[1] * parent.height
                                            width: modelData[2] * parent.width - 1
                                            height: modelData[3] * parent.height - 1
                                            radius: 1
                                            color: index === 0 ? root.c_accent : Qt.rgba(root.c_muted.r, root.c_muted.g, root.c_muted.b, 0.18)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: root.selectedPreset !== null ? 116 : 0
                        visible: root.selectedPreset !== null
                        radius: 8
                        color: "transparent"
                        border.width: visible ? 1 : 0
                        border.color: root.c_border

                        Repeater {
                            model: root.selectedPreset ? root.selectedPreset.zones : []
                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                x: modelData[0] * parent.width
                                y: modelData[1] * parent.height
                                width: Math.max(2, modelData[2] * parent.width - 4)
                                height: Math.max(2, modelData[3] * parent.height - 4)
                                radius: 6
                                color: index === root.chosenZone
                                    ? Qt.rgba(root.c_accent.r, root.c_accent.g, root.c_accent.b, 0.45)
                                    : Qt.rgba(root.c_surface.r, root.c_surface.g, root.c_surface.b, 0.85)
                                border.width: index === root.chosenZone ? 3 : 1
                                border.color: index === root.chosenZone
                                    ? root.c_accent : root.c_border

                                Text {
                                    anchors.centerIn: parent
                                    text: String(index + 1)
                                    color: root.c_text
                                    font.family: root.font
                                    font.pixelSize: 18
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: root.chosenZone = index
                                    onClicked: root.apply(root.selectedPreset, index)
                                }
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        text: root.selectedPreset ? "Click the area you want." : "Choose a layout, then an area."
                        color: root.c_muted
                        font.family: root.font
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

}
