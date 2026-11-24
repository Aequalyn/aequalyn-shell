// Text: fonts and text size used across the desktop.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "root:/settings"
import ".."

CcPage {
    id: page
    title: "Text"
    sub: "Fonts and text size used across the shell, terminals, and apps."
    tabs: ["Fonts", "Text"]

    property var fontList: []

    function loadFonts() {
        fontProc.running = true
    }
    Component.onCompleted: loadFonts()

    Process {
        id: fontProc
        command: ["sh", "-c", "fc-list --format '%{family[0]}\\n' | sort -u"]
        stdout: StdioCollector { id: fontOut }
        onExited: {
            const installed = {}
            for (const n of String(fontOut.text || "").split("\n")) { const name = n.trim(); if (name) installed[name.toLowerCase()] = name }
            const curated = ["Aequalyn","Aequalyn Mono","JetBrainsMono Nerd Font","Noto Sans Mono","Adwaita Mono","Liberation Mono","Noto Sans","DejaVu Sans","Adwaita Sans","Figtree"]
            const list = []
            for (const c of curated) { if (installed[c.toLowerCase()] || c === "Aequalyn") list.push(installed[c.toLowerCase()] || c) }
            for (const n of Object.values(installed)) { if (list.indexOf(n) < 0) list.push(n) }
            page.fontList = list
        }
    }



    readonly property var fontOptions: {
        const q = ""
        const opts = []
        for (const f of page.fontList) opts.push({ key: f, label: f })
        return opts
    }

    CcSection {
        visible: page.tab === 0
        title: "Use same font everywhere"
        hint: "When on, the selected font is used for both interface and monospace text."
        CcToggle {
            title: "Same font for UI and mono"
            checked: AequalynSettings.fontSame
            onToggled: v => AequalynSettings.setFontSame(v)
        }
    }

    CcSection {
        visible: page.tab === 0
        title: "Font"
        hint: AequalynSettings.fontSame
            ? "Used everywhere: shell, panels, terminals, and supported apps."
            : "Pick interface and monospace fonts separately."
        CcSearchableChoice {
            current: AequalynSettings.uiFont
            options: page.fontOptions
            placeholder: "Search fonts..."
            onChosen: v => AequalynSettings.setFont("ui", v)
        }
    }

    CcSection {
        visible: page.tab === 0 && !AequalynSettings.fontSame
        title: "Monospace font"
        hint: "Used by terminals, code, keys, and technical text."
        CcSearchableChoice {
            current: AequalynSettings.monoFont
            options: page.fontOptions
            placeholder: "Search fonts for terminals and code..."
            onChosen: v => AequalynSettings.setFont("mono", v)
        }
    }

    CcSection {
        visible: page.tab === 1
        title: "Text size"
        hint: "Applies across the shell and supported apps/terminals."
        CcSlider {
            title: "Font size"
            from: 8; to: 20; step: 1; unit: " pt"
            value: AequalynSettings.fontSize
            onMoved: v => AequalynSettings.setFontOption("fontSize", Math.round(v))
        }
    }

    CcSection {
        visible: page.tab === 1
        title: "Text rendering"
        hint: "Best-effort system text rendering settings."
        CcToggle {
            title: "Antialiasing"
            sub: "Smooth font edges."
            checked: AequalynSettings.fontAntialiasing !== false
            onToggled: v => AequalynSettings.setFontOption("fontAntialiasing", v)
        }
        Text { text: "Hinting"; color: Cc.theme.textPrimary; font.family: Cc.sans; font.pixelSize: 12; font.weight: Font.DemiBold; Layout.leftMargin: 12; Layout.topMargin: 4 }
        CcChoice {
            options: [{ key: "none", label: "None" }, { key: "slight", label: "Slight" }, { key: "medium", label: "Medium" }, { key: "full", label: "Full" }]
            current: AequalynSettings.fontHinting || "slight"
            onChosen: v => AequalynSettings.setFontOption("fontHinting", v)
        }
        Text { text: "Subpixel order"; color: Cc.theme.textPrimary; font.family: Cc.sans; font.pixelSize: 12; font.weight: Font.DemiBold; Layout.leftMargin: 12; Layout.topMargin: 4 }
        CcChoice {
            options: [{ key: "rgb", label: "RGB" }, { key: "bgr", label: "BGR" }, { key: "vrgb", label: "Vertical RGB" }, { key: "vbgr", label: "Vertical BGR" }, { key: "none", label: "None" }]
            current: AequalynSettings.fontSubpixel || "rgb"
            onChosen: v => AequalynSettings.setFontOption("fontSubpixel", v)
        }
    }

    CcNote {
        visible: page.tab === 0
        text: "Any installed font works, for the interface and for terminals, and changes apply at once. Fonts that are not monospaced are fitted to the terminal's grid."
    }
}
