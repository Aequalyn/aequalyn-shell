// "Label   ‹ value ›" with bounds; used for hours and durations.
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: stepper
    property var theme
    property string font: "JetBrainsMono Nerd Font"
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
        font.family: stepper.font
        font.pixelSize: 11
        Layout.preferredWidth: 64
    }

    Repeater {
        model: [{ glyph: "‹", delta: -1 }, { glyph: "", delta: 0 }, { glyph: "›", delta: 1 }]
        delegate: Rectangle {
            required property var modelData
            implicitWidth: modelData.delta === 0 ? 54 : 24
            implicitHeight: 24
            radius: 6
            color: modelData.delta === 0 ? stepper.theme.bgSurface : (btn.containsMouse ? stepper.theme.bgHover : "transparent")
            border.color: modelData.delta === 0 ? stepper.theme.bgBorder : "transparent"
            Text {
                anchors.centerIn: parent
                text: modelData.delta === 0 ? (stepper.value + stepper.suffix) : modelData.glyph
                color: stepper.theme.textPrimary
                font.family: stepper.font
                font.pixelSize: 12
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
