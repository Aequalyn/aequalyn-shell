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
