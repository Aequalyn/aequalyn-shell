// What follows what. A plugin that follows the desktop (Showcase's cards, the cursor)
// reads the theme's colors, or the look and colors of the bar or of a dock, here; and
// with one look everywhere on (AequalynSettings.matchCfg), everything that joins reads the
// look of the one that leads. Nothing is kept here: it is all read from where it is set,
// so a change shows at once, and turning it off brings everyone's own look back.
pragma Singleton

import QtQuick
import Quickshell
import "root:/settings"
import "root:/plugins/atelier"
import "root:/plugins/plume"
import "root:/theme-switcher" as AeqTheme
import "root:/style/Colors.js" as Colors
import "root:/style/BarLooks.js" as BarLooks
import "root:/style/Follow.js" as Follow

Singleton {
    id: root

    // each one's own settings
    readonly property var ownBar: BarLooks.clean(AequalynSettings.barStyleCfg)
    readonly property var docks: AtelierHost.docks && AtelierHost.docks.enabled ? AtelierHost.docks : null
    readonly property var showcase: KitHost.get("showcase")
    readonly property var plume: PlumeHost.svc
    readonly property string edge: AequalynSettings.barPosition

    // each color read here, so a theme change is seen at once
    readonly property var theme: ({
        bgBase: AeqTheme.Theme.bgBase, textPrimary: AeqTheme.Theme.textPrimary,
        accentPrimary: AeqTheme.Theme.accentPrimary, accentCyan: AeqTheme.Theme.accentCyan,
        accentGreen: AeqTheme.Theme.accentGreen, accentOrange: AeqTheme.Theme.accentOrange,
        accentRed: AeqTheme.Theme.accentRed, borderColors: AeqTheme.Theme.borderColors
    })
    readonly property var themeColors: Object.assign({}, Colors.fromTheme(root.theme), { mode: "theme" })
    function colorsOf(c, mode) { return Object.assign({ borders: [] }, Colors.forMode(root.theme, mode, c), { mode: mode }) }

    // ---- one look everywhere ------------------------------------------------------------
    readonly property var match: AequalynSettings.matchCfg
    readonly property string lead: !root.match.on ? "" : (root.match.lead === "last" ? root.match.now : root.match.lead)
    readonly property int leadDock: root.docks ? Math.min(root.match.nowDock, root.docks.docks.length - 1) : -1
    readonly property var dockOwn: root.leadDock >= 0 && !root.docks.docks[root.leadDock].followBar ? root.docks.docks[root.leadDock] : null

    readonly property var ownBarSource: Follow.source(root.ownBar, root.edge, root.ownBar.colorMode)
    // the look everyone takes: the one leading, or the bar's when that one is off or bare
    readonly property var leadSource: {
        if (root.lead === "dock" && root.dockOwn) return Follow.source(root.dockOwn, root.dockOwn.edge, root.dockOwn.style)
        if (root.lead === "showcase" && root.showcase) return Follow.fromCard(root.showcase.cfg, root.edge) || root.ownBarSource
        if (root.lead === "cursor" && root.plume) return Follow.fromCursor(root.plume.cfg, root.edge)
        return root.ownBarSource
    }
    // its colors; a cursor has none of its own a bar could have: the theme's
    readonly property var leadColorCfg: {
        const of = (c, mode) => ({ mode: mode, customBg: c.customBg, customFg: c.customFg, accentColor: c.accentColor })
        if (root.lead === "dock" && root.dockOwn) return of(root.dockOwn, root.leadSource.mode)
        if (root.lead === "showcase" && root.showcase) return of(root.showcase.cfg, root.showcase.cfg.colorMode)
        if (root.lead === "cursor" && root.plume) return of(root.ownBar, "theme")
        return of(root.ownBar, root.ownBar.colorMode)
    }
    readonly property var leadColors: root.colorsOf(root.leadColorCfg, root.leadColorCfg.mode)

    function joins(what) { return root.match.on && root.match[what] === true && root.lead !== what }
    readonly property var matchColors: root.match.colors ? root.leadColorCfg : null
    readonly property var barOver: root.joins("bar") ? Follow.bar(root.leadSource, root.matchColors) : null
    Binding { target: AequalynSettings; property: "barStyleOver"; value: root.barOver }
    readonly property var dockLook: root.match.on && root.match.dock ? Follow.dock(root.leadSource, root.matchColors) : null
    // what dock i wears over its own settings, or null
    function dockOver(i) { return !root.dockLook || (root.lead === "dock" && i === root.leadDock) ? null : root.dockLook }

    // ---- following by hand -----------------------------------------------------------------
    // the bar as it is drawn, and the first dock as it is drawn (the bar when there is none)
    readonly property var bar: BarLooks.clean(AequalynSettings.barStyleWorn)
    readonly property var dock: root.docks && root.docks.docks.length > 0 ? root.docks.effective(0) : null
    readonly property var barSource: Follow.source(root.bar, root.edge, root.bar.colorMode)
    readonly property var dockSource: root.dock ? Follow.source(root.dock, root.dock.edge, root.dock.style) : root.barSource
    readonly property var barColors: root.colorsOf(root.bar, root.bar.colorMode)
    readonly property var dockColors: root.dock
        ? Object.assign({ borders: [] }, root.docks.palette(root.dock), { mode: root.dockSource.mode }) : root.barColors

    // the look for `what` ("showcase" or "cursor") set to follow `which` ("own" | "bar" |
    // "dock"): a source (style/Follow.js), or null for its own
    function source(what, which) {
        if (root.joins(what)) return root.leadSource
        return which === "bar" ? root.barSource : (which === "dock" ? root.dockSource : null)
    }
    // the colors, for "own" | "theme" | "bar" | "dock": { bg, fg, ac, hot, spectrum, borders,
    // mode }, or null for its own
    function colors(what, which) {
        if (root.joins(what) && root.match.colors) return root.leadColors
        return which === "theme" ? root.themeColors : (which === "bar" ? root.barColors : (which === "dock" ? root.dockColors : null))
    }
    // one look everywhere leaves `what` to wear another's: who, in words, or ""
    readonly property var leadNames: ({ bar: "the bar", dock: "the dock", showcase: "Showcase", cursor: "the cursor" })
    function ledBy(what) { return root.joins(what) ? root.leadNames[root.lead] : "" }
}
