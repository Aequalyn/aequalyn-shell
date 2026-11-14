// A question and what answers it: a short title, an optional hint, then the controls.
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: sec
    property string title: ""
    property string hint: ""
    default property alias content: body.data

    Layout.fillWidth: true
    spacing: 10

    Text {
        visible: sec.title !== ""
        text: sec.title
        color: Cc.theme.textSecondary
        font.family: Cc.sans
        font.pixelSize: 13
        font.weight: Font.DemiBold
        Layout.fillWidth: true
    }
    Text {
        visible: sec.hint !== ""
        text: sec.hint
        color: Cc.theme.textMuted
        font.family: Cc.sans
        font.pixelSize: 12
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
        Layout.topMargin: -6
    }
    ColumnLayout {
        id: body
        Layout.fillWidth: true
        spacing: 8
    }
}
