// Clipscape's quick panel: the last things you copied (a click copies one again),
// recording on or paused, the whole picker, and clearing what isn't pinned (it asks
// twice); last, the Clipboard page.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/plugins/bar/quick"
import "root:/plugins/clipscape"
import "root:/plugins/clipscape/qml/js/Clips.js" as Clips

QuickPopup {
    id: q
    required property var bar
    readonly property var svc: ClipscapeService
    readonly property var recent: svc ? svc.clips.clips.slice(0, 6) : []
    property bool armed: false
    Timer { id: disarm; interval: 4000; onTriggered: q.armed = false }
    onVisibleChanged: if (!visible) q.armed = false

    function glyphOf(c) {
        const k = Clips.kindOf(c);
        return ({ image: "\u{F021F}", link: "\u{F0337}", files: "\u{F0214}", color: "\u{F0266}", code: "\u{F0169}" })[k] || "\u{F014C}";
    }

    glyph: "\u{F014C}"
    title: "Clipboard"
    sub: !svc ? "" : (svc.paused ? "Paused · " : "Recording · ") + svc.count + (svc.count === 1 ? " clip" : " clips")
    settingsLabel: "Clipboard settings"
    onSettingsClicked: { q.dismissed(); q.bar.openPage("clipboard") }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        QuickTile {
            glyph: q.svc && q.svc.paused ? "\u{F03E4}" : "\u{F044A}"
            title: q.svc && q.svc.paused ? "Paused" : "Recording"
            sub: q.svc && q.svc.paused ? "Copies aren't kept" : "Every copy is kept"
            on: !!q.svc && !q.svc.paused
            onToggled: q.svc.togglePaused()
        }
        QuickTile {
            glyph: "\u{F0349}"; title: "Search all"
            sub: "Super + Ctrl + V"
            onToggled: { q.dismissed(); q.svc.openPicker("") }
        }
    }

    QuickLabel { visible: q.recent.length > 0; text: "Copied last · a click copies it again" }
    Repeater {
        model: q.recent
        delegate: QuickTile {
            required property var modelData
            glyph: q.glyphOf(modelData)
            title: modelData.secret ? "••••••" : Clips.title(modelData, true)
            sub: (modelData.pinned ? "Pinned · " : "") + Clips.kindOf(modelData)
            onToggled: { q.svc.clips.use(modelData.id, "copy"); q.dismissed() }
        }
    }
    Text {
        visible: q.recent.length === 0
        Layout.fillWidth: true
        text: "Nothing copied yet."
        color: Quick.theme.textMuted
        font.family: Quick.mono
        font.pixelSize: 11
    }
    QuickWide {
        visible: q.recent.length > 0
        glyph: "\u{F0A7A}"
        label: q.armed ? "Click again to clear (pinned stay)" : "Clear the history"
        on: q.armed
        onClicked: {
            if (!q.armed) { q.armed = true; disarm.restart(); return }
            q.armed = false;
            q.svc.clips.clearUnpinned();
        }
    }
}
