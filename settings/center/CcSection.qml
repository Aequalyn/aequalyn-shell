// A question and what answers it: a short title, an optional hint, then the settings.
// The settings that are rows (switches, amounts, items) sit together in one rounded
// group with a hairline between them, as every page shows them; a section holding no
// rows (a gallery, a row of choices) shows its content as it is, without the group.
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
    spacing: 8

    Text {
        visible: sec.title !== ""
        text: sec.title
        color: Cc.theme.textSecondary
        font.family: Cc.sans
        font.pixelSize: 13
        font.weight: Font.DemiBold
        Layout.fillWidth: true
        Layout.leftMargin: 2
    }
    Text {
        visible: sec.hint !== ""
        text: sec.hint
        color: Cc.theme.textMuted
        font.family: Cc.sans
        font.pixelSize: 12
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
        radius: 12
        color: sec.boxed ? Cc.theme.bgSurface : "transparent"
        border.width: sec.boxed ? 1 : 0
        border.color: Cc.theme.bgBorder
        ColumnLayout {
            id: body
            x: sec.boxed ? 4 : 0
            y: sec.boxed ? 4 : 0
            width: box.width - (sec.boxed ? 8 : 0)
            // rows sit flush with a hairline between them; anything else keeps its room
            spacing: sec.boxed ? 0 : 8
        }
    }
}
