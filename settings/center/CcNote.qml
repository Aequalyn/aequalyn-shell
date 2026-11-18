// A line of quiet explanation under a section.
import QtQuick
import QtQuick.Layouts

Text {
    id: note
    color: Cc.theme.textMuted
    font.family: Cc.sans
    font.pixelSize: 11
    wrapMode: Text.WordWrap
    Layout.fillWidth: true
    // in a section's group: room of its own beside the rows
    readonly property bool grouped: Cc.inGroup(note)
    readonly property bool roomy: Cc.inGroupBody(note)
    Layout.leftMargin: roomy ? 14 : 0
    Layout.rightMargin: roomy ? 14 : 0
    Layout.topMargin: roomy ? 8 : 0
    Layout.bottomMargin: roomy ? 8 : 0
}
