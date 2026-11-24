// Lock and sleep: what happens when you step away, and keeping it awake for now.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "root:/settings"
import "root:/plugins/idleInhibitor"
import "root:/plugins/lock"
import ".."

CcPage {
    id: page
    title: "Lock and sleep"
    sub: "What happens when you step away. Moving the mouse or typing starts the count again."

    // when each thing happens after you step away, on one line; it follows the settings
    readonly property var steps: [
        { on: AequalynSettings.screenOffEnabled, at: AequalynSettings.screenOffMinutes, label: "Screen off", tone: "accentCyan" },
        { on: AequalynSettings.lockEnabled, at: AequalynSettings.lockMinutes, label: "Locked", tone: "accentPrimary" },
        { on: AequalynSettings.suspendEnabled, at: AequalynSettings.suspendMinutes, label: "Asleep", tone: "accentOrange" }
    ].filter(x => x.on).sort((a, b) => a.at - b.at)
    stageHeight: 132
    // drawn with plain items, not a canvas: sharp at any screen scale, and in the theme's
    // colours whenever they change
    stage: Rectangle {
        anchors.fill: parent
        radius: 14
        color: Cc.theme.bgSurface
        Item {
            id: tl
            anchors.fill: parent
            anchors.leftMargin: 28
            anchors.rightMargin: 28
            readonly property var steps: page.steps
            readonly property real last: steps.length ? steps[steps.length - 1].at : 10
            // the line runs a little past the last step, to a round number of minutes
            readonly property real max: Math.max(10, Math.ceil((last * 1.15) / 5) * 5)
            readonly property int every: max <= 30 ? 5 : max <= 60 ? 10 : 30
            // low enough for three rows of names over it, the minutes under it
            readonly property real lineY: height - 46
            function at(m) { return width * Math.min(m, max) / max; }
            // each name on the row nearest the line where it doesn't touch the one before
            // (or "You step away"); a name only climbs when it has to
            readonly property var rows: {
                const out = [], ends = [112];        // where each row is taken up to
                for (let i = 0; i < steps.length; i++) {
                    // a name's width, give or take: about 7 px a letter at this size
                    const w = (steps[i].label + "  " + steps[i].at + " min").length * 7 + 6;
                    const x0 = Math.max(0, at(steps[i].at) - w / 2);
                    let r = 0;
                    while (r < ends.length && x0 < ends[r] + 10) r++;
                    out.push(Math.min(r, 2));
                    ends[Math.min(r, 2)] = x0 + w;
                }
                return out;
            }

            Rectangle {
                y: tl.lineY - 3
                width: parent.width
                height: 6
                radius: 3
                color: Qt.rgba(Cc.theme.textPrimary.r, Cc.theme.textPrimary.g, Cc.theme.textPrimary.b, 0.12)
            }
            // the minutes under the line, the first and last kept inside it
            Repeater {
                model: Math.floor(tl.max / tl.every) + 1
                delegate: Text {
                    required property int index
                    readonly property real m: index * tl.every
                    x: index === 0 ? 0 : m >= tl.max ? tl.width - width : tl.at(m) - width / 2
                    y: tl.lineY + 14
                    text: m + " min"
                    color: Cc.theme.textMuted
                    font.family: Cc.mono
                    font.pixelSize: 11
                }
            }
            // where it starts
            Rectangle {
                x: -5; y: tl.lineY - 5
                width: 10; height: 10; radius: 5
                color: Cc.theme.textSecondary
            }
            Text {
                x: -6
                y: tl.lineY - 36
                text: CaffeineService.active ? "Kept awake: nothing happens" : "You step away"
                color: CaffeineService.active ? Cc.theme.accentPrimary : Cc.theme.textSecondary
                font.family: Cc.sans
                font.pixelSize: 12
            }
            // then each step, its dot and its name
            Repeater {
                model: CaffeineService.active ? [] : tl.steps
                delegate: Item {
                    id: stepItem
                    required property var modelData
                    required property int index
                    readonly property color tone: Cc.theme[modelData.tone]
                    readonly property real cx: tl.at(modelData.at)
                    Rectangle {
                        x: stepItem.cx - 8; y: tl.lineY - 8
                        width: 16; height: 16; radius: 8
                        color: stepItem.tone
                        border.width: 3
                        border.color: Cc.theme.bgSurface
                    }
                    Text {
                        id: stepName
                        x: Math.max(0, Math.min(tl.width - width, stepItem.cx - width / 2))
                        y: tl.lineY - 36 - (tl.rows[stepItem.index] || 0) * 18
                        text: stepItem.modelData.label + "  " + stepItem.modelData.at + " min"
                        color: stepItem.tone
                        font.family: Cc.sans
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }
                }
            }
        }
    }

    CcToggle {
        title: "Keep awake now"
        sub: "Nothing locks, dims or sleeps until you turn this off. Super + Shift + C does the same."
        checked: CaffeineService.active
        onToggled: v => v ? CaffeineService.enable() : CaffeineService.disable()
    }

    CcSection {
        title: "Turn the screen off"
        CcToggle { setting: "screenOffEnabled"; title: "Turn the screen off when I'm away"; sub: "Only the screen; nothing locks or sleeps." }
        CcSlider {
            visible: AequalynSettings.screenOffEnabled
            setting: "screenOffMinutes"; title: "After"
            from: 1; to: 120; step: 1; unit: " min"
        }
    }
    CcSection {
        title: "Lock"
        CcToggle { setting: "lockEnabled"; title: "Lock the screen when I'm away"; sub: "Off: it never locks by itself, not even before sleeping." }
        CcSlider {
            visible: AequalynSettings.lockEnabled
            setting: "lockMinutes"; title: "After"
            from: 1; to: 60; step: 1; unit: " min"
        }
    }
    // how it looks while locked: one of the designs (bin/aequalyn-lockscreen), in your
    // theme's colours over your wallpaper
    readonly property var lockStyles: [
        { key: "classic", label: "Classic", about: "The time, your name and the password over the blurred wallpaper." },
        { key: "clean", label: "Clean", about: "A big clock and the date over a soft blur, a round password line under them." },
        { key: "mono", label: "Mono", about: "Only your theme's colour: a large clock, the date, the password line at the bottom." },
        { key: "corner", label: "Corner", about: "The wallpaper as it is; the time in the lower left, the password in the lower right." },
        { key: "pill", label: "Pill", about: "One pill in the middle holding the time and the password." },
        { key: "split", label: "Split", about: "A panel down the left with the time, the date and your name; the wallpaper beside it." },
        { key: "stack", label: "Stack", about: "Hours over minutes, large, the minutes in the accent colour." },
        { key: "dot", label: "Dot", about: "Nothing but a greeting and the dots you type, on your theme's colour." },
        { key: "frame", label: "Frame", about: "The wallpaper inside a thin accent frame, the time at the top." },
        { key: "glass", label: "Glass", about: "A see-through card on a deep blur, with the time, the date and the password." },
        { key: "line", label: "Line", about: "A single accent line to type on, and the time small at the top." },
        { key: "terminal", label: "Terminal", about: "A prompt in the corner: the seconds ticking, your name, and a password: line to type after." },
        { key: "neon", label: "Neon", about: "A glowing clock, date and password ring in your accent colours on the dark." },
        { key: "poster", label: "Poster", about: "Today's name across the whole screen, faint, with the time small over it." },
        { key: "orbit", label: "Orbit", about: "A ring in your two accents around the time and the date." },
        { key: "dashboard", label: "Dashboard", about: "The time, then the battery, how long it has been on, and what is playing." },
        { key: "zen", label: "Zen", about: "No clock to watch: a greeting for the time of day over a deep blur." },
        { key: "vertical", label: "Vertical", about: "The time turned on its side down a dark strip on the left." },
        { key: "duo", label: "Duo", about: "Hours and minutes side by side, the minutes in the accent colour, split by a line." },
        { key: "card", label: "Card", about: "Your picture (~/.face), your name and the password on one card at the bottom." },
        { key: "nowplaying", label: "Now playing", about: "The song's cover, large, with its title and artist, and whether it plays." },
        { key: "binary", label: "Binary", about: "The time in dots, hours over minutes, for those who read them." },
        { key: "words", label: "Words", about: "The time as you'd say it, \"twenty past eleven\", large on the left." },
        { key: "day", label: "Day", about: "The time, and a bar of how much of today has already gone." },
        { key: "calendar", label: "Calendar", about: "The time beside this month's calendar, on one card." },
        { key: "weather", label: "Weather", about: "The time and the sky where you are, looked up every half hour." },
        { key: "quote", label: "Quote", about: "A short line to read, a different one each day, over a deep blur." },
        { key: "avatar", label: "Avatar", about: "Your picture (~/.face) large in a ring of your two accents, your name under it." },
        { key: "battery", label: "Battery", about: "The time, the battery as a bar of blocks, and how long it has been on." },
        { key: "custom", label: "Custom", about: "Your own layout: place elements where you want them and save." }
    ]
    readonly property var lockNow: lockStyles.find(x => x.key === AequalynSettings.lockStyle) || lockStyles[0]

    property string cachedWallpaper: ""
    readonly property string resolvedWallpaper: {
        if (AequalynSettings.lockWallpaperSource === "solid") return ""
        const live = String(AequalynSettings.wallpaperPath || "").trim()
        const cached = String(page.cachedWallpaper || "").trim()
        const svc = String(LockService.wallpaperPath || "").trim()
        if (AequalynSettings.lockWallpaperSource === "theme") return live || cached || svc
        return live || cached || svc
    }
    FileView {
        id: wallpaperCache
        path: Quickshell.env("HOME") + "/.cache/aequalyn/current-wallpaper"
        printErrors: false
        watchChanges: true
        onTextChanged: {
            const raw = typeof wallpaperCache.text === "function" ? wallpaperCache.text() : wallpaperCache.text
            page.cachedWallpaper = String(raw || "").trim()
        }
    }
    Component.onCompleted: {
        try {
            const raw = typeof wallpaperCache.text === "function" ? wallpaperCache.text() : wallpaperCache.text
            page.cachedWallpaper = String(raw || "").trim()
        } catch (e) {}
    }

    readonly property var lockPalette: [
        { type: "clock",    label: "Clock",      icon: "\u{F017}" },
        { type: "date",     label: "Date",       icon: "\u{F073}" },
        { type: "user",     label: "User name",  icon: "\u{F007}" },
        { type: "field",    label: "Password",   icon: "\u{F023}" },
        { type: "media",    label: "Now playing",icon: "\u{F001}" },
        { type: "battery",  label: "Battery",    icon: "\u{F240}" },
        { type: "weather",  label: "Weather",    icon: "\u{F185}" },
        { type: "quote",    label: "Quote",      icon: "\u{F10D}" },
        { type: "day",      label: "Day progress",icon: "\u{F251}" },
        { type: "calendar", label: "Calendar",   icon: "\u{F133}" },
        { type: "binary",   label: "Binary clock",icon: "\u{F1C0}" },
        { type: "words",    label: "Words time", icon: "\u{F031}" }
    ]

    readonly property var defaultCustomLayout: [
        { type: "field", x: 0.5, y: 0.72, visible: true }
    ]

    function readCustomLayout() {
        try {
            const o = JSON.parse(AequalynSettings.lockCustomLayout || "{}")
            if (Array.isArray(o.elements) && o.elements.length) return o.elements
        } catch (e) {}
        return page.defaultCustomLayout.map(e => Object.assign({}, e))
    }

    function writeCustomLayout(elements) {
        const scr = Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
        AequalynSettings.lockCustomLayout = JSON.stringify({
            refW: scr ? scr.width : 1920,
            refH: scr ? scr.height : 1080,
            elements: elements
        })
        AequalynSettings.save()
    }

    function setCustomElement(type, patch) {
        const els = page.readCustomLayout().map(e => Object.assign({}, e))
        let found = false
        for (let i = 0; i < els.length; i++) {
            if (els[i].type === type) { els[i] = Object.assign(els[i], patch); found = true }
        }
        if (!found) els.push(Object.assign({ type: type, x: 0.5, y: 0.5, visible: true }, patch))
        page.writeCustomLayout(els)
    }

    function addCustomElement(type) {
        const els = page.readCustomLayout().map(e => Object.assign({}, e))
        const ex = els.find(e => e.type === type)
        if (ex) { ex.visible = true; page.writeCustomLayout(els); return }
        const defaults = { clock:{x:0.5,y:0.28}, date:{x:0.5,y:0.38}, user:{x:0.5,y:0.48}, field:{x:0.5,y:0.72}, media:{x:0.5,y:0.84}, battery:{x:0.5,y:0.90}, weather:{x:0.5,y:0.18}, quote:{x:0.5,y:0.2}, day:{x:0.5,y:0.18}, calendar:{x:0.5,y:0.35}, binary:{x:0.5,y:0.3}, words:{x:0.3,y:0.4} }
        const d = defaults[type] || {x:0.5,y:0.5}
        els.push({ type: type, x: d.x, y: d.y, visible: true })
        page.writeCustomLayout(els)
    }

    function removeCustomElement(type) {
        const els = page.readCustomLayout().map(e => Object.assign({}, e))
        for (let i = 0; i < els.length; i++) if (els[i].type === type) els[i].visible = false
        page.writeCustomLayout(els)
    }
    CcSection {
        title: "How it looks when locked"
        hint: page.lockNow.about + (page.lockNow.key === "custom" ? " Drawn by Aequalyn's own lock."
            : " Drawn by hyprlock, in your theme's colours over your wallpaper; it follows when they change.")
        CcChoice {
            options: page.lockStyles.map(x => ({ key: x.key, label: x.label }))
            current: page.lockNow.key
            onChosen: key => AequalynSettings.setLockStyle(key)
        }
        CcButton {
            text: "Lock now to see it"; icon: "\u{F033E}"
            onClicked: Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/aequalyn-lockscreen", "try", page.lockNow.key])
        }
    }
    CcSection {
        visible: page.lockNow.key === "custom"
        title: "Lock screen editor"
        hint: "Drag elements from the palette onto the wallpaper preview. Drag placed elements to reposition. Save when ready."

        Text { text: "Wallpaper"; color: Cc.theme.textMuted; font.pixelSize: 12; Layout.fillWidth: true; Layout.leftMargin: 12; Layout.topMargin: 4 }
        CcChoice {
            options: [
                { key: "wallpaper", label: "Current wallpaper" },
                { key: "theme",     label: "Theme wallpaper" },
                { key: "solid",     label: "Solid color" }
            ]
            current: AequalynSettings.lockWallpaperSource
            onChosen: key => { AequalynSettings.lockWallpaperSource = key; AequalynSettings.save() }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 560
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            Layout.topMargin: 8
            radius: 12
            color: Cc.theme.bgSurface
            border.color: Cc.theme.bgBorder
            clip: true

            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10

                // Left palette
                Rectangle {
                    Layout.preferredWidth: 150
                    Layout.fillHeight: true
                    radius: 10
                    color: Qt.rgba(Cc.theme.textPrimary.r, Cc.theme.textPrimary.g, Cc.theme.textPrimary.b, 0.03)
                    border.color: Cc.theme.bgBorder
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 8; spacing: 6
                        Text { text: "Elements"; color: Cc.theme.textMuted; font.pixelSize: 11; font.bold: true; Layout.leftMargin: 4 }
                        Repeater {
                            model: page.lockPalette.slice(0, 6)
                            delegate: Rectangle {
                                required property var modelData
                                Layout.fillWidth: true; Layout.preferredHeight: 34; radius: 8
                                readonly property bool placed: { const e = page.readCustomLayout().find(x => x.type === modelData.type); return !!e && e.visible !== false }
                                color: placed ? Qt.rgba(Cc.theme.accentPrimary.r, Cc.theme.accentPrimary.g, Cc.theme.accentPrimary.b, 0.18) : Qt.rgba(Cc.theme.textPrimary.r, Cc.theme.textPrimary.g, Cc.theme.textPrimary.b, 0.05)
                                border.color: placed ? Cc.theme.accentPrimary : Cc.theme.bgBorder
                                Text { anchors.centerIn: parent; text: modelData.label; color: placed ? Cc.theme.accentPrimary : Cc.theme.textSecondary; font.pixelSize: 11; font.family: Cc.mono }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: placed ? page.removeCustomElement(modelData.type) : page.addCustomElement(modelData.type)
                                }
                            }
                        }
                        Item { Layout.fillHeight: true }
                    }
                }

                // Preview center
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 10
                    color: "#111"
                    border.color: Cc.theme.bgBorder
                    clip: true

                    Item {
                        id: previewRoot
                        anchors.fill: parent

                        Item {
                            id: previewStage
                            readonly property real refW: Quickshell.screens.length > 0 ? Quickshell.screens[0].width : 1920
                            readonly property real refH: Quickshell.screens.length > 0 ? Quickshell.screens[0].height : 1080
                            width: refW; height: refH
                            scale: Math.min(previewRoot.width / refW, previewRoot.height / refH)
                            transformOrigin: Item.TopLeft
                            x: (previewRoot.width - width * scale) / 2
                            y: (previewRoot.height - height * scale) / 2

                            LockView {
                                id: previewLock
                                anchors.fill: parent
                                theme: AequalynDefaultTheme {}
                                wallpaperPath: page.resolvedWallpaper
                                userName: Quickshell.env("USER") || ""
                                use24h: AequalynSettings.use24h
                                lockStyle: "custom"
                                customLayout: AequalynSettings.lockCustomLayout
                                settingShowUser: true
                                settingShowClock: true
                                settingShowDate: true
                                settingShowMedia: true
                                settingShowBattery: true
                                authenticating: false
                                glanceScanning: false
                                fingerprintConfigured: false
                                fingerprintClaimed: false
                                sessionSecure: false
                                preview: true
                            }

                            Repeater {
                                model: page.readCustomLayout()
                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index
                                    readonly property string kind: String(modelData.type || "")
                                    visible: modelData.visible !== false
                                    width: kind === "field" ? Math.min(320, previewStage.width - 40)
                                         : kind === "clock" ? 280 : kind === "date" ? 260 : kind === "user" ? 200
                                         : kind === "media" ? 360 : kind === "battery" ? 140
                                         : kind === "weather" ? 220 : kind === "quote" ? 500
                                         : kind === "day" ? 220 : kind === "calendar" ? 280
                                         : kind === "binary" ? 220 : kind === "words" ? 500 : 200
                                    height: kind === "field" ? 56 : kind === "clock" ? 90 : kind === "quote" ? 70
                                          : kind === "words" ? 80 : kind === "binary" ? 60 : kind === "calendar" ? 180 : 44
                                    radius: 8
                                    color: dragArea.containsMouse || dragArea.drag.active ? Qt.rgba(Cc.theme.accentPrimary.r, Cc.theme.accentPrimary.g, Cc.theme.accentPrimary.b, 0.10) : "transparent"
                                    border.color: dragArea.containsMouse || dragArea.drag.active ? Cc.theme.accentSecondary : Qt.rgba(Cc.theme.accentPrimary.r, Cc.theme.accentPrimary.g, Cc.theme.accentPrimary.b, 0.35)
                                    border.width: 1
                                    x: Number(modelData.x ?? 0.5) * previewStage.width - width/2
                                    y: Number(modelData.y ?? 0.5) * previewStage.height - height/2
                                    z: 10

                                    Text {
                                        visible: dragArea.containsMouse || dragArea.drag.active
                                        anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 4
                                        text: kind
                                        color: Cc.theme.accentPrimary
                                        font.pixelSize: 10; font.family: Cc.mono
                                    }
                                    MouseArea {
                                        id: dragArea
                                        anchors.fill: parent; cursorShape: Qt.SizeAllCursor
                                        hoverEnabled: true
                                        drag.target: parent; drag.axis: Drag.XAndYAxis
                                        drag.minimumX: 0; drag.maximumX: previewStage.width - parent.width
                                        drag.minimumY: 0; drag.maximumY: previewStage.height - parent.height
                                        onReleased: {
                                            page.setCustomElement(kind, {
                                                x: Math.max(0.03, Math.min(0.97, (parent.x + parent.width/2) / previewStage.width)),
                                                y: Math.max(0.03, Math.min(0.97, (parent.y + parent.height/2) / previewStage.height))
                                            })
                                        }
                                    }
                                    // remove button
                                    Rectangle {
                                        width: 18; height: 18; radius: 9
                                        anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 4
                                        color: Qt.rgba(Cc.theme.accentRed.r, Cc.theme.accentRed.g, Cc.theme.accentRed.b, 0.9)
                                        visible: kind !== "field"
                                        Text { anchors.centerIn: parent; text: "×"; color: "white"; font.pixelSize: 12; font.bold: true }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.removeCustomElement(kind) }
                                    }
                                }
                            }
                        }
                    }
                }

                // Right palette
                Rectangle {
                    Layout.preferredWidth: 150
                    Layout.fillHeight: true
                    radius: 10
                    color: Qt.rgba(Cc.theme.textPrimary.r, Cc.theme.textPrimary.g, Cc.theme.textPrimary.b, 0.03)
                    border.color: Cc.theme.bgBorder
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 8; spacing: 6
                        Text { text: "More"; color: Cc.theme.textMuted; font.pixelSize: 11; font.bold: true; Layout.leftMargin: 4 }
                        Repeater {
                            model: page.lockPalette.slice(6)
                            delegate: Rectangle {
                                required property var modelData
                                Layout.fillWidth: true; Layout.preferredHeight: 34; radius: 8
                                readonly property bool placed: { const e = page.readCustomLayout().find(x => x.type === modelData.type); return !!e && e.visible !== false }
                                color: placed ? Qt.rgba(Cc.theme.accentPrimary.r, Cc.theme.accentPrimary.g, Cc.theme.accentPrimary.b, 0.18) : Qt.rgba(Cc.theme.textPrimary.r, Cc.theme.textPrimary.g, Cc.theme.textPrimary.b, 0.05)
                                border.color: placed ? Cc.theme.accentPrimary : Cc.theme.bgBorder
                                Text { anchors.centerIn: parent; text: modelData.label; color: placed ? Cc.theme.accentPrimary : Cc.theme.textSecondary; font.pixelSize: 11; font.family: Cc.mono }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: placed ? page.removeCustomElement(modelData.type) : page.addCustomElement(modelData.type)
                                }
                            }
                        }
                        Item { Layout.fillHeight: true }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true; Layout.leftMargin: 12; Layout.rightMargin: 12; spacing: 8
            CcButton {
                text: "Save as custom lock style"; icon: "\u{F0C7}"
                onClicked: {
                    if (!AequalynSettings.lockCustomLayout) page.writeCustomLayout(page.defaultCustomLayout)
                    AequalynSettings.setLockStyle("custom")
                }
            }
            CcButton {
                text: "Reset layout"; icon: "\u{F0453}"
                onClicked: { page.writeCustomLayout(page.defaultCustomLayout.map(e => Object.assign({}, e))); AequalynSettings.save() }
            }
        }
    }
    CcSection {
        title: "Sleep"
        CcToggle { setting: "suspendEnabled"; title: "Go to sleep when I'm away"; sub: "Saves the battery. Off: only the screen turns off." }
        CcSlider {
            visible: AequalynSettings.suspendEnabled
            setting: "suspendMinutes"; title: "After"
            from: 1; to: 240; step: 1; unit: " min"
        }
    }
}
