import QtQuick
import Quickshell
import "root:/theme-switcher" as Aeq
import "root:/settings"

pragma Singleton

Singleton {
    id: root

    readonly property var t: Aeq.Theme
    readonly property bool isDark: t.isDark
    readonly property bool isLight: !t.isDark

    readonly property color bg: t.bgBase
    readonly property color bgOpaque: t.bgBase
    readonly property color bgHigh: t.bgSurface
    readonly property color bgSunken: t.bgBase
    readonly property color surfaceLow: t.bgBase
    readonly property color surfaceHigh: t.bgSurface
    readonly property color surfaceHighest: t.bgHover
    readonly property color scrim: t.bgOverlay
    readonly property color outline: t.bgBorder
    readonly property color outlineStrong: t.bgBorder
    readonly property color divider: t.bgBorder

    readonly property color text: t.textPrimary
    readonly property color subtext: t.textSecondary
    readonly property color subtextDim: t.textMuted

    readonly property color accent: t.accentPrimary
    readonly property color primary: t.accentPrimary
    readonly property color error: t.accentRed
    readonly property color accentContainer: Qt.rgba(t.accentPrimary.r, t.accentPrimary.g, t.accentPrimary.b, 0.18)
    readonly property color primaryContainer: Qt.rgba(t.accentPrimary.r, t.accentPrimary.g, t.accentPrimary.b, 0.18)
    readonly property color secondaryContainer: t.bgHover
    readonly property color secondary: t.accentCyan
    readonly property color errorContainer: t.bgHover
    readonly property color inverseSurface: t.textPrimary
    readonly property color fgAccent: t.bgBase
    readonly property color fgAccentContainer: t.accentPrimary
    readonly property color fgSecondaryContainer: t.textPrimary
    readonly property color fgPrimary: t.bgBase
    readonly property color fgPrimaryContainer: t.accentPrimary
    readonly property color fgSecondary: t.textSecondary
    readonly property color fgInverseSurface: t.bgBase
    readonly property color fgError: t.bgBase
    readonly property color fgErrorContainer: t.accentRed
    readonly property color stateHover: t.bgHover
    readonly property color statePressed: t.bgSelected
    // tonal buttons rest on it, segmented groups idle on it, progress tracks run on it
    readonly property color bgSelected: t.bgSelected
    readonly property color disabledContainer: Qt.rgba(t.textPrimary.r, t.textPrimary.g, t.textPrimary.b, 0.12)
    readonly property color disabledContent: Qt.rgba(t.textPrimary.r, t.textPrimary.g, t.textPrimary.b, 0.38)

    readonly property real uiScale: 1
    readonly property real motionScale: 1

    readonly property int radiusXs: 10
    readonly property int radiusSm: 10
    readonly property int radiusMd: 10
    readonly property int shapeLg: 10
    readonly property int shapeXl: 12
    readonly property string fontFamily: AequalynSettings.uiFont
    readonly property int fontBody: 13
    readonly property int fontLabel: 11
    readonly property int fontTitle: 14

    readonly property int durQuick: 120
    readonly property int durShort: 140
    readonly property int durMedium: 180
    readonly property int durFastSpatial: 160
    readonly property int durDefaultSpatial: 200
    readonly property int durFastEffects: 120
    readonly property int durDefaultEffects: 120
    readonly property int durSlowEffects: 200
    readonly property var curveStandard: [0.05, 0.7, 0.1, 1, 1, 1]
    readonly property var curveEffects: [0.31, 0.94, 0.34, 1, 1, 1]
    readonly property var curveFastSpatial: [0.42, 1.67, 0.21, 0.9, 1, 1]
    readonly property var curveDefaultSpatial: [0.38, 1.21, 0.22, 1, 1, 1]
    readonly property var easeEmphasizedDecel: [0.05, 0.7, 0.1, 1, 1, 1]
    readonly property var easeEmphasizedAccel: [0.3, 0, 0.8, 0.15, 1, 1]

    readonly property real jelly: 0

    function dp(px) { return Math.round(px) }
    function ms(d) { return Math.round(d) }
    function rad(px) { return Math.min(10, Math.round(px)) }
    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    function withBlur(c) { return c }
    function axes(px, wght, rond) { return ({}) }
    function mix(a, b, k) { return a }
    function light(c) { return 0.5 }
    function on(c) { return root.light(c) > 0.55 ? "#181b1c" : "#ffffff" }
    function atTone(c, tone) { return c }
    function typeSize(role) {
        if (role.indexOf("display") === 0) return 24
        if (role.indexOf("headline") === 0) return 16
        if (role.indexOf("title") === 0) return 14
        if (role.indexOf("label") === 0) return 11
        return 13
    }
    function typeWeight(role) {
        if (role.indexOf("label") === 0 || role.indexOf("title") === 0) return 600
        if (role.indexOf("headline") === 0 || role.indexOf("display") === 0) return 600
        return 400
    }
    function typeRound(role) { return 0 }
    function pill(size) { return 10 }
}
