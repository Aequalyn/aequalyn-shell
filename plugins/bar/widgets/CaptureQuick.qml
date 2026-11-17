// Capture's quick panel (the screenshot and recording widgets): a picture of a part of
// the screen or all of it, copied or only saved, and recording on or off; last, where
// they are kept.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/plugins/bar/quick"

QuickPopup {
    id: q
    required property var bar
    // the panel closes first, so it isn't in the picture
    function shot(mode) { q.dismissed(); Quickshell.execDetached(["sh", "-c", "sleep 0.3; exec aequalyn-screenshot " + mode]) }

    glyph: "\u{F0100}"
    title: "Capture"
    sub: q.bar.recordingActive ? "Recording the screen" : "Screenshots and recordings"
    settingsLabel: "Open the Screenshots folder"
    onSettingsClicked: { q.dismissed(); Quickshell.execDetached(["sh", "-c", 'mkdir -p "$HOME/Pictures/Screenshots" && xdg-open "$HOME/Pictures/Screenshots"']) }

    QuickLabel { text: "Screenshot" }
    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: 8
        rowSpacing: 8
        QuickTile { glyph: "\u{F0A6B}"; title: "A part"; sub: "Saved and copied"; onToggled: q.shot("region-clip") }
        QuickTile { glyph: "\u{F0379}"; title: "The whole screen"; sub: "Saved and copied"; onToggled: q.shot("full-clip") }
        QuickTile { glyph: "\u{F0A6B}"; title: "A part, saved"; sub: "Not copied"; onToggled: q.shot("region-file") }
        QuickTile { glyph: "\u{F0379}"; title: "The screen, saved"; sub: "Not copied"; onToggled: q.shot("full-file") }
    }
    QuickLabel { text: "Recording" }
    QuickTile {
        glyph: q.bar.recordingActive ? "\u{F04DB}" : "\u{F044A}"
        title: q.bar.recordingActive ? "Stop recording" : "Record the screen"
        sub: q.bar.recordingActive ? "Saved to Videos when it stops" : "To Videos, until you stop it"
        on: q.bar.recordingActive
        onToggled: { q.dismissed(); q.bar.toggleRecording() }
    }
    QuickWide {
        glyph: "\u{F0FCE}"; label: "Open the Videos folder"
        onClicked: { q.dismissed(); Quickshell.execDetached(["sh", "-c", 'xdg-open "$HOME/Videos"']) }
    }
}
