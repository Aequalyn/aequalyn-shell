// A question and what answers it: a short title, an optional hint, then the settings.
// Rows sit together in one quiet framed group with hairlines between them; a section
// holding no rows (a gallery, a row of choices) shows its content as it is, without
// the group. Previews are never framed here.
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: sec
    property string title: ""
    property string hint: ""
    default property alias content: body.data

    // rows find their section through this (Cc.sectionOf), and count themselves in
    readonly property bool ccSection: true
    property int rows: 0
    readonly property bool boxed: rows > 0

    Layout.fillWidth: true
    spacing: 6

    Text {
        visible: sec.title !== ""
        text: sec.title.toUpperCase()
        color: Cc.theme.textSecondary
        font.family: Cc.sans
        font.pixelSize: 9
        font.weight: Font.DemiBold
        font.letterSpacing: 1
        opacity: 0.45
        Layout.fillWidth: true
        Layout.leftMargin: 2
        Layout.topMargin: 6
    }
    Text {
        visible: sec.hint !== ""
        text: sec.hint
        color: Cc.theme.textMuted
        font.family: Cc.sans
        font.pixelSize: 10
        opacity: 0.55
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
        Layout.leftMargin: 2
        Layout.topMargin: -4
    }
    // the group: a quiet box around the rows
    Rectangle {
        id: box
        Layout.fillWidth: true
        Layout.topMargin: 2
        implicitHeight: body.implicitHeight + (sec.boxed ? 8 : 0)
        radius: 6
        color: sec.boxed ? Cc.alpha(Cc.theme.textPrimary, 0.03) : "transparent"
        border.width: sec.boxed ? 1 : 0
        border.color: Cc.alpha(Cc.theme.textPrimary, 0.08)
        ColumnLayout {
            id: body
            x: sec.boxed ? 4 : 0
            y: sec.boxed ? 4 : 0
            width: box.width - (sec.boxed ? 8 : 0)
            // rows sit flush with a hairline between them; anything else keeps its room
            spacing: sec.boxed ? 0 : 6
        }
    }
}
