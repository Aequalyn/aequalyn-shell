// The visible lock surface: wallpaper/theme background, style-driven layout,
// clock, password field and fingerprint/glance hint. All colours come from the
// shell's injected theme.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Effects

Item {
  id: root

  property var theme: null
  property string wallpaperPath: ""
  property string userName: ""
  property bool use24h: true
  property string lockStyle: "classic"
  property string fieldPosition: "center"
  property bool settingShowUser: true
  property bool settingShowClock: true
  property bool settingShowDate: true
  property bool settingShowMedia: true
  property bool settingShowBattery: false
  property real customClockX: -1
  property real customClockY: -1
  property real customFieldX: -1
  property real customFieldY: -1
  property bool preview: false
  property string customLayout: ""
  property string failureMessage: ""
  property int failedAttempts: 0
  property bool authenticating: false
  property bool glanceScanning: false
  property bool fingerprintConfigured: false
  property bool fingerprintClaimed: false
  property bool sessionSecure: false

  signal submitPassword(string value)
  signal clearFailure()
  signal triggerGlance()

  readonly property color bg: theme && theme.bgBase ? theme.bgBase : "#141414"
  readonly property color surface: theme && theme.bgSurface ? theme.bgSurface : "#1e1e1e"
  readonly property color border: theme && theme.bgBorder ? theme.bgBorder : "#45475a"
  readonly property color fg: theme && theme.textPrimary ? theme.textPrimary : "#e0e0e0"
  readonly property color muted: theme && theme.textMuted ? theme.textMuted : "#8a8a8a"
  readonly property color accent: theme && theme.accentPrimary ? theme.accentPrimary : "#7aa2f7"
  readonly property color accent2: theme && theme.accentSecondary ? theme.accentSecondary : accent
  readonly property color error: theme && theme.accentRed ? theme.accentRed : "#f7768e"
  readonly property string font: "JetBrainsMono Nerd Font"

  readonly property string style: {
    const s = String(root.lockStyle || "classic")
    const known = ["classic","clean","mono","corner","pill","split","stack","dot","frame","glass","line","terminal","neon","poster","orbit","dashboard","zen","vertical","duo","card","nowplaying","binary","words","day","calendar","weather","quote","avatar","battery","custom"]
    return known.indexOf(s) >= 0 ? s : "classic"
  }
  readonly property var defaultCustomItems: [
    { type: "field", x: 0.5, y: 0.72, visible: true }
  ]
  readonly property var customItems: {
    if (root.style !== "custom") return []
    try {
      const o = JSON.parse(root.customLayout || "{}")
      if (Array.isArray(o.elements) && o.elements.length) return o.elements
    } catch (e) {}
    return root.defaultCustomItems
  }

  readonly property bool isSolid: ["mono","dot","line","terminal","battery","binary","neon"].indexOf(style) >= 0
  readonly property bool showWallpaper: wallpaper.status === Image.Ready && !isSolid
  readonly property real blurAmount: {
    if (style === "glass" || style === "zen" || style === "quote" || style === "nowplaying") return 0.75
    if (style === "calendar" || style === "avatar") return 0.7
    if (style === "words" || style === "orbit" || style === "stack") return 0.55
    if (style === "clean" || style === "dashboard") return 0.45
    if (style === "corner" || style === "split" || style === "frame") return 0.0
    if (style === "classic" || style === "pill" || style === "duo" || style === "day" || style === "poster" || style === "weather" || style === "vertical" || style === "card") return 0.35
    return 0.45
  }
  readonly property real dimAmount: {
    if (style === "mono" || style === "dot" || style === "line" || style === "terminal" || style === "battery" || style === "binary" || style === "neon") return 1.0
    if (style === "glass" || style === "calendar" || style === "avatar") return 0.24
    if (style === "quote" || style === "nowplaying" || style === "zen") return 0.32
    if (style === "corner" || style === "frame" || style === "split") return 0.35
    return 0.18
  }
  readonly property string timeFormat: root.use24h ? "HH:mm" : "h:mm AP"
  readonly property string timeText: Qt.formatTime(new Date(), root.timeFormat)
  readonly property string dateText: Qt.formatDate(new Date(), "dddd, d MMMM")
  readonly property string shortDateText: Qt.formatDate(new Date(), "ddd d")
  property string infoText: ""
  property string infoText2: ""
  property string mediaText: ""
  property string batteryText: ""

  function refreshInfo() {
    const has = (t) => root.style === "custom" && root.customItems.some(e => e.type === t && e.visible !== false)
    if (style === "weather" || has("weather")) infoProc.command = [root.homeBin("aequalyn-lock-info"), "weather"]
    else if (style === "words" || has("words")) infoProc.command = [root.homeBin("aequalyn-lock-info"), "words"]
    else if (style === "quote" || has("quote")) infoProc.command = [root.homeBin("aequalyn-lock-info"), "quote"]
    else if (style === "day" || has("day")) infoProc.command = [root.homeBin("aequalyn-lock-info"), "day"]
    else if (style === "battery") infoProc.command = [root.homeBin("aequalyn-lock-info"), "battery"]
    else if (style === "binary" || has("binary")) infoProc.command = [root.homeBin("aequalyn-lock-info"), "binary"]
    else if (style === "dashboard" || has("calendar")) infoProc.command = ["bash", "-c", "cal -m | sed -e 's/&/\\&amp;/g'"]
    else { root.infoText = ""; root.infoText2 = ""; return }
    infoProc.running = false
    infoProc.running = true
  }
  function homeBin(name) { return (Quickshell.env("HOME") || "") + "/.local/bin/" + name }

  onStyleChanged: refreshInfo()
  onCustomLayoutChanged: if (root.style === "custom") refreshInfo()
  Component.onCompleted: { refreshInfo(); if (!root.preview) input.forceActiveFocus() }

  Process {
    id: infoProc
    command: []
    stdout: StdioCollector {
      onStreamFinished: {
        const t = String(text || "").trim()
        if (root.style === "binary") {
          const lines = t.split("\n")
          root.infoText = lines[0] || ""
          root.infoText2 = lines[1] || ""
        } else {
          root.infoText = t
          root.infoText2 = ""
        }
      }
    }
  }

  Process {
    id: mediaProc
    command: ["bash", "-c", "playerctl metadata --format '{{artist}} - {{title}}' 2>/dev/null | head -1"]
    stdout: StdioCollector { onStreamFinished: root.mediaText = String(text || "").trim() }
  }
  Process {
    id: batteryProc
    command: ["bash", "-c", "b=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1); [ -n \"$b\" ] && echo \"󰁹 ${b}%\""]
    stdout: StdioCollector { onStreamFinished: root.batteryText = String(text || "").trim() }
  }
  Timer { interval: 1000; repeat: true; running: true; onTriggered: { clockText.text = Qt.formatTime(new Date(), root.timeFormat); if (root.style === "binary" || (root.style === "custom" && root.customItems.some(e => e.type === "binary" && e.visible !== false))) root.refreshInfo() } }
  Timer { interval: 60000; repeat: true; running: root.style === "custom" || ["weather","words","quote","day","battery","dashboard","calendar","nowplaying"].indexOf(root.style) >= 0; onTriggered: root.refreshInfo() }
  Timer { interval: 10000; repeat: true; running: root.settingShowMedia || (root.style === "custom" && root.customItems.some(e => e.type === "media" && e.visible !== false)); triggeredOnStart: true; onTriggered: { mediaProc.running = false; mediaProc.running = true } }
  Timer { interval: 30000; repeat: true; running: root.settingShowBattery || (root.style === "custom" && root.customItems.some(e => e.type === "battery" && e.visible !== false)); triggeredOnStart: true; onTriggered: { batteryProc.running = false; batteryProc.running = true } }

  Image {
    id: wallpaper
    anchors.fill: parent
    source: root.wallpaperPath ? "file://" + root.wallpaperPath : ""
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    cache: false
    visible: false
    layer.enabled: true
  }

  MultiEffect {
    source: wallpaper
    anchors.fill: parent
    visible: root.showWallpaper
    autoPaddingEnabled: false
    blurEnabled: root.blurAmount > 0.01
    blurMax: 64
    blur: root.blurAmount
    blurMultiplier: 1.0
    brightness: root.style === "glass" || root.style === "zen" || root.style === "quote" ? -0.14 : -0.08
    saturation: 0.0
  }

  Rectangle {
    anchors.fill: parent
    color: root.isSolid ? root.bg : "#000000"
    opacity: root.showWallpaper ? root.dimAmount : 1
  }

  // ---- style helpers -------------------------------------------------------
  readonly property bool styleWantsClock: style !== "dot" && style !== "custom"
  readonly property bool styleWantsDate: style !== "custom" && (["dot","mono","line","terminal","binary","stack","duo","pill","poster","words","quote","day","battery","avatar","card","nowplaying","vertical"].indexOf(style) < 0 || ["classic","clean","corner","frame","glass","orbit","dashboard","zen","split","calendar","weather","neon"].indexOf(style) >= 0)
  readonly property bool styleWantsUser: style !== "custom" && ["classic","avatar","card","split","terminal","dot"].indexOf(style) >= 0
  readonly property bool showClock: root.settingShowClock && styleWantsClock
  readonly property bool showDate: root.settingShowDate && styleWantsDate
  readonly property bool showUser: root.settingShowUser && styleWantsUser
  readonly property bool centerLayout: ["corner","split","terminal","vertical","card","line"].indexOf(style) < 0
  readonly property int clockSize: style === "mono" ? 112 : (style === "stack" || style === "duo" ? 96 : (style === "neon" ? 88 : (style === "clean" || style === "glass" || style === "orbit" || style === "dashboard" ? 68 : (style === "battery" ? 68 : (style === "corner" ? 60 : (style === "poster" ? 40 : (style === "nowplaying" ? 26 : (style === "frame" ? 38 : 60))))))))
  readonly property color clockColor: style === "neon" ? root.accent : (style === "duo" ? root.fg : root.fg)

  // ---- special background shapes -------------------------------------------
  Rectangle { // split left panel
    visible: root.style === "split"
    anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
    width: parent.width * 0.34
    color: Qt.rgba(root.bg.r, root.bg.g, root.bg.b, 0.95)
  }
  Rectangle { // vertical left strip
    visible: root.style === "vertical"
    anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
    width: 160
    color: Qt.rgba(root.bg.r, root.bg.g, root.bg.b, 0.9)
  }
  Rectangle { // frame
    visible: root.style === "frame"
    anchors.centerIn: parent
    width: parent.width * 0.96; height: parent.height * 0.92
    radius: 24; color: "transparent"
    border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.8)
    border.width: 2
  }
  Rectangle { // glass card
    visible: root.style === "glass"
    anchors.centerIn: parent
    width: Math.min(360, parent.width - 64); height: 300
    radius: 24
    color: Qt.rgba(root.surface.r, root.surface.g, root.surface.b, 0.6)
    border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.13)
    border.width: 1
  }
  Rectangle { // orbit circle
    visible: root.style === "orbit"
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: 20
    width: 360; height: 360; radius: 180
    color: Qt.rgba(root.bg.r, root.bg.g, root.bg.b, 0.65)
    border.width: 3
    border.color: root.accent
  }
  Rectangle { // pill
    visible: root.style === "pill"
    anchors.centerIn: parent
    width: Math.min(440, parent.width - 64); height: 70; radius: 35
    color: Qt.rgba(root.surface.r, root.surface.g, root.surface.b, 0.9)
  }
  Rectangle { // line accent
    visible: root.style === "line"
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: 28
    width: 300; height: 2; color: root.accent
  }
  Rectangle { // card bottom
    visible: root.style === "card"
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom; anchors.bottomMargin: 80
    width: Math.min(420, parent.width - 64); height: 150; radius: 18
    color: Qt.rgba(root.bg.r, root.bg.g, root.bg.b, 0.93)
    border.color: root.border; border.width: 1
  }
  Rectangle { // calendar card
    visible: root.style === "calendar"
    anchors.centerIn: parent; anchors.verticalCenterOffset: 20
    width: Math.min(640, parent.width - 64); height: 330; radius: 20
    color: Qt.rgba(root.bg.r, root.bg.g, root.bg.b, 0.86)
    border.color: root.border; border.width: 1
  }

  // ---- clock ---------------------------------------------------------------
  Text {
    id: clockText
    readonly property bool customPos: root.customClockX >= 0 && root.customClockY >= 0
    visible: root.showClock && root.style !== "stack" && root.style !== "duo" && root.style !== "binary" && root.style !== "words" && root.style !== "quote" && root.style !== "vertical"
    text: root.timeText
    color: root.clockColor
    font.family: root.font
    font.pixelSize: root.clockSize
    font.bold: true
    Binding { when: clockText.customPos; target: clockText; property: "x"; value: Math.max(0, Math.min(clockText.parent.width - clockText.width, root.customClockX * clockText.parent.width - clockText.width / 2)) }
    Binding { when: clockText.customPos; target: clockText; property: "y"; value: Math.max(0, Math.min(clockText.parent.height - clockText.height, root.customClockY * clockText.parent.height - clockText.height / 2)) }
    anchors.horizontalCenter: customPos ? undefined : (root.centerLayout || ["pill","frame","nowplaying","poster","orbit","glass","dashboard","day","weather","battery","avatar","calendar","neon"].indexOf(root.style) >= 0 ? parent.horizontalCenter : undefined)
    anchors.left: customPos ? undefined : (["corner","split","terminal"].indexOf(root.style) >= 0 ? parent.left : undefined)
    anchors.leftMargin: customPos ? 0 : (root.style === "corner" ? 60 : (root.style === "split" ? parent.width * 0.08 : (root.style === "terminal" ? 80 : 0)))
    anchors.top: customPos ? undefined : (["frame","nowplaying","terminal"].indexOf(root.style) >= 0 ? parent.top : undefined)
    anchors.topMargin: customPos ? 0 : (root.style === "frame" ? 70 : (root.style === "nowplaying" ? 60 : (root.style === "terminal" ? 80 : 0)))
    anchors.bottom: customPos ? undefined : (["corner"].indexOf(root.style) >= 0 ? parent.bottom : undefined)
    anchors.bottomMargin: customPos ? 0 : (root.style === "corner" ? 110 : 0)
    anchors.verticalCenter: customPos ? undefined : (["classic","clean","mono","pill","glass","orbit","dashboard","zen","neon","poster","duo","day","weather","battery","avatar","calendar","line","dot","quote","words","split"].indexOf(root.style) >= 0 ? parent.verticalCenter : undefined)
    anchors.verticalCenterOffset: customPos ? 0 : ({
      classic: -80, clean: -60, mono: -80, glass: -70, orbit: -70, dashboard: -120, zen: -90, neon: -90, poster: -50, day: -90, weather: -120, battery: -90, avatar: -150, calendar: -90, split: -90
    }[root.style] !== undefined ? { classic: -80, clean: -60, mono: -80, glass: -70, orbit: -70, dashboard: -120, zen: -90, neon: -90, poster: -50, day: -90, weather: -120, battery: -90, avatar: -150, calendar: -90, split: -90 }[root.style] : -20)
  }

  // stack/duo split clocks
  Text {
    visible: root.style === "stack" || root.style === "duo"
    text: Qt.formatTime(new Date(), "HH")
    color: root.fg
    font.family: root.font; font.pixelSize: 96; font.bold: true
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.horizontalCenterOffset: root.style === "duo" ? -90 : 0
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: root.style === "stack" ? -130 : -70
  }
  Text {
    visible: root.style === "stack" || root.style === "duo"
    text: Qt.formatTime(new Date(), "mm")
    color: root.accent
    font.family: root.font; font.pixelSize: 96; font.bold: true
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.horizontalCenterOffset: root.style === "duo" ? 90 : 0
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: root.style === "stack" ? 10 : -70
  }
  Rectangle {
    visible: root.style === "duo"
    width: 4; height: 90; radius: 2
    color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.4)
    anchors.centerIn: parent; anchors.verticalCenterOffset: -70
  }

  // vertical rotated clock
  Item {
    visible: root.style === "vertical"
    width: 160; height: parent.height
    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
    Text {
      anchors.centerIn: parent
      rotation: 90
      text: root.timeText
      color: root.fg
      font.family: root.font; font.pixelSize: 72; font.bold: true
    }
  }

  // binary/words/quote special main text
  Text {
    visible: root.style === "binary"
    text: root.infoText || "·····"
    color: root.accent
    font.family: root.font; font.pixelSize: 40; font.bold: true
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: -70
  }
  Text {
    visible: root.style === "binary"
    text: root.infoText2 || "·····"
    color: root.fg
    font.family: root.font; font.pixelSize: 40; font.bold: true
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: 0
  }
  Text {
    visible: root.style === "binary"
    text: "16 8 4 2 1   ·   " + root.timeText
    color: root.muted
    font.family: root.font; font.pixelSize: 11
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: 55
  }
  Text {
    visible: root.style === "words"
    text: root.infoText || root.timeText
    color: root.fg
    font.family: root.font; font.pixelSize: 54; font.bold: true
    anchors.left: parent.left; anchors.leftMargin: 100
    anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: -40
    width: parent.width - 200; wrapMode: Text.WordWrap
  }
  Text {
    visible: root.style === "quote"
    text: root.infoText ? "“" + root.infoText + "”" : "“Breathe.”"
    color: root.fg
    font.family: root.font; font.pixelSize: 28
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: -40
    width: Math.min(760, parent.width - 120); wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter
  }

  // ---- date / user / info --------------------------------------------------
  Text {
    id: dateLabel
    visible: ["classic","clean","corner","frame","glass","orbit","dashboard","zen","split","calendar","weather","neon","day","poster","battery","avatar","card","nowplaying","vertical","duo","stack","mono","line","terminal","words","quote"].indexOf(root.style) >= 0 && root.style !== "dot" && root.style !== "binary" && root.style !== "pill"
    text: {
      if (root.style === "terminal") return "last seen " + Qt.formatDateTime(new Date(), "ddd d MMM, HH:mm")
      if (root.style === "calendar" || root.style === "split" || root.style === "clean" || root.style === "corner" || root.style === "frame" || root.style === "glass" || root.style === "orbit" || root.style === "dashboard" || root.style === "duo" || root.style === "day" || root.style === "weather" || root.style === "words") return root.dateText
      if (root.style === "zen") return root.timeText + "  ·  " + Qt.formatDate(new Date(), "dddd")
      if (root.style === "quote") return root.timeText + "  ·  " + Qt.formatDate(new Date(), "dddd")
      if (root.style === "mono") return root.dateText
      if (root.style === "line") return root.timeText + "  ·  " + root.dateText
      if (root.style === "poster") return Qt.formatDate(new Date(), "d MMMM yyyy")
      if (root.style === "avatar") return root.timeText + "  ·  " + Qt.formatDate(new Date(), "ddd d MMM")
      if (root.style === "card") return root.timeText
      if (root.style === "nowplaying") return root.dateText
      if (root.style === "vertical") return root.shortDateText
      if (root.style === "stack" || root.style === "neon") return root.dateText
      if (root.style === "battery") return "up " + (root.infoText2 || "")
      return root.dateText
    }
    color: (root.style === "split" || root.style === "neon" || root.style === "poster" || root.style === "quote") ? root.accent : (root.style === "mono" || root.style === "terminal" || root.style === "line" ? root.muted : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.75))
    font.family: root.font
    font.pixelSize: root.style === "poster" ? 13 : (root.style === "mono" || root.style === "line" || root.style === "terminal" ? 12 : 14)
    anchors.horizontalCenter: ["corner","split","terminal","vertical","card"].indexOf(root.style) < 0 ? parent.horizontalCenter : undefined
    anchors.left: ["corner","split","terminal","vertical","words"].indexOf(root.style) >= 0 ? parent.left : undefined
    anchors.leftMargin: root.style === "corner" ? 64 : (root.style === "split" ? parent.width * 0.084 : (root.style === "terminal" ? 80 : (root.style === "vertical" ? 40 : (root.style === "words" ? 104 : 0))))
    anchors.top: ["terminal","nowplaying","frame"].indexOf(root.style) >= 0 ? parent.top : undefined
    anchors.topMargin: root.style === "terminal" ? 155 : (root.style === "nowplaying" ? 105 : (root.style === "frame" ? 130 : 0))
    anchors.bottom: ["corner","vertical","card"].indexOf(root.style) >= 0 ? parent.bottom : undefined
    anchors.bottomMargin: root.style === "corner" ? 70 : (root.style === "vertical" ? 40 : (root.style === "card" ? 175 : 0))
    anchors.verticalCenter: ["classic","clean","mono","glass","orbit","dashboard","zen","neon","poster","duo","day","weather","battery","avatar","calendar","line","quote","split","stack","words"].indexOf(root.style) >= 0 ? parent.verticalCenter : undefined
    anchors.verticalCenterOffset: {
      if (root.style === "classic") return 10
      if (root.style === "clean") return 20
      if (root.style === "mono") return 10
      if (root.style === "glass") return 0
      if (root.style === "orbit") return 0
      if (root.style === "dashboard") return -40
      if (root.style === "zen") return -30
      if (root.style === "neon") return -10
      if (root.style === "poster") return 10
      if (root.style === "duo") return 30
      if (root.style === "day") return -10
      if (root.style === "weather") return -50
      if (root.style === "battery") return -10
      if (root.style === "avatar") return -90
      if (root.style === "calendar") return -20
      if (root.style === "split") return -10
      if (root.style === "stack") return 150
      if (root.style === "words") return 30
      if (root.style === "quote") return 30
      if (root.style === "line") return -70
      return -10
    }
  }

  Text {
    visible: root.showUser && root.style !== "terminal" && root.style !== "card" && root.style !== "avatar"
    text: root.style === "dot" ? "Hi, " + root.userName : (root.style === "split" ? "Hi, " + root.userName : root.userName)
    color: root.style === "dot" || root.style === "split" ? root.muted : root.fg
    font.family: root.font
    font.pixelSize: root.style === "dot" ? 16 : (root.style === "split" ? 13 : 22)
    font.bold: root.style === "classic"
    anchors.horizontalCenter: ["split","terminal"].indexOf(root.style) < 0 ? parent.horizontalCenter : undefined
    anchors.left: root.style === "split" ? parent.left : undefined
    anchors.leftMargin: root.style === "split" ? parent.width * 0.084 : 0
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: root.style === "classic" ? -100 : (root.style === "dot" ? -40 : (root.style === "split" ? 50 : -100))
  }

  // terminal prompt
  Text {
    visible: root.style === "terminal"
    text: root.userName + "@aequalyn ~ $ unlock"
    color: root.fg
    font.family: root.font; font.pixelSize: 16
    anchors.left: parent.left; anchors.leftMargin: 80
    anchors.top: parent.top; anchors.topMargin: 120
  }

  // avatar image
  Image {
    visible: root.style === "avatar" || root.style === "card"
    source: "file://" + (Quickshell.env("HOME") || "") + "/.face"
    width: root.style === "avatar" ? 150 : 72; height: width
    fillMode: Image.PreserveAspectCrop
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.horizontalCenterOffset: root.style === "card" ? -140 : 0
    anchors.verticalCenter: root.style === "avatar" ? parent.verticalCenter : undefined
    anchors.verticalCenterOffset: root.style === "avatar" ? -170 : 0
    anchors.bottom: root.style === "card" ? parent.bottom : undefined
    anchors.bottomMargin: root.style === "card" ? 120 : 0
    layer.enabled: true
    layer.effect: MultiEffect { maskEnabled: true; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }
  }
  Rectangle { // avatar ring fallback border
    visible: (root.style === "avatar" || root.style === "card")
    width: (root.style === "avatar" ? 150 : 72) + 6; height: width; radius: width/2
    color: "transparent"
    border.width: root.style === "avatar" ? 3 : 2
    border.color: root.accent
    anchors.centerIn: parent.children[parent.children.length - 2]
  }

  // ---- extra info labels ---------------------------------------------------
  Text {
    visible: root.style === "dashboard" || root.style === "weather" || root.style === "day" || root.style === "battery"
    text: root.infoText
    color: root.style === "day" ? root.accent : (root.style === "battery" ? root.accent : root.fg)
    font.family: root.font; font.pixelSize: root.style === "weather" ? 20 : 14
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: root.style === "dashboard" ? 30 : (root.style === "weather" ? -20 : (root.style === "day" ? -20 : 0))
  }
  Text {
    visible: root.style === "nowplaying"
    text: root.infoText
    color: root.accent
    font.family: root.font; font.pixelSize: 12
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: 100
  }

  // ---- password field ------------------------------------------------------
  readonly property string effectiveFieldPosition: {
    if (root.fieldPosition === "bottom" || root.fieldPosition === "left" || root.fieldPosition === "center") return root.fieldPosition
    return "center"
  }
  readonly property bool fieldBottom: effectiveFieldPosition === "bottom" || (effectiveFieldPosition === "center" && ["corner","frame","card","mono","nowplaying","poster","vertical"].indexOf(root.style) >= 0)
  readonly property bool fieldLeft: effectiveFieldPosition === "left" || (effectiveFieldPosition === "center" && ["split","terminal","words"].indexOf(root.style) >= 0)
  readonly property bool fieldPill: root.style === "pill" && effectiveFieldPosition === "center"

  Rectangle {
    id: field
    visible: root.style !== "custom"
    width: root.fieldPill ? 250 : (root.style === "terminal" ? 420 : (root.style === "line" ? 300 : Math.min(root.style === "dashboard" || root.style === "nowplaying" || root.style === "frame" || root.style === "glass" || root.style === "orbit" || root.style === "split" ? 280 : 260, parent.width - 64)))
    height: root.style === "terminal" ? 36 : (root.style === "line" ? 44 : (root.style === "pill" ? 46 : 44))
    radius: root.style === "terminal" || root.style === "line" ? 0 : (root.style === "pill" ? 23 : (["clean","nowplaying","weather","day","quote","avatar","poster","dot"].indexOf(root.style) >= 0 ? 22 : 10))
    color: root.style === "terminal" || root.style === "line" || root.style === "dot" ? root.bg : (root.style === "mono" ? root.bg : Qt.rgba(root.surface.r, root.surface.g, root.surface.b, 0.92))
    border.color: root.failureMessage ? root.error : (input.activeFocus ? root.accent : (root.style === "line" ? "transparent" : root.border))
    border.width: root.style === "line" || root.style === "dot" || root.style === "terminal" ? 0 : (input.activeFocus || root.failureMessage ? 2 : 1)
    readonly property bool customPos: root.customFieldX >= 0 && root.customFieldY >= 0
    anchors.horizontalCenter: customPos ? undefined : ((!root.fieldLeft && !root.fieldPill) ? parent.horizontalCenter : undefined)
    anchors.horizontalCenterOffset: customPos ? 0 : (root.style === "card" ? 40 : 0)
    anchors.left: customPos ? undefined : (root.fieldLeft ? parent.left : undefined)
    anchors.leftMargin: customPos ? 0 : (root.style === "split" ? parent.width * 0.08 : (root.style === "terminal" ? 80 : (root.style === "words" ? 100 : 0)))
    anchors.right: customPos ? undefined : (root.style === "corner" ? parent.right : undefined)
    anchors.rightMargin: customPos ? 0 : (root.style === "corner" ? 60 : 0)
    anchors.bottom: customPos ? undefined : (root.fieldBottom ? parent.bottom : undefined)
    anchors.bottomMargin: customPos ? 0 : (root.style === "corner" ? 70 : (root.style === "frame" ? 90 : (root.style === "card" ? 105 : (root.style === "mono" || root.style === "nowplaying" || root.style === "poster" ? 80 : (root.style === "vertical" ? 60 : 0)))))
    anchors.verticalCenter: customPos ? undefined : ((!root.fieldBottom && root.style !== "terminal") ? parent.verticalCenter : undefined)
    anchors.verticalCenterOffset: customPos ? 0 : (root.fieldBottom ? 0 : ({
      classic: 120, clean: 130, glass: 120, orbit: 130, dashboard: 140, zen: 110, quote: 110, neon: 120, split: 150, stack: 170, duo: 130, day: 110, weather: 110, battery: 120, avatar: 70, calendar: 120, line: 30, dot: 30, words: 120, pill: 0
    }[root.style] !== undefined ? { classic: 120, clean: 130, glass: 120, orbit: 130, dashboard: 140, zen: 110, quote: 110, neon: 120, split: 150, stack: 170, duo: 130, day: 110, weather: 110, battery: 120, avatar: 70, calendar: 120, line: 30, dot: 30, words: 120, pill: 0 }[root.style] : 120))
    anchors.top: customPos ? undefined : (root.style === "terminal" ? parent.top : undefined)
    anchors.topMargin: customPos ? 0 : (root.style === "terminal" ? 200 : 0)
    Binding { when: field.customPos; target: field; property: "x"; value: Math.max(0, Math.min(field.parent.width - field.width, root.customFieldX * field.parent.width - field.width / 2)) }
    Binding { when: field.customPos; target: field; property: "y"; value: Math.max(0, Math.min(field.parent.height - field.height, root.customFieldY * field.parent.height - field.height / 2)) }
    Binding { when: !field.customPos && root.fieldPill; target: field; property: "x"; value: (field.parent.width - pillShape.width) / 2 + pillShape.width - field.width - 12 }

    TextInput {
      id: input
      anchors.fill: parent
      anchors.leftMargin: 16; anchors.rightMargin: 44
      verticalAlignment: TextInput.AlignVCenter
      echoMode: TextInput.Password
      passwordCharacter: "•"
      maximumLength: 512
      focus: true
      color: root.fg
      font.family: root.font
      font.pixelSize: 16
      selectByMouse: true
      onAccepted: { const value = text; text = ""; if (value) root.submitPassword(value) }
      onTextEdited: root.clearFailure()
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Space && text === "") { root.triggerGlance(); event.accepted = true }
      }
    }

    Text {
      anchors.right: parent.right; anchors.rightMargin: 14
      anchors.verticalCenter: parent.verticalCenter
      text: root.fingerprintConfigured ? "󰏖" : "󰌾"
      color: root.fingerprintConfigured ? (root.fingerprintClaimed ? root.accent : root.muted) : root.muted
      font.family: root.font; font.pixelSize: 18
      opacity: root.authenticating ? 0.5 : 1
    }

    // placeholder
    Text {
      anchors.left: parent.left; anchors.leftMargin: 16
      anchors.verticalCenter: parent.verticalCenter
      visible: input.text.length === 0 && !input.activeFocus
      text: root.style === "terminal" ? "password:" : (root.style === "zen" ? "Breathe, then type" : "")
      color: root.style === "terminal" ? root.accent : root.muted
      font.family: root.font; font.pixelSize: 14
    }
  }

  // pill needs the field positioned relative to pill shape
  Item {
    id: pillShape
    visible: root.style === "pill"
    anchors.centerIn: parent
    width: Math.min(440, parent.width - 64); height: 70
  }

  Text {
    visible: root.style !== "custom" && root.style !== "dot" && root.style !== "line"
    anchors.horizontalCenter: field.horizontalCenter
    anchors.top: field.bottom; anchors.topMargin: 16
    text: root.failureMessage
      ? root.failureMessage + (root.failedAttempts > 1 ? " (" + root.failedAttempts + ")" : "")
      : (root.glanceScanning ? "Scanning face…" : (root.authenticating ? "Checking…" : "Password, then Enter · Space for face unlock"))
    color: root.failureMessage ? root.error : root.muted
    font.family: root.font; font.pixelSize: 12
  }

  Text {
    visible: root.settingShowMedia && root.mediaText !== ""
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom; anchors.bottomMargin: root.settingShowBattery && root.batteryText !== "" ? 72 : 52
    text: "󰎆  " + root.mediaText
    color: root.muted
    font.family: root.font; font.pixelSize: 11
    elide: Text.ElideRight
    width: Math.min(parent.width - 80, 600)
    horizontalAlignment: Text.AlignHCenter
  }

  Text {
    visible: root.settingShowBattery && root.batteryText !== ""
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom; anchors.bottomMargin: 52
    text: root.batteryText
    color: root.muted
    font.family: root.font; font.pixelSize: 11
  }

  // ---- custom layout renderer ---------------------------------------------
  Repeater {
    model: root.style === "custom" ? root.customItems : []
    delegate: Item {
      id: customItem
      required property var modelData
      required property int index
      readonly property string kind: String(modelData.type || "")
      readonly property real cx: Number(modelData.x ?? 0.5)
      readonly property real cy: Number(modelData.y ?? 0.5)
      readonly property bool shown: modelData.visible !== false
      x: cx * root.width - width / 2
      y: cy * root.height - height / 2
      width: kind === "field" ? Math.min(320, root.width - 40)
            : kind === "clock" ? 280 : kind === "date" ? 260 : kind === "user" ? 200
            : kind === "media" ? Math.min(360, root.width - 40) : kind === "battery" ? 140
            : kind === "weather" ? 220 : kind === "quote" ? Math.min(500, root.width - 80)
            : kind === "day" ? 220 : kind === "calendar" ? 280
            : kind === "binary" ? 220 : kind === "words" ? Math.min(500, root.width - 80)
            : 200
      height: kind === "field" ? 56 : kind === "clock" ? 90 : kind === "date" ? 44
            : kind === "user" ? 44 : kind === "media" ? 44 : kind === "battery" ? 44
            : kind === "weather" ? 44 : kind === "quote" ? 70
            : kind === "day" ? 44 : kind === "calendar" ? 180
            : kind === "binary" ? 60 : kind === "words" ? 80
            : 40
      visible: shown

      Text {
        id: clockText
        visible: customItem.kind === "clock"
        anchors.centerIn: parent
        text: root.timeText
        color: root.fg; font.family: root.font; font.pixelSize: 72; font.bold: true
      }
      Text {
        id: dateText
        visible: customItem.kind === "date"
        anchors.centerIn: parent
        text: root.dateText
        color: root.muted; font.family: root.font; font.pixelSize: 18
      }
      Text {
        id: userText
        visible: customItem.kind === "user"
        anchors.centerIn: parent
        text: root.userName || "User"
        color: root.fg; font.family: root.font; font.pixelSize: 22; font.bold: true
      }
      Text {
        id: mediaTextItem
        visible: customItem.kind === "media"
        anchors.centerIn: parent
        text: root.mediaText ? "󰎆  " + root.mediaText : "󰎆  Not playing"
        color: root.muted; font.family: root.font; font.pixelSize: 14
        elide: Text.ElideRight; width: Math.min(implicitWidth, 500)
      }
      Text {
        id: batteryTextItem
        visible: customItem.kind === "battery"
        anchors.centerIn: parent
        text: root.batteryText || "󰁹 --%"
        color: root.muted; font.family: root.font; font.pixelSize: 14
      }
      Text {
        id: weatherText
        visible: customItem.kind === "weather"
        anchors.centerIn: parent
        text: root.infoText || "Weather"
        color: root.fg; font.family: root.font; font.pixelSize: 20
      }
      Text {
        id: quoteText
        visible: customItem.kind === "quote"
        anchors.centerIn: parent
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: root.infoText || "Quote"
        color: root.fg; font.family: root.font; font.pixelSize: 22; font.italic: true
      }
      Text {
        id: dayText
        visible: customItem.kind === "day"
        anchors.centerIn: parent
        text: root.infoText || "Day progress"
        color: root.fg; font.family: root.font; font.pixelSize: 18
      }
      Text {
        id: calendarText
        visible: customItem.kind === "calendar"
        anchors.centerIn: parent
        text: root.infoText || Qt.formatDate(new Date(), "MMMM yyyy")
        color: root.fg; font.family: root.font; font.pixelSize: 14
        horizontalAlignment: Text.AlignHCenter
      }
      Column {
        id: binaryCol
        visible: customItem.kind === "binary"
        anchors.centerIn: parent
        spacing: 4
        Text { text: root.infoText || "······"; color: root.accent; font.family: root.font; font.pixelSize: 20 }
        Text { text: root.infoText2 || "······"; color: root.muted; font.family: root.font; font.pixelSize: 20 }
      }
      Text {
        id: wordsText
        visible: customItem.kind === "words"
        anchors.centerIn: parent
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: root.infoText || root.timeText
        color: root.fg; font.family: root.font; font.pixelSize: 34; font.bold: true
      }

      Rectangle {
        visible: customItem.kind === "field"
        anchors.fill: parent
        radius: 12
        color: Qt.rgba(root.surface.r, root.surface.g, root.surface.b, 0.94)
        border.color: root.failureMessage ? root.error : (customInput.activeFocus ? root.accent : root.border)
        border.width: customInput.activeFocus || root.failureMessage ? 2 : 1
        TextInput {
          id: customInput
          anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 44
          verticalAlignment: TextInput.AlignVCenter
          echoMode: TextInput.Password; passwordCharacter: "•"
          focus: !root.preview
          color: root.fg; font.family: root.font; font.pixelSize: 16
          onAccepted: { const v = text; text = ""; if (v) root.submitPassword(v) }
          onTextEdited: root.clearFailure()
          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Space && text === "") { root.triggerGlance(); event.accepted = true }
          }
        }
        Text {
          anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
          text: root.fingerprintConfigured ? "󰏖" : "󰌾"
          color: root.fingerprintConfigured ? (root.fingerprintClaimed ? root.accent : root.muted) : root.muted
          font.family: root.font; font.pixelSize: 18
        }
      }
    }
  }

  Text {
    visible: root.style === "custom"
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom; anchors.bottomMargin: 52
    text: root.failureMessage
      ? root.failureMessage + (root.failedAttempts > 1 ? " (" + root.failedAttempts + ")" : "")
      : (root.glanceScanning ? "Scanning face…" : (root.authenticating ? "Checking…" : "Password, then Enter · Space for face unlock"))
    color: root.failureMessage ? root.error : root.muted
    font.family: root.font; font.pixelSize: 12
  }

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom; anchors.bottomMargin: 28
    text: "Aequalyn"
    color: root.muted
    font.family: root.font; font.pixelSize: 12
    opacity: 0.7
    visible: root.style !== "terminal" && root.style !== "corner"
  }

  Connections {
    target: LockService
    function onSessionSecureChanged() { if (root.sessionSecure && !root.preview) input.forceActiveFocus() }
  }
}
