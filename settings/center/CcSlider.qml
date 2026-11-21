// An amount: drag the bar, or step it with − and +. The bar is compact: a quiet
// track, an accent fill and a small accent knob with a surface edge.
// The value is saved when you let go, so commands behind a setting run once, not on
// every pixel. `setting` binds it to an AequalynSettings key; otherwise use `value`
// and `committed` (and `moved` for something that should follow the drag, like volume).
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
    implicitHeight: col.implicitHeight + 16
    radius: 6
    color: grouped ? "transparent" : Cc.alpha(Cc.theme.textPrimary, 0.03)
    border.width: grouped ? 0 : 1
    border.color: Cc.alpha(Cc.theme.textPrimary, 0.08)
    opacity: enabled ? 1 : 0.4
    // the pattern (Cc.qml): a row of its section's group, or a group of its own
    property var section: null
    readonly property bool grouped: !!section
    readonly property bool firstRow: Cc.firstShown(parent) === s
    Component.onCompleted: { s.section = Cc.sectionOf(s); if (s.section) s.section.rows++; }
    Component.onDestruction: { try { if (s.section) s.section.rows--; } catch (e) {} }
    Rectangle {
        visible: s.grouped && !s.firstRow
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        height: 1
        color: Cc.alpha(Cc.theme.textPrimary, 0.07)
    }

    ColumnLayout {
        id: col
        x: 12
        width: parent.width - 24
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: s.title
                color: Cc.theme.textPrimary
                font.family: Cc.sans
                font.pixelSize: 11
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Text {
                text: s.text(s.current)
                color: Cc.theme.accentPrimary
                font.family: Cc.mono
                font.pixelSize: 10
                font.bold: true
            }
        }
        Text {
            visible: s.sub !== ""
            text: s.sub
            color: Cc.theme.textMuted
            font.family: Cc.sans
            font.pixelSize: 9
            opacity: 0.55
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            StepButton { label: "−"; onClicked: s.commit(s.current - s.step) }
            Item {
                id: track
                Layout.fillWidth: true
                implicitHeight: 20
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 6
                    radius: 3
                    color: Cc.alpha(Cc.theme.textPrimary, 0.12)
                    Rectangle {
                        width: Math.max(6, parent.width * s.frac)
                        height: parent.height
                        radius: 3
                        color: Cc.theme.accentPrimary
                    }
                }
                Rectangle {
                    width: 16; height: 16; radius: 8
                    anchors.verticalCenter: parent.verticalCenter
                    x: s.frac * (track.width - width)
                    color: Cc.theme.accentPrimary
                    border.color: Cc.theme.bgSurface
                    border.width: 2
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: s.enabled
                    preventStealing: true
                    cursorShape: Qt.PointingHandCursor
                    function at(x) { return s.snap(s.from + Math.max(0, Math.min(1, (x - 8) / Math.max(1, track.width - 16))) * (s.to - s.from)); }
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
        implicitWidth: 24
        implicitHeight: 24
        radius: 6
        color: Cc.alpha(Cc.theme.textPrimary, sbArea.containsMouse ? 0.16 : 0.08)
        Text {
            anchors.centerIn: parent
            text: sb.label
            color: Cc.theme.textPrimary
            opacity: 0.85
            font.family: Cc.mono
            font.pixelSize: 12
            font.weight: Font.DemiBold
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
