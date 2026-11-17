// Lock and sleep: what happens when you step away, and keeping it awake for now.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/settings"
import "root:/plugins/idleInhibitor"
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
    stageHeight: 120
    stage: Rectangle {
        anchors.fill: parent
        radius: 14
        color: Cc.theme.bgSurface
        Canvas {
            id: line
            anchors.fill: parent
            readonly property var key: [JSON.stringify(page.steps), CaffeineService.active, width, String(Cc.theme.accentPrimary)]
            onKeyChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const rgba = (c, a) => "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + a + ")";
                const steps = page.steps;
                const last = steps.length ? steps[steps.length - 1].at : 10;
                const max = Math.max(10, Math.ceil((last * 1.15) / 5) * 5);
                const x0 = 28, x1 = width - 28, y = height / 2 + 6;
                const X = m => x0 + (x1 - x0) * Math.min(m, max) / max;
                ctx.lineCap = "round";
                ctx.strokeStyle = rgba(Cc.theme.textPrimary, 0.12);
                ctx.lineWidth = 6;
                ctx.beginPath(); ctx.moveTo(x0, y); ctx.lineTo(x1, y); ctx.stroke();
                // the minute marks
                ctx.fillStyle = rgba(Cc.theme.textPrimary, 0.45);
                ctx.font = "10px 'JetBrainsMono Nerd Font'";
                const every = max <= 30 ? 5 : max <= 60 ? 10 : 30;
                for (let m = 0; m <= max; m += every) ctx.fillText(m + " min", X(m) - 14, y + 24);
                // you step away, then each step
                ctx.fillStyle = rgba(Cc.theme.textPrimary, 0.75);
                ctx.font = "12px sans-serif";
                ctx.fillText(CaffeineService.active ? "Kept awake: nothing happens" : "You step away", x0 - 6, y - 22);
                if (CaffeineService.active) return;
                steps.forEach((st, i) => {
                    const c = Cc.theme[st.tone];
                    ctx.fillStyle = rgba(c, 1);
                    ctx.beginPath(); ctx.arc(X(st.at), y, 8, 0, Math.PI * 2); ctx.fill();
                    ctx.font = "600 12px sans-serif";
                    const tw = ctx.measureText(st.label).width;
                    ctx.fillText(st.label, Math.min(x1 - tw, Math.max(x0, X(st.at) - tw / 2)), y - 20 - (i % 2) * 16);
                });
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
        title: "Sleep"
        CcToggle { setting: "suspendEnabled"; title: "Go to sleep when I'm away"; sub: "Saves the battery. Off: only the screen turns off." }
        CcSlider {
            visible: AequalynSettings.suspendEnabled
            setting: "suspendMinutes"; title: "After"
            from: 1; to: 240; step: 1; unit: " min"
        }
    }
}
