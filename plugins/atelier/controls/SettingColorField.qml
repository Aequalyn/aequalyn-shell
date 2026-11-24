// "Label" above a framed hex field: the same text row Clipboard uses for colours.
import QtQuick
import QtQuick.Layouts
import "root:/settings"

ColumnLayout {
    id: field
    property var theme
    property string font: AequalynSettings.monoFont
    property string label: ""
    property string value: ""
    signal picked(string value)

    function tint(a) {
        return theme ? Qt.rgba(theme.textPrimary.r, theme.textPrimary.g, theme.textPrimary.b, a) : "transparent";
    }
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

    Layout.fillWidth: true
    spacing: 6

    Text {
        visible: field.label !== ""
        text: field.label
        color: field.theme ? field.theme.textSecondary : "white"
        font.family: AequalynSettings.uiFont
        font.pixelSize: 12
        Layout.fillWidth: true
        elide: Text.ElideRight
    }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 34
        radius: 6
        color: field.tint(0.05)
        border.width: 1
        border.color: input.activeFocus ? field.tint(0.28) : field.tint(0.08)
        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            verticalAlignment: TextInput.AlignVCenter
            text: field.value
            color: field.theme ? field.theme.textPrimary : "white"
            font.family: field.font
            font.pixelSize: 12
            maximumLength: 7
            selectByMouse: true
            activeFocusOnTab: true
            onAccepted: field.commit()
            onEditingFinished: field.commit()
            Keys.onEscapePressed: { input.text = field.value; input.focus = false; }
        }
    }
    Text {
        text: "hex, like #ff6a1f"
        color: field.theme ? field.theme.textMuted : "white"
        opacity: 0.45
        font.family: AequalynSettings.uiFont
        font.pixelSize: 10
    }
    Connections {
        target: field
        function onValueChanged() { if (!input.activeFocus) input.text = field.value; }
    }
}
