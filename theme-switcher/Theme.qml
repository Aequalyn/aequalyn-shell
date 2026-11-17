// The desktop's colours, from one of two places (set on the control center's Theme page):
//   a theme      a folder with its colours and its own wallpapers (aequalyn-themes).
//                Picking one applies its colours, and its first wallpaper unless "A
//                theme brings its wallpapers" is off. Another wallpaper keeps them.
//   the wallpaper colours made from whatever wallpaper is on (matugen), following
//                every change of wallpaper.
// ~/.config/quickshell/theme.conf holds "theme:<id>" or "wallpaper".

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "root:/settings"

Singleton {
    id: root

    property int currentIndex: 0
    property int previewIndex: -1
    // true: colours are made from the wallpaper and follow it
    property bool wallpaperMode: false
    property var wallpaperTheme: ({})
    property string configFormat: "conf" // "conf" or "lua" — which hyprland.* is active
    property bool configFormatReady: false
    property bool kdeIntegrationEnabled: Quickshell.env("QUICKSHELL_KDE_INTEGRATION") === "1"
    readonly property bool themesReady: true

    // Folder themes (palette + backgrounds) from `aequalyn-themes list --json`,
    // normalised to the same palette keys as the curated themes.
    property var folderThemes: []
    property bool folderThemesReady: false
    // Id of the folder theme ~/.config/aequalyn/current/theme points to ("" = none).
    property string currentFolderId: ""
    // A palette shown temporarily while browsing (Atelier live preview).
    property var previewPalette: null

    function tryLoadTheme() {
        if (root.configFormatReady && root.themesReady && root.folderThemesReady && !root.initialLoadDone)
            loadProc.running = true;
    }
    property bool initialLoadDone: false

    function reloadFolderThemes() {
        folderProc.running = true;
    }

    function folderTheme(id) {
        for (let i = 0; i < folderThemes.length; i++)
            if (folderThemes[i].id === id) return folderThemes[i];
        return null;
    }

    // ---- colour helpers ------------------------------------------------
    function _rgb(hex) {
        const h = String(hex).replace("#", "");
        return [parseInt(h.substr(0, 2), 16), parseInt(h.substr(2, 2), 16), parseInt(h.substr(4, 2), 16)];
    }
    function _hex(rgb) {
        return "#" + rgb.map(v => Math.max(0, Math.min(255, Math.round(v))).toString(16).padStart(2, "0")).join("");
    }
    function mix(a, b, t) {
        const x = _rgb(a), y = _rgb(b);
        return _hex([x[0] + (y[0] - x[0]) * t, x[1] + (y[1] - x[1]) * t, x[2] + (y[2] - x[2]) * t]);
    }

    // colors.toml (accent, foreground, background, color0..15,
    // selection_background) -> the shell's 13 palette keys.
    function paletteFromColors(c) {
        const bg = c.background || c.color0 || "#1e1e2e";
        const fg = c.foreground || c.color15 || c.color7 || "#cdd6f4";
        const accent = c.accent || c.color4 || "#89b4fa";
        return {
            bgBase: bg,
            bgSurface: mix(bg, fg, 0.06),
            bgHover: mix(bg, fg, 0.10),
            bgSelected: c.selection_background || mix(bg, accent, 0.28),
            bgBorder: mix(bg, fg, 0.18),
            textPrimary: fg,
            textSecondary: c.color7 || mix(fg, bg, 0.2),
            textMuted: c.color8 || mix(fg, bg, 0.45),
            accentPrimary: accent,
            accentCyan: c.color6 || c.color14 || accent,
            accentGreen: c.color2 || c.color10 || accent,
            accentOrange: c.color3 || c.color11 || accent,
            accentRed: c.color1 || c.color9 || accent
        };
    }

    function normaliseFolderTheme(t) {
        let pal = t.palette;
        if (!pal && t.colors) pal = paletteFromColors(t.colors);
        const out = {
            id: t.id, source: "folder", kind: t.kind, dir: t.dir,
            name: t.name, family: t.family, author: t.author || "",
            backgrounds: t.backgrounds || [], preview: t.preview || "",
            hasPalette: !!pal
        };
        if (pal) Object.assign(out, pal);
        return out;
    }
    onPreviewIndexChanged: {
        if (previewIndex >= 0 && previewIndex < themes.length) {
            applyKittyTheme(themes[previewIndex]);
        } else {
            applyKittyTheme(current);
        }
    }
    // The committed palette, ignoring any preview.
    readonly property var committed: {
        if (wallpaperMode && wallpaperTheme && wallpaperTheme.bgBase)
            return wallpaperTheme;
        if (currentFolderId !== "") {
            const f = folderTheme(currentFolderId);
            if (f && f.hasPalette) return f;
        }
        return themes[currentIndex];
    }
    readonly property var current: {
        if (previewPalette && previewPalette.bgBase)
            return previewPalette;
        if (previewIndex >= 0 && previewIndex < themes.length)
            return themes[previewIndex];
        return committed;
    }
    readonly property int count: themes.length
    readonly property string currentName: current.name
    readonly property string currentFamily: current.family
    readonly property bool isDark: !isLightColor(current.bgBase)

    function isLightColor(hex) {
        hex = hex.toString().replace("#", "");
        var r = parseInt(hex.substr(0, 2), 16);
        var g = parseInt(hex.substr(2, 2), 16);
        var b = parseInt(hex.substr(4, 2), 16);
        return (0.299 * r + 0.587 * g + 0.114 * b) / 255 > 0.5;
    }

    function applySystemColorScheme(dark) {
        colorSchemeProc.command = ["gsettings", "set",
            "org.gnome.desktop.interface", "color-scheme",
            dark ? "prefer-dark" : "prefer-light"];
        colorSchemeProc.running = true;
    }

    // Reactive color properties — same API as before
    readonly property color bgBase:       current.bgBase
    readonly property color bgSurface:    current.bgSurface
    readonly property color bgHover:      current.bgHover
    readonly property color bgSelected:   current.bgSelected
    readonly property color bgBorder:     current.bgBorder
    readonly property color bgOverlay:    "#88000000"

    readonly property color textPrimary:   current.textPrimary
    readonly property color textSecondary: current.textSecondary
    readonly property color textMuted:     current.textMuted

    readonly property color accentPrimary: current.accentPrimary
    readonly property color accentCyan:    current.accentCyan
    readonly property color accentGreen:   current.accentGreen
    readonly property color accentOrange:  current.accentOrange
    readonly property color accentRed:     current.accentRed

    // Semantic aliases
    readonly property color urgencyLow:      textMuted
    readonly property color urgencyNormal:   accentPrimary
    readonly property color urgencyCritical: accentRed
    readonly property color batteryGood:     accentGreen
    readonly property color batteryWarning:  accentOrange
    readonly property color batteryCritical: accentRed

    function hexToRgba(hex) {
        return "rgba(" + hex.toString().replace("#", "") + "ff)";
    }

    // Hyprland 0.57+ uses a Lua config. `aequalyn-theme` renders the wallpaper
    // palette into ~/.config/hypr/aequalyn/colors.lua; a curated theme writes the
    // same file with its own accents, then reloads. Either way the compositor
    // and the shell stay on the same palette.
    function applyHyprlandBorders(t) {
        var activeColor1 = hexToRgba(t.accentPrimary);
        var activeColor2 = hexToRgba(t.accentCyan);
        var inactive = hexToRgba(t.bgBorder);
        var lua = "-- Generated by the Aequalyn theme switcher. Do not edit.\n" +
            "hl.config({\n" +
            "    general = {\n" +
            "        col = {\n" +
            "            active_border = { colors = { \"" + activeColor1 + "\", \"" + activeColor2 + "\" }, angle = 45 },\n" +
            "            inactive_border = \"" + inactive + "\"\n" +
            "        }\n" +
            "    }\n" +
            "})\n";
        hyprlandProc.command = [
            "sh", "-c",
            'mkdir -p "$HOME/.config/hypr/aequalyn" && printf \'%s\' "$1" > "$HOME/.config/hypr/aequalyn/colors.lua" && hyprctl reload >/dev/null 2>&1 || true',
            "sh", lua
        ];
        hyprlandProc.running = true;
    }

    function applyKdeTheme(t) {
        var scheme = [
            "[General]",
            "Name=Quickshell",
            "shadeSortColumn=true",
            "",
            "[Colors:Window]",
            "BackgroundAlternate=" + t.bgSurface,
            "BackgroundNormal=" + t.bgBase,
            "DecorationFocus=" + t.accentPrimary,
            "DecorationHover=" + t.bgHover,
            "ForegroundActive=" + t.accentPrimary,
            "ForegroundInactive=" + t.textMuted,
            "ForegroundLink=" + t.accentCyan,
            "ForegroundNegative=" + t.accentRed,
            "ForegroundNeutral=" + t.accentOrange,
            "ForegroundNormal=" + t.textPrimary,
            "ForegroundPositive=" + t.accentGreen,
            "ForegroundVisited=" + t.accentPrimary,
            "",
            "[Colors:View]",
            "BackgroundAlternate=" + t.bgSurface,
            "BackgroundNormal=" + t.bgBase,
            "DecorationFocus=" + t.accentPrimary,
            "DecorationHover=" + t.bgHover,
            "ForegroundActive=" + t.accentPrimary,
            "ForegroundInactive=" + t.textMuted,
            "ForegroundLink=" + t.accentCyan,
            "ForegroundNegative=" + t.accentRed,
            "ForegroundNeutral=" + t.accentOrange,
            "ForegroundNormal=" + t.textPrimary,
            "ForegroundPositive=" + t.accentGreen,
            "ForegroundVisited=" + t.accentPrimary,
            "",
            "[Colors:Button]",
            "BackgroundAlternate=" + t.bgBase,
            "BackgroundNormal=" + t.bgSurface,
            "DecorationFocus=" + t.accentPrimary,
            "DecorationHover=" + t.bgHover,
            "ForegroundActive=" + t.accentPrimary,
            "ForegroundInactive=" + t.textMuted,
            "ForegroundLink=" + t.accentCyan,
            "ForegroundNegative=" + t.accentRed,
            "ForegroundNeutral=" + t.accentOrange,
            "ForegroundNormal=" + t.textPrimary,
            "ForegroundPositive=" + t.accentGreen,
            "ForegroundVisited=" + t.accentPrimary,
            "",
            "[Colors:Selection]",
            "BackgroundAlternate=" + t.bgSurface,
            "BackgroundNormal=" + t.bgSelected,
            "DecorationFocus=" + t.accentPrimary,
            "DecorationHover=" + t.accentPrimary,
            "ForegroundActive=" + t.textPrimary,
            "ForegroundInactive=" + t.textSecondary,
            "ForegroundLink=" + t.accentCyan,
            "ForegroundNegative=" + t.accentRed,
            "ForegroundNeutral=" + t.accentOrange,
            "ForegroundNormal=" + t.textPrimary,
            "ForegroundPositive=" + t.accentGreen,
            "ForegroundVisited=" + t.textPrimary,
            "",
            "[Colors:Tooltip]",
            "BackgroundAlternate=" + t.bgSurface,
            "BackgroundNormal=" + t.bgSurface,
            "DecorationFocus=" + t.accentPrimary,
            "DecorationHover=" + t.bgHover,
            "ForegroundActive=" + t.accentPrimary,
            "ForegroundInactive=" + t.textMuted,
            "ForegroundLink=" + t.accentCyan,
            "ForegroundNegative=" + t.accentRed,
            "ForegroundNeutral=" + t.accentOrange,
            "ForegroundNormal=" + t.textPrimary,
            "ForegroundPositive=" + t.accentGreen,
            "ForegroundVisited=" + t.accentPrimary,
            "",
            "[Colors:Complementary]",
            "BackgroundAlternate=" + t.bgSurface,
            "BackgroundNormal=" + t.bgSurface,
            "DecorationFocus=" + t.accentPrimary,
            "DecorationHover=" + t.bgHover,
            "ForegroundActive=" + t.accentPrimary,
            "ForegroundInactive=" + t.textMuted,
            "ForegroundLink=" + t.accentCyan,
            "ForegroundNegative=" + t.accentRed,
            "ForegroundNeutral=" + t.accentOrange,
            "ForegroundNormal=" + t.textPrimary,
            "ForegroundPositive=" + t.accentGreen,
            "ForegroundVisited=" + t.accentPrimary
        ].join("\n");

       kdeThemeProc.command = [
            "sh", "-c",
            "mkdir -p \"$HOME/.local/share/color-schemes\" && " +
            "printf '%s\\n' \"$1\" > \"$HOME/.local/share/color-schemes/Quickshell.colors\" && " +

            "kwriteconfig6 --file kdeglobals --group UiSettings --key ColorScheme Quickshell && " +

            "kwriteconfig6 --file kdeglobals --group 'Colors:Window' --key BackgroundAlternate '" + t.bgSurface + "' && " +
            "kwriteconfig6 --file kdeglobals --group 'Colors:Window' --key BackgroundNormal '" + t.bgBase + "' && " +
            "kwriteconfig6 --file kdeglobals --group 'Colors:Window' --key DecorationFocus '" + t.accentPrimary + "' && " +
            "kwriteconfig6 --file kdeglobals --group 'Colors:Window' --key DecorationHover '" + t.bgHover + "' && " +
            "kwriteconfig6 --file kdeglobals --group 'Colors:Window' --key ForegroundActive '" + t.accentPrimary + "' && " +
            "kwriteconfig6 --file kdeglobals --group 'Colors:Window' --key ForegroundInactive '" + t.textMuted + "' && " +
            "kwriteconfig6 --file kdeglobals --group 'Colors:Window' --key ForegroundLink '" + t.accentCyan + "' && " +
            "kwriteconfig6 --file kdeglobals --group 'Colors:Window' --key ForegroundNegative '" + t.accentRed + "' && " +
            "kwriteconfig6 --file kdeglobals --group 'Colors:Window' --key ForegroundNeutral '" + t.accentOrange + "' && " +
            "kwriteconfig6 --file kdeglobals --group 'Colors:Window' --key ForegroundNormal '" + t.textPrimary + "' && " +
            "kwriteconfig6 --file kdeglobals --group 'Colors:Window' --key ForegroundPositive '" + t.accentGreen + "' && " +
            "kwriteconfig6 --file kdeglobals --group 'Colors:Window' --key ForegroundVisited '" + t.accentPrimary + "' && " +

            "kwriteconfig6 --file kdeglobals --group 'Colors:View' --key BackgroundAlternate '" + t.bgSurface + "' && " +
            "kwriteconfig6 --file kdeglobals --group 'Colors:View' --key BackgroundNormal '" + t.bgBase + "' && " +
            "kwriteconfig6 --file kdeglobals --group 'Colors:View' --key DecorationFocus '" + t.accentPrimary + "' && " +
            "kwriteconfig6 --file kdeglobals --group 'Colors:View' --key DecorationHover '" + t.bgHover + "' && " +
            "kwriteconfig6 --file kdeglobals --group 'Colors:View' --key ForegroundActive '" + t.accentPrimary + "' && " +
            "kwriteconfig6 --file kdeglobals --group 'Colors:View' --key ForegroundInactive '" + t.textMuted + "' && " +
            "kwriteconfig6 --file kdeglobals --group 'Colors:View' --key ForegroundLink '" + t.accentCyan + "' && " +
            "kwriteconfig6 --file kdeglobals --group 'Colors:View' --key ForegroundNegative '" + t.accentRed + "' && " +
            "kwriteconfig6 --file kdeglobals --group 'Colors:View' --key ForegroundNeutral '" + t.accentOrange + "' && " +
            "kwriteconfig6 --file kdeglobals --group 'Colors:View' --key ForegroundNormal '" + t.textPrimary + "' && " +
            "kwriteconfig6 --file kdeglobals --group 'Colors:View' --key ForegroundPositive '" + t.accentGreen + "' && " +
            "kwriteconfig6 --file kdeglobals --group 'Colors:View' --key ForegroundVisited '" + t.accentPrimary + "'",

            "sh",
            scheme
        ];

        kdeThemeProc.running = true;
    }

    function applyTerminalPalette(t) {
        paletteProc.command = ["sh", "-c",
            'printf \'%s\' "$1" | aequalyn-apply-palette - >/dev/null 2>&1 || true',
            "sh", JSON.stringify(t)];
        paletteProc.running = true;
    }

    function applyTheme(t) {
        applyKittyTheme(t);
        applyTerminalPalette(t);
        applySystemColorScheme(!isLightColor(t.bgBase));
        applyHyprlandBorders(t);
        if (kdeIntegrationEnabled) applyKdeTheme(t);
        applyNautilusPalette(t);
        applyBrowserTheme(t);
    }

    // Nautilus/libadwaita is not reachable through a GTK theme, so regenerate
    // its palette CSS from this exact palette. Its extension watches the file
    // and reloads it in place; no restart is needed.
    function applyNautilusPalette(t) {
        nautilusProc.command = ["sh", "-c",
            'printf \'%s\' "$1" | aequalyn-nautilus-palette - >/dev/null 2>&1 || true',
            "sh", JSON.stringify(t)];
        nautilusProc.running = true;
    }

    // Keep the browser policy in step with the bar's base colour that was just
    // applied. Called at startup too, so never prompt: the toggle asks once.
    function applyBrowserTheme(t) {
        browserProc.command = ["sh", "-c",
            'aequalyn-browser-theme sync --color "$1" >/dev/null 2>&1 || true',
            "sh", String(t.bgBase || "")];
        browserProc.running = true;
    }

    // Activate a theme: its colours, then (aequalyn-themes set) its first wallpaper,
    // unless one of its own is on already. theme.conf is written first.
    function setFolderTheme(id) {
        const t = folderTheme(id);
        if (!t || !t.hasPalette) return false;
        previewPalette = null;
        previewIndex = -1;
        wallpaperMode = false;
        currentFolderId = id;
        applyTheme(t);
        // its wallpaper too, unless "A theme brings its wallpapers" is off
        const keepWallpaper = AequalynSettings.atelierCfg.themeWallpapers === false;
        folderSetProc.command = ["sh", "-c",
            'printf "%s" "$1" > "$HOME/.config/quickshell/theme.conf" && aequalyn-themes set "$2" --from-shell $3',
            "sh", "theme:" + id, id, keepWallpaper ? "--no-background" : ""];
        folderSetProc.running = true;
        return true;
    }

    // Colours made from the wallpaper from now on, following every change of it.
    function setWallpaperMode() {
        wallpaperMode = true;
        previewPalette = null;
        saveProc.command = ["sh", "-c", 'printf "%s" wallpaper > "$HOME/.config/quickshell/theme.conf"'];
        saveProc.running = true;
        if (wallpaperTheme && wallpaperTheme.bgBase)
            applyTheme(wallpaperTheme);
    }

    // Colours made from a given image, then from the wallpaper. set.sh writes
    // wallpaper-theme.json, which the FileView below live-reloads and applies.
    function setWallpaperFromImage(img) {
        if (img && img.length > 0) {
            generateProc.command = ["sh", Quickshell.env("HOME") + "/.config/quickshell/theme-switcher/wallpaper-theme/set.sh", img];
            generateProc.running = true;
        }
        setWallpaperMode();
    }
    Process { id: generateProc; running: false }

    // IPC / CLI entry: a theme's id.
    function setByKey(key) { return setFolderTheme(key); }

    function applyKittyTheme(t) {
        var colorsConf = [
            "foreground " + t.textPrimary,
            "background " + t.bgBase,
            "cursor " + t.accentPrimary,
            "cursor_text_color " + t.bgBase,
            "selection_foreground " + t.textPrimary,
            "selection_background " + t.bgSelected,
            "active_tab_foreground " + t.textPrimary,
            "active_tab_background " + t.bgSurface,
            "inactive_tab_foreground " + t.textMuted,
            "inactive_tab_background " + t.bgBase,
            "color0 " + t.bgSurface,
            "color1 " + t.accentRed,
            "color2 " + t.accentGreen,
            "color3 " + t.accentOrange,
            "color4 " + t.accentPrimary,
            "color5 " + t.accentPrimary,
            "color6 " + t.accentCyan,
            "color7 " + t.textSecondary,
            "color8 " + t.textMuted,
            "color9 " + t.accentRed,
            "color10 " + t.accentGreen,
            "color11 " + t.accentOrange,
            "color12 " + t.accentPrimary,
            "color13 " + t.accentPrimary,
            "color14 " + t.accentCyan,
            "color15 " + t.textPrimary
        ].join("\n");
        var colorsArgs = [
            "foreground=" + t.textPrimary,
            "background=" + t.bgBase,
            "cursor=" + t.accentPrimary,
            "cursor_text_color=" + t.bgBase,
            "selection_foreground=" + t.textPrimary,
            "selection_background=" + t.bgSelected,
            "active_tab_foreground=" + t.textPrimary,
            "active_tab_background=" + t.bgSurface,
            "inactive_tab_foreground=" + t.textMuted,
            "inactive_tab_background=" + t.bgBase,
            "color0=" + t.bgSurface,
            "color1=" + t.accentRed,
            "color2=" + t.accentGreen,
            "color3=" + t.accentOrange,
            "color4=" + t.accentPrimary,
            "color5=" + t.accentPrimary,
            "color6=" + t.accentCyan,
            "color7=" + t.textSecondary,
            "color8=" + t.textMuted,
            "color9=" + t.accentRed,
            "color10=" + t.accentGreen,
            "color11=" + t.accentOrange,
            "color12=" + t.accentPrimary,
            "color13=" + t.accentPrimary,
            "color14=" + t.accentCyan,
            "color15=" + t.textPrimary
        ].join(" ");
        kittyProc.command = ["sh", "-c",
            "printf '%s\\n' '" + colorsConf + "' > $HOME/.config/kitty/theme-colors.conf; " +
            "for sock in /tmp/kitty-*; do " +
            "[ -S \"$sock\" ] && kitty @ --to \"unix:$sock\" set-colors --all --configured " + colorsArgs + "; " +
            "done"
        ];
        kittyProc.running = true;
    }

    Process { id: saveProc; running: false }
    Process { id: folderSetProc; running: false }
    Process {
        id: folderProc
        running: true
        command: ["sh", "-c", "aequalyn-themes list --json 2>/dev/null || echo '[]'; aequalyn-themes current 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                try {
                    root.folderThemes = JSON.parse(lines[0] || "[]").map(t => root.normaliseFolderTheme(t));
                } catch (e) {
                    console.error("aequalyn-themes list failed:", e);
                    root.folderThemes = [];
                }
                const cur = (lines[1] || "").trim();
                if (cur !== "" && root.folderTheme(cur)) root.currentFolderId = cur;
                root.folderThemesReady = true;
                root.tryLoadTheme();
            }
        }
    }
    Process { id: kittyProc; running: false }
    Process { id: colorSchemeProc; running: false }
    Process { id: hyprlandProc; running: false }
    Process { id: paletteProc; running: false }
    Process { id: nautilusProc; running: false }
    Process { id: browserProc; running: false }
    // KDE addition start
    Process {
        id: kdeThemeProc
        running: false
    }
    // KDE addition end
    // Which hyprland.* is active — hyprland.lua wins exclusively if present, per
    // Hyprland's own startup precedence (see monitor-manager/MonitorService.qml for the twin check).
    Process {
        id: configFormatCheck
        command: ["sh", "-c",
            "[ -f \"$HOME/.config/hypr/hyprland.lua\" ] && echo lua || echo conf"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.configFormat = text.trim() === "lua" ? "lua" : "conf";
                root.configFormatReady = true;
                root.tryLoadTheme();
            }
        }
    }

    Process {
        id: loadProc
        command: ["sh", "-c", "cat $HOME/.config/quickshell/theme.conf 2>/dev/null"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.initialLoadDone = true;
                const raw = text.trim();
                if (raw === "wallpaper") {
                    // colours from the wallpaper; until its palette is read, the
                    // fallback theme's
                    root.wallpaperMode = true;
                    root.applyTheme(root.wallpaperTheme && root.wallpaperTheme.bgBase ? root.wallpaperTheme : root.themes[0]);
                    return;
                }
                const f = raw.startsWith("theme:") ? root.folderTheme(raw.slice(6)) : null;
                if (f && f.hasPalette) {
                    root.currentFolderId = f.id;
                    root.applyTheme(f);
                    // the link the wallpaper rotation reads (a fresh install has none yet)
                    saveProc.command = ["sh", "-c", 'mkdir -p "$HOME/.config/aequalyn/current" && ln -sfn "$1" "$HOME/.config/aequalyn/current/theme"', "sh", f.dir];
                    saveProc.running = true;
                    return;
                }
                // A palette without wallpapers (no longer shipped) or a theme that's
                // gone: move to a theme with its own wallpapers, keeping the wallpaper
                // that's on now.
                root.adoptDefaultTheme();
            }
        }
    }

    // The theme to fall back on: Basalt, else the first with colours and wallpapers.
    function defaultThemeId() {
        const ok = folderThemes.filter(t => t.hasPalette && (t.backgrounds || []).length > 0);
        const basalt = ok.find(t => t.id === "basalt");
        return basalt ? basalt.id : (ok.length ? ok[0].id : "");
    }
    function adoptDefaultTheme() { useThemeColours(defaultThemeId()); }
    // A theme's colours (the current one's, else the default's), leaving the wallpaper as
    // it is: going back from wallpaper colours to a theme's.
    function useThemeColours(id) {
        let f = id ? folderTheme(id) : null;
        if (!f || !f.hasPalette) f = folderTheme(defaultThemeId());
        if (!f) { applyTheme(themes[0]); return; }
        wallpaperMode = false;
        previewPalette = null;
        currentFolderId = f.id;
        applyTheme(f);
        saveProc.command = ["sh", "-c",
            'mkdir -p "$HOME/.config/aequalyn/current" "$HOME/.config/quickshell" '
            + '&& printf "%s" "theme:$1" > "$HOME/.config/quickshell/theme.conf" '
            + '&& ln -sfn "$2" "$HOME/.config/aequalyn/current/theme"',
            "sh", f.id, f.dir];
        saveProc.running = true;
    }

    // Live-reloads the palette made from the wallpaper: while colours follow the
    // wallpaper, a new wallpaper (and a fresh wallpaper-theme.json) repaints the shell.
    FileView {
        id: wallpaperThemeFile
        path: Quickshell.env("HOME") + "/.config/quickshell/theme-switcher/wallpaper-theme.json"
        watchChanges: true
        onFileChanged: reload()
        onTextChanged: {
            const raw = wallpaperThemeFile.text();
            if (!raw) return;
            try {
                root.wallpaperTheme = JSON.parse(raw);
                if (root.wallpaperMode && root.wallpaperTheme.bgBase)
                    root.applyTheme(root.wallpaperTheme);
            } catch (e) {
                console.error("Failed to parse wallpaper-theme.json:", e);
            }
        }
    }

    // Only until a theme is applied, or if none is installed at all.
    property var themes: [
        {
            name: "Night", family: "Tokyo Night",
            bgBase: "#1a1b26", bgSurface: "#24283b", bgHover: "#1e2235",
            bgSelected: "#283457", bgBorder: "#32364a",
            textPrimary: "#c0caf5", textSecondary: "#a9b1d6", textMuted: "#565f89",
            accentPrimary: "#7aa2f7", accentCyan: "#7dcfff",
            accentGreen: "#9ece6a", accentOrange: "#ff9e64", accentRed: "#f7768e"
        }
    ]
}
