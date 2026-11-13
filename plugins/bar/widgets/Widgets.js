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
    media:          "Media.qml",
    volume:         "Volume.qml",
    battery:        "Battery.qml",
    screenshot:     "Screenshot.qml",
    cpu:            "Cpu.qml",
    network:        "Network.qml",
    caffeine:       "Caffeine.qml",
    power:          "Power.qml",
    screenrecorder: "ScreenRecorder.qml",
    atelier:        "AtelierButton.qml",
    tray:           "Tray.qml",
    brightness:     "Brightness.qml",
    bluetooth:      "Bluetooth.qml",
    temperature:    "Temperature.qml",
    settingsbutton: "SettingsButton.qml"
};

// the file for a widget id, or "" for an id the bar doesn't know (a hand-edited settings.json)
function fileFor(id) {
    return Object.prototype.hasOwnProperty.call(files, id) ? files[id] : "";
}
