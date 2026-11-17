// Weather: the weather where you are, on the bar's weather widget, and the next days
// in its panel (a click on the widget). From wttr.in, every half hour, for the place
// you set on the Everyday tools page, or where your connection says you are.
import QtQuick
import Quickshell
import Quickshell.Io
import "root:/plugins/kit"

Scope {
    id: root
    property var theme: null
    KitStore { id: store; pluginId: "weather"; defaults: ({ place: "", units: "c" }) }
    readonly property var settingsStore: store      // for the Everyday tools page
    property var now: null              // { temp, feels, text, icon, place }
    property var days: []
    property string error: ""

    readonly property var icons: ({ sun: "\u{F0599}", cloud: "\u{F0590}", partly: "\u{F0595}", rain: "\u{F0597}", snow: "\u{F0598}", storm: "\u{F0593}", fog: "\u{F0591}" })
    function kind(code) {
        const c = Number(code)
        if (c === 113) return "sun"
        if (c === 116) return "partly"
        if (c === 119 || c === 122) return "cloud"
        if ([143, 248, 260].indexOf(c) >= 0) return "fog"
        if ([200, 386, 389, 392, 395].indexOf(c) >= 0) return "storm"
        if ([179, 227, 230, 323, 326, 329, 332, 335, 338, 368, 371, 374, 377].indexOf(c) >= 0) return "snow"
        return "rain"
    }
    function fetch() {
        const place = String(store.get("place") || "").trim().replace(/\s+/g, "+")
        if (!/^[A-Za-z0-9+,.\-~@]*$/.test(place)) { root.error = "That place has characters it can't look up"; return }
        getter.start(["curl", "-sf", "--max-time", "15", "https://wttr.in/" + place + "?format=j1"])
    }
    KitRun {
        id: getter
        seconds: 20
        maxOut: 300000
        onDone: (code, out) => {
            let j = null
            try { j = JSON.parse(out) } catch (e) { j = null }
            if (code !== 0 || !j || !j.current_condition) { root.error = "Weather could not be fetched"; return }
            const f = store.get("units") === "f"
            const c = j.current_condition[0]
            const area = j.nearest_area && j.nearest_area[0] ? j.nearest_area[0].areaName[0].value : ""
            root.error = ""
            root.now = { temp: (f ? c.temp_F : c.temp_C) + "°", feels: (f ? c.FeelsLikeF : c.FeelsLikeC) + "°",
                         text: c.weatherDesc[0].value, icon: root.icons[root.kind(c.weatherCode)], place: area }
            root.days = (j.weather || []).map(d => ({
                date: d.date, max: (f ? d.maxtempF : d.maxtempC) + "°", min: (f ? d.mintempF : d.mintempC) + "°",
                icon: root.icons[root.kind(d.hourly && d.hourly[4] ? d.hourly[4].weatherCode : 113)],
                text: d.hourly && d.hourly[4] ? d.hourly[4].weatherDesc[0].value : ""
            }))
        }
    }
    Timer { interval: 30 * 60000; repeat: true; running: true; triggeredOnStart: true; onTriggered: root.fetch() }
    Connections { target: store; function onValuesChanged() { if (store.loaded) refetch.restart() } }
    Timer { id: refetch; interval: 800; onTriggered: root.fetch() }

    KitPanel {
        id: panel
        theme: root.theme
        name: "weather"
        icon: root.now ? root.now.icon : "\u{F0599}"
        title: root.now ? root.now.place || "Weather" : "Weather"
        input: false
        panelHeight: 380
        status: root.error
        items: (root.now ? [{ icon: root.now.icon, title: root.now.temp + "  " + root.now.text, sub: "Feels like " + root.now.feels }] : [])
            .concat(root.days.map(d => ({ icon: d.icon, title: Qt.formatDate(new Date(d.date + "T12:00:00"), "dddd"), sub: d.text, hint: d.min + " – " + d.max })))
            .concat([{ icon: "\u{F0493}", title: "Change the place or units", sub: "Everyday tools in the control center", act: "settings" }])
        hints: [["Enter", "on its row: settings"], ["Esc", "close"]]
        onActivated: (item) => { if (item && item.act === "settings") { panel.open = false; KitHost.openSettings() } }
    }
    // its panel, opened or closed (the bar widget's click)
    function toggle() { panel.toggle() }
    IpcHandler {
        target: "weather"
        function toggle(): void { panel.toggle() }
        function refresh(): void { root.fetch() }
        function now(): string { return root.now ? root.now.temp + " " + root.now.text : root.error }
    }
    Component.onCompleted: KitHost.register("weather", root)
    Component.onDestruction: KitHost.unregister("weather", root)
}
