// A line of quiet explanation under a section, at the small hint size.
import QtQuick
import QtQuick.Layouts

Text {
    id: note
    color: Cc.theme.textMuted
    opacity: 0.55
    font.family: Cc.sans
    font.pixelSize: 10
    wrapMode: Text.WordWrap
    Layout.fillWidth: true
    // in a section's group: room of its own beside the rows
    readonly property bool grouped: Cc.inGroup(note)
    readonly property bool roomy: Cc.inGroupBody(note)
    Layout.leftMargin: roomy ? 10 : 0
    Layout.rightMargin: roomy ? 10 : 0
    Layout.topMargin: roomy ? 6 : 0
    Layout.bottomMargin: roomy ? 6 : 0
}
