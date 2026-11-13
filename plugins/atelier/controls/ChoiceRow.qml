// "Label   (a) (b) (c)": one choice out of a few, as chips that wrap.
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: row
    property var theme
    property string font: "JetBrainsMono Nerd Font"
    property string label: ""
    property var options: []        // values
    property var labels: ({})       // value -> label (else the value itself)
    property var value
    property bool enabled: true
    signal picked(var value)

    Layout.fillWidth: true
    spacing: 10
    opacity: enabled ? 1 : 0.45

    Text {
        text: row.label
        color: row.theme.textSecondary
        font.family: row.font
        font.pixelSize: 11
        Layout.preferredWidth: 96
        Layout.alignment: Qt.AlignTop
        Layout.topMargin: 5
        elide: Text.ElideRight
    }
    Flow {
        Layout.fillWidth: true
        spacing: 6
        Repeater {
            model: row.options
            delegate: Chip {
                required property var modelData
                theme: row.theme
                font: row.font
                compact: true
                text: row.labels[modelData] !== undefined ? row.labels[modelData] : String(modelData)
                selected: row.value === modelData
                onClicked: if (row.enabled) row.picked(modelData)
            }
        }
    }
}
