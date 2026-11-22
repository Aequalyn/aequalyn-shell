// "Label" above a full-width row of joined buttons: one choice out of a few.
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: row
    property var theme
    property string font: "JetBrainsMono Nerd Font"
    property string label: ""
    property var options: []        // values
    property var labels: ({})       // value -> label (else the value itself)
    property var value
    signal picked(var value)

    Layout.fillWidth: true
    spacing: 6
    opacity: enabled ? 1 : 0.45

    Text {
        visible: row.label !== ""
        text: row.label
        color: row.theme ? row.theme.textSecondary : "white"
        font.family: "sans-serif"
        font.pixelSize: 12
        Layout.fillWidth: true
        elide: Text.ElideRight
    }
    ChoiceTrack {
        theme: row.theme
        font: row.font
        options: row.options
        labels: row.labels
        value: row.value
        onPicked: v => row.picked(v)
    }
}
