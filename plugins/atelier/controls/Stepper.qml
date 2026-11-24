// "Label   ‹ value ›" with bounds; used for hours and durations.
import QtQuick
import QtQuick.Layouts
import "root:/settings"

RowLayout {
    id: stepper
    property var theme
    property string font: AequalynSettings.monoFont
    property string label: ""
    property real value: 0
    property real from: 0
    property real to: 23
    property real step: 1
    property string suffix: ""
    signal stepped(real value)

    spacing: 8

    Text {
        text: stepper.label
        color: stepper.theme.textSecondary
        font.family: AequalynSettings.uiFont
        font.pixelSize: 12
        Layout.preferredWidth: 90
    }

    Repeater {
        model: [{ glyph: "‹", delta: -1 }, { glyph: "", delta: 0 }, { glyph: "›", delta: 1 }]
        delegate: Rectangle {
            required property var modelData
            implicitWidth: modelData.delta === 0 ? 62 : 30
            implicitHeight: 30
            radius: 9
            color: modelData.delta === 0 ? "transparent"
                 : Qt.rgba(stepper.theme.textPrimary.r, stepper.theme.textPrimary.g, stepper.theme.textPrimary.b, btn.containsMouse ? 0.11 : 0.06)
            Text {
                anchors.centerIn: parent
                text: modelData.delta === 0 ? (stepper.value + stepper.suffix) : modelData.glyph
                color: modelData.delta === 0 ? stepper.theme.accentPrimary : stepper.theme.textPrimary
                font.family: stepper.font
                font.pixelSize: modelData.delta === 0 ? 12 : 15
                font.bold: modelData.delta === 0
            }
            MouseArea {
                id: btn
                anchors.fill: parent
                enabled: modelData.delta !== 0
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    let v = stepper.value + modelData.delta * stepper.step;
                    v = Math.max(stepper.from, Math.min(stepper.to, Math.round(v * 100) / 100));
                    if (v !== stepper.value) stepper.stepped(v);
                }
            }
        }
    }
}
