// One palette row like Clipboard's: target tabs, a shared swatch grid, a preview
// and a validated hex field. `targets` are { key, label, value } objects.
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: pal
    property var theme
    property string font: "JetBrainsMono Nerd Font"
    property string label: "Colors"
    property var swatches: []
    property var targets: []
    property int target: 0
    signal picked(string key, string value)

    function tint(a) {
        return theme ? Qt.rgba(theme.textPrimary.r, theme.textPrimary.g, theme.textPrimary.b, a) : "transparent";
    }
    function labelMap() {
        const map = {};
        for (let i = 0; i < targets.length; i++) map[targets[i].key] = targets[i].label;
        return map;
    }
    function currentKey() {
        return targets.length > target ? targets[target].key : "";
    }
    function currentValue() {
        return targets.length > target ? String(targets[target].value || "") : "";
    }

    readonly property var keys: {
        const list = [];
        for (let i = 0; i < targets.length; i++) list.push(targets[i].key);
        return list;
    }
    readonly property var shown: {
        const from = target * 8;
        return swatches.slice(from, from + 8);
    }

    Layout.fillWidth: true
    spacing: 8

    Text {
        visible: pal.label !== ""
        text: pal.label
        color: pal.theme ? pal.theme.textPrimary : "white"
        font.family: "sans-serif"
        font.pixelSize: 13
        font.weight: Font.DemiBold
        Layout.fillWidth: true
    }
    ChoiceTrack {
        theme: pal.theme
        font: pal.font
        options: pal.keys
        labels: pal.labelMap()
        value: pal.currentKey()
        onPicked: k => pal.target = pal.keys.indexOf(k)
    }
    GridLayout {
        Layout.fillWidth: true
        columns: 8
        columnSpacing: 10
        rowSpacing: 10

        Repeater {
            model: pal.shown
            delegate: Rectangle {
                required property string modelData
                readonly property bool on: String(pal.currentValue()).toLowerCase() === modelData.toLowerCase()
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: 14
                color: modelData
                border.width: on ? 2 : 1
                border.color: on ? (pal.theme ? pal.theme.textPrimary : "white") : pal.tint(0.25)
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pal.picked(pal.currentKey(), modelData)
                }
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Rectangle {
            Layout.preferredWidth: 34
            Layout.preferredHeight: 34
            radius: 6
            color: pal.currentValue() === "" ? "transparent" : pal.currentValue()
            border.width: 1
            border.color: pal.tint(0.16)
        }
        SettingColorField {
            Layout.fillWidth: true
            theme: pal.theme
            font: pal.font
            label: "Hex"
            value: pal.currentValue()
            onPicked: v => pal.picked(pal.currentKey(), v)
        }
    }
}
