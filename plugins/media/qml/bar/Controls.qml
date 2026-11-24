import QtQuick
import "root:/settings"

Row {
    id: root

    property var bar: null
    property var service: null
    property bool showPrevious: true
    property bool showPlayPause: true
    property bool showNext: true

    spacing: (3)

    readonly property bool playing: service ? service.playing : false
    readonly property var player: service ? service.player : null

    // Tooltips are shown/hidden here so a click always dismisses them.
    function tip(item, on, text) {
        if (!bar) return
        if (on) bar.showTooltip(item, text)
        else bar.hideTooltip(item)
    }

    function can(action) {
        if (!player) return false
        if (action === "previous") return !!player.canGoPrevious
        if (action === "next") return !!player.canGoNext
        return !!(player.canTogglePlaying || player.canPlay || player.canPause)
    }

    IconButton {
        id: prevBtn
        visible: root.showPrevious
        enabled: root.can("previous")
        opacity: enabled ? 1 : 0.35
        iconText: "\uDB81\uDCAE"
        foreground: root.bar ? root.bar.theme.textPrimary : "#e0e0e0"
        fontFamily: root.bar ? root.bar.font : AequalynSettings.monoFont
        iconSize: 12
        horizontalPadding: (3)
        verticalPadding: (2)
        HoverHandler { onHoveredChanged: root.tip(prevBtn, hovered, "Previous") }
        onClicked: {
            root.tip(prevBtn, false, "")
            if (root.service) root.service.runAction("previous")
        }
    }

    IconButton {
        id: playBtn
        visible: root.showPlayPause
        enabled: root.can("playPause")
        opacity: enabled ? 1 : 0.35
        iconText: root.playing ? "\uDB80\uDFE4" : "\uDB81\uDC0A"
        foreground: root.bar ? root.bar.theme.textPrimary : "#e0e0e0"
        fontFamily: root.bar ? root.bar.font : AequalynSettings.monoFont
        iconSize: 12
        horizontalPadding: (4)
        verticalPadding: (2)
        HoverHandler { onHoveredChanged: root.tip(playBtn, hovered, root.playing ? "Pause" : "Play") }
        onClicked: {
            root.tip(playBtn, false, "")
            if (root.service) root.service.runAction("playPause")
        }
    }

    IconButton {
        id: nextBtn
        visible: root.showNext
        enabled: root.can("next")
        opacity: enabled ? 1 : 0.35
        iconText: "\uDB81\uDCAD"
        foreground: root.bar ? root.bar.theme.textPrimary : "#e0e0e0"
        fontFamily: root.bar ? root.bar.font : AequalynSettings.monoFont
        iconSize: 12
        horizontalPadding: (3)
        verticalPadding: (2)
        HoverHandler { onHoveredChanged: root.tip(nextBtn, hovered, "Next") }
        onClicked: {
            root.tip(nextBtn, false, "")
            if (root.service) root.service.runAction("next")
        }
    }
}
