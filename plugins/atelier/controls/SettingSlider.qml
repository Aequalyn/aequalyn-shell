// An amount: − and + beside the reading, a quiet track and a small accent knob
// underneath. The same slider shape the desktop's other settings use.
import QtQuick
import QtQuick.Layouts
import "root:/settings"

ColumnLayout {
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

    function tint(a) {
        return theme ? Qt.rgba(theme.textPrimary.r, theme.textPrimary.g, theme.textPrimary.b, a) : "transparent";
    }
    function snap(v) {
        v = Math.max(from, Math.min(to, v));
        return Number((from + Math.round((v - from) / step) * step).toFixed(2));
    }
    function commit(v) {
        v = snap(v);
        if (v !== value) stepper.stepped(v);
    }

    readonly property real frac: to === from ? 0 : Math.max(0, Math.min(1, (value - from) / (to - from)))

    Layout.fillWidth: true
    spacing: 4
    opacity: enabled ? 1 : 0.45

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
            text: stepper.label
            color: stepper.theme ? stepper.theme.textSecondary : "white"
            font.family: AequalynSettings.uiFont
            font.pixelSize: 12
            Layout.fillWidth: true
            elide: Text.ElideRight
        }
        StepButton {
            theme: stepper.theme
            glyph: "\u2212"
            onClicked: stepper.commit(stepper.value - stepper.step)
        }
        Text {
            Layout.minimumWidth: 46
            text: stepper.value + stepper.suffix
            color: stepper.theme ? stepper.theme.accentPrimary : "white"
            font.family: stepper.font
            font.pixelSize: 12
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
        }
        StepButton {
            theme: stepper.theme
            glyph: "+"
            onClicked: stepper.commit(stepper.value + stepper.step)
        }
    }

    Item {
        id: track
        Layout.fillWidth: true
        implicitHeight: 20

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 6
            radius: 3
            color: stepper.tint(0.12)
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(6, parent.width * stepper.frac)
            height: 6
            radius: 3
            color: stepper.theme ? stepper.theme.accentPrimary : "white"
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: stepper.frac * (track.width - width)
            width: 16
            height: 16
            radius: 8
            color: stepper.theme ? stepper.theme.accentPrimary : "white"
            border.width: 2
            border.color: stepper.theme ? stepper.theme.bgBase : "black"
        }
        MouseArea {
            anchors.fill: parent
            preventStealing: true
            cursorShape: Qt.PointingHandCursor
            function at(x) {
                const f = Math.max(0, Math.min(1, (x - 8) / Math.max(1, track.width - 16)));
                return stepper.snap(stepper.from + f * (stepper.to - stepper.from));
            }
            onPressed: m => stepper.commit(at(m.x))
            onPositionChanged: m => { if (pressed) stepper.commit(at(m.x)); }
        }
    }
}
