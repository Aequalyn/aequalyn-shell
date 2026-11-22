// "Label   #rrggbb": a typed colour, next to the swatches above it.
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: field
    property var theme
    property string font: "JetBrainsMono Nerd Font"
    property string label: ""
    property string value: ""
    signal picked(string value)

    Layout.fillWidth: true
    spacing: 10

    function commit() {
        let v = input.text.trim().toLowerCase();
        if (/^#[0-9a-f]{3}$/.test(v))
            v = "#" + v[1] + v[1] + v[2] + v[2] + v[3] + v[3];
        if (/^#[0-9a-f]{6}$/.test(v)) {
            input.text = v;
            field.picked(v);
        } else {
            input.text = field.value;
        }
    }

    Text {
        text: field.label
        color: field.theme.textSecondary
        font.family: "sans-serif"
        font.pixelSize: 12
        Layout.preferredWidth: 96
    }
    Rectangle {
        Layout.preferredWidth: 104
        Layout.preferredHeight: 28
        radius: 8
        color: field.theme.bgSurface
        border.width: 1
        border.color: input.activeFocus ? field.theme.accentPrimary : field.theme.bgBorder
        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            verticalAlignment: TextInput.AlignVCenter
            text: field.value
            color: field.theme.textPrimary
            font.family: field.font
            font.pixelSize: 12
            maximumLength: 7
            selectByMouse: true
            activeFocusOnTab: true
            onAccepted: field.commit()
            onEditingFinished: field.commit()
        }
    }
    Connections {
        target: field
        function onValueChanged() { if (!input.activeFocus) input.text = field.value; }
    }
}
