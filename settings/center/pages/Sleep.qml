// Lock and sleep: what happens when you step away, and keeping it awake for now.
import QtQuick
import QtQuick.Layouts
import Quickshell
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
        { key: "battery", label: "Battery", about: "The time, the battery as a bar of blocks, and how long it has been on." }
    ]
    readonly property var lockNow: lockStyles.find(x => x.key === AequalynSettings.lockStyle) || lockStyles[0]
    CcSection {
        title: "How it looks when locked"
        hint: page.lockNow.about + " In your theme's colours, over your wallpaper; it follows when they change."
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
        title: "Lock screen editor"
        hint: "Customize what the Quickshell lock screen shows."

        Text {
            text: "Wallpaper"
            color: Cc.theme.textMuted
            font.pixelSize: 12
            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.topMargin: 4
        }
        CcChoice {
            options: [
                { key: "wallpaper", label: "Current" },
                { key: "theme",     label: "Theme" },
                { key: "solid",     label: "Solid" }
            ]
            current: AequalynSettings.lockWallpaperSource
            onChosen: key => { AequalynSettings.lockWallpaperSource = key; AequalynSettings.save() }
        }

        Text {
            text: "Password field"
            color: Cc.theme.textMuted
            font.pixelSize: 12
            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.topMargin: 4
        }
        CcChoice {
            options: [
                { key: "center", label: "Center" },
                { key: "bottom", label: "Bottom" },
                { key: "left",   label: "Left" }
            ]
            current: AequalynSettings.lockFieldPosition
            onChosen: key => { AequalynSettings.lockFieldPosition = key; AequalynSettings.save() }
        }

        CcToggle { setting: "lockShowClock"; title: "Show clock" }
        CcToggle { setting: "lockShowDate";  title: "Show date" }
        CcToggle { setting: "lockShowUser";  title: "Show user name" }
        CcToggle { setting: "lockShowMedia"; title: "Show now playing" }
        CcToggle { setting: "lockShowBattery"; title: "Show battery" }

        Text {
            text: "Live preview — drag clock or password field"
            color: Cc.theme.textMuted
            font.pixelSize: 12
            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.topMargin: 8
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 260
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            radius: 12
            color: Cc.theme.bgSurface
            border.color: Cc.theme.bgBorder
            clip: true

            Item {
                id: previewRoot
                anchors.fill: parent
                property real sx: width / 1280
                property real sy: height / 720
                property real s: Math.min(sx, sy)

                Item {
                    id: previewStage
                    width: 1280; height: 720
                    scale: previewRoot.s
                    transformOrigin: Item.TopLeft
                    x: (previewRoot.width - width * scale) / 2
                    y: (previewRoot.height - height * scale) / 2

                    LockView {
                        id: previewLock
                        anchors.fill: parent
                        theme: AequalynDefaultTheme {}
                        wallpaperPath: AequalynSettings.lockWallpaperSource === "solid" ? "" : (AequalynSettings.wallpaperPath || "")
                        userName: Quickshell.env("USER") || ""
                        use24h: AequalynSettings.use24h
                        lockStyle: AequalynSettings.lockStyle
                        fieldPosition: AequalynSettings.lockFieldPosition
                        settingShowUser: AequalynSettings.lockShowUser
                        settingShowClock: AequalynSettings.lockShowClock
                        settingShowDate: AequalynSettings.lockShowDate
                        settingShowMedia: AequalynSettings.lockShowMedia
                        settingShowBattery: AequalynSettings.lockShowBattery
                        customClockX: AequalynSettings.lockClockX
                        customClockY: AequalynSettings.lockClockY
                        customFieldX: AequalynSettings.lockFieldX
                        customFieldY: AequalynSettings.lockFieldY
                        authenticating: false
                        glanceScanning: false
                        fingerprintConfigured: false
                        fingerprintClaimed: false
                        sessionSecure: false
                        preview: true
                    }

                    // drag handle: clock
                    Rectangle {
                        id: clockHandle
                        width: 220; height: 90; radius: 10
                        color: Qt.rgba(1,1,1,0.02)
                        border.color: Qt.rgba(Cc.theme.accentPrimary.r, Cc.theme.accentPrimary.g, Cc.theme.accentPrimary.b, 0.7)
                        border.width: 1
                        visible: AequalynSettings.lockShowClock
                        x: (AequalynSettings.lockClockX >= 0 ? AequalynSettings.lockClockX : 0.5) * previewStage.width - width/2
                        y: (AequalynSettings.lockClockY >= 0 ? AequalynSettings.lockClockY : 0.35) * previewStage.height - height/2
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.SizeAllCursor
                            drag.target: parent; drag.axis: Drag.XAndYAxis
                            onReleased: {
                                AequalynSettings.lockClockX = Math.max(0.05, Math.min(0.95, (parent.x + parent.width/2) / previewStage.width))
                                AequalynSettings.lockClockY = Math.max(0.05, Math.min(0.95, (parent.y + parent.height/2) / previewStage.height))
                                AequalynSettings.save()
                            }
                        }
                        Text { anchors.centerIn: parent; text: "Clock"; color: Cc.theme.accentPrimary; font.pixelSize: 14; font.family: "JetBrainsMono Nerd Font" }
                    }

                    // drag handle: field
                    Rectangle {
                        id: fieldHandle
                        width: 300; height: 56; radius: 10
                        color: Qt.rgba(1,1,1,0.02)
                        border.color: Qt.rgba(Cc.theme.accentSecondary.r, Cc.theme.accentSecondary.g, Cc.theme.accentSecondary.b, 0.7)
                        border.width: 1
                        x: (AequalynSettings.lockFieldX >= 0 ? AequalynSettings.lockFieldX : 0.5) * previewStage.width - width/2
                        y: (AequalynSettings.lockFieldY >= 0 ? AequalynSettings.lockFieldY : 0.68) * previewStage.height - height/2
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.SizeAllCursor
                            drag.target: parent; drag.axis: Drag.XAndYAxis
                            onReleased: {
                                AequalynSettings.lockFieldX = Math.max(0.05, Math.min(0.95, (parent.x + parent.width/2) / previewStage.width))
                                AequalynSettings.lockFieldY = Math.max(0.05, Math.min(0.95, (parent.y + parent.height/2) / previewStage.height))
                                AequalynSettings.save()
                            }
                        }
                        Text { anchors.centerIn: parent; text: "Password"; color: Cc.theme.accentSecondary; font.pixelSize: 14; font.family: "JetBrainsMono Nerd Font" }
                    }
                }
            }
        }

        CcButton {
            text: "Reset element positions"
            icon: "\u{F0453}"
            onClicked: {
                AequalynSettings.lockClockX = -1; AequalynSettings.lockClockY = -1
                AequalynSettings.lockFieldX = -1; AequalynSettings.lockFieldY = -1
                AequalynSettings.save()
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
