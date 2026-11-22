.pragma library

// The bar's widgets: the id stored in settings.json (appearance.barLeft / barCenter /
// barRight) and the file in this folder that draws it. Each file is a plain QML item
// with `required property var bar`, the bar it sits in (theme, font, shared state and
// actions, see Bar.qml). To add a widget: put its file here, add a line below, and give
// it a label (and optionally a show/hide toggle) in settings/AequalynSettings.qml.
//
// A widget with nothing to show can say so with `readonly property bool wanted: false`;
// the bar then hides its whole slot, shape and spacing included.
var files = {
    appsmenu:       "AppsMenu.qml",
    workspaces:     "Workspaces.qml",
    layouts:        "LayoutsButton.qml",
    title:          "Title.qml",
    clock:          "Clock.qml",
    calendar:       "Calendar.qml",
    media:          "Media.qml",
    volume:         "Volume.qml",
    battery:        "Battery.qml",
    screenshot:     "Screenshot.qml",
    cpu:            "Cpu.qml",
    network:        "Network.qml",
    caffeine:       "Caffeine.qml",
    plume:          "Plume.qml",
    timer:          "TimerWidget.qml",
    focus:          "FocusWidget.qml",
    weather:        "WeatherWidget.qml",
    netspeed:       "NetSpeedWidget.qml",
    altscape:       "AltscapeButton.qml",
    power:          "Power.qml",
    screenrecorder: "ScreenRecorder.qml",
    atelier:        "AtelierButton.qml",
    tray:           "Tray.qml",
    brightness:     "Brightness.qml",
    bluetooth:      "Bluetooth.qml",
    temperature:    "Temperature.qml",
    settingsbutton: "SettingsButton.qml",
    barbutton:      "BarButton.qml",
    clipscape:      "ClipscapeButton.qml"
};

// the file for a widget id, or "" for an id the bar doesn't know (a hand-edited settings.json)
function fileFor(id) {
    return Object.prototype.hasOwnProperty.call(files, id) ? files[id] : "";
}

// The widgets that belong to a plugin (Plugins.js): while it is off, the widget is not
// on the bar at all.
var plugins = {
    media: "media", timer: "timer", focus: "focus", weather: "weather", netspeed: "netSpeed",
    plume: "plume", altscape: "altscape", atelier: "atelier", layouts: "atelier",
    caffeine: "idleInhibitor", appsmenu: "appLauncher", power: "powerMenu", clipscape: "clipscape"
};
function pluginFor(id) { return Object.prototype.hasOwnProperty.call(plugins, id) ? plugins[id] : ""; }
// the widgets of plugin `pid`, first the one put on the bar when it is turned on
function widgetsOf(pid) { return Object.keys(plugins).filter(w => plugins[w] === pid); }

// The widgets with a quick panel (widgets/<Name>Quick.qml), and the click that opens it
// unless you choose another on the Bar page (AequalynSettings.barClicks). The Themes and
// Layouts buttons choose theirs with their other clicks.
var quick = {
    media: "right", timer: "right", focus: "right", weather: "right", netspeed: "left",
    plume: "right", altscape: "right", caffeine: "right", appsmenu: "right", power: "right",
    network: "left", bluetooth: "left", battery: "left", volume: "right", brightness: "left",
    cpu: "left", temperature: "left", calendar: "left", screenshot: "right", screenrecorder: "right",
    clipscape: "right"
};
function quickDefault(id) { return Object.prototype.hasOwnProperty.call(quick, id) ? quick[id] : "none"; }
