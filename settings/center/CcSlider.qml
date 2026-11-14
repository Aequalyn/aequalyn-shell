// An amount: drag the bar, or step it with − and +. The value is saved when you let
// go, so commands behind a setting run once, not on every pixel. `setting` binds it
// to an AequalynSettings key; otherwise use `value` and `committed` (and `live` for
// something that should follow the drag, like a volume).
import QtQuick
import QtQuick.Layouts
import "root:/settings"

Rectangle {
    id: s
    property string title: ""
    property string sub: ""
    property string setting: ""
    property real value: 0
    property real from: 0
    property real to: 100
    property real step: 1
    property string unit: ""
    property int decimals: 0
    property string zeroText: ""       // shown instead of 0, when 0 means "automatic"
    property var format: null          // value -> text, for anything else
    signal committed(real value)
    signal moved(real value)

    property bool dragging: false
    property real dragValue: 0
    readonly property real current: dragging ? dragValue : (setting !== "" ? Number(AequalynSettings[setting]) : value)
    readonly property real frac: to === from ? 0 : Math.max(0, Math.min(1, (current - from) / (to - from)))

    function snap(v) {
        v = Math.max(from, Math.min(to, v));
        return Number((from + Math.round((v - from) / step) * step).toFixed(4));
    }
    function commit(v) {
        v = snap(v);
        if (setting !== "") AequalynSettings.apply(setting, v);
        committed(v);
    }
    function text(v) {
        if (format) return format(v);
        if (zeroText !== "" && v === 0) return zeroText;
        return v.toFixed(decimals) + unit;
    }

    Layout.fillWidth: true
    implicitHeight: col.implicitHeight + 26
    radius: 12
    color: Cc.theme.bgSurface
    opacity: enabled ? 1 : 0.5

    ColumnLayout {
        id: col
        x: 16
        width: parent.width - 32
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: s.title
                color: Cc.theme.textPrimary
                font.family: Cc.sans
                font.pixelSize: 13
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Text {
                text: s.text(s.current)
                color: Cc.theme.accentPrimary
                font.family: Cc.mono
                font.pixelSize: 12
                font.bold: true
            }
        }
        Text {
            visible: s.sub !== ""
            text: s.sub
            color: Cc.theme.textMuted
            font.family: Cc.sans
            font.pixelSize: 11
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2
            spacing: 10
            StepButton { label: "−"; onClicked: s.commit(s.current - s.step) }
            Item {
                id: track
                Layout.fillWidth: true
                implicitHeight: 24
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 6
                    radius: 3
                    color: Cc.theme.bgSelected
                    Rectangle {
                        width: Math.max(6, parent.width * s.frac)
                        height: parent.height
                        radius: 3
                        color: Cc.theme.accentPrimary
                    }
                }
                Rectangle {
                    width: 20; height: 20; radius: 10
                    anchors.verticalCenter: parent.verticalCenter
                    x: s.frac * (track.width - width)
                    color: Cc.theme.textPrimary
                    border.color: Cc.theme.accentPrimary
                    border.width: 4
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: s.enabled
                    preventStealing: true
                    cursorShape: Qt.PointingHandCursor
                    function at(x) { return s.snap(s.from + Math.max(0, Math.min(1, (x - 10) / Math.max(1, track.width - 20))) * (s.to - s.from)); }
                    onPressed: m => { s.dragValue = at(m.x); s.dragging = true; s.moved(s.dragValue); }
                    onPositionChanged: m => { if (s.dragging) { s.dragValue = at(m.x); s.moved(s.dragValue); } }
                    onReleased: { s.dragging = false; s.commit(s.dragValue); }
                    onCanceled: s.dragging = false
                }
            }
            StepButton { label: "+"; onClicked: s.commit(s.current + s.step) }
        }
    }

    component StepButton: Rectangle {
        id: sb
        property string label: ""
        signal clicked()
        implicitWidth: 28
        implicitHeight: 28
        radius: 9
        color: sbArea.containsMouse ? Cc.theme.bgHover : Cc.theme.bgSelected
        Text {
            anchors.centerIn: parent
            text: sb.label
            color: Cc.theme.textPrimary
            font.family: Cc.mono
            font.pixelSize: 15
        }
        MouseArea {
            id: sbArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: s.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: sb.clicked()
        }
    }
}
