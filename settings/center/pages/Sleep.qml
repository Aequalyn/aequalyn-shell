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
