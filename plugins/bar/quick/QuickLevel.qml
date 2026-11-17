// An amount you drag (brightness, volume, how far into a song): its icon (a click on
// it: iconClicked), the track, and the amount as words (`format`, a percent unless
// told). Without a glyph, no icon. The wheel moves it by 5%.
import QtQuick
import QtQuick.Layouts
import Quickshell

RowLayout {
    id: lv
    property string glyph: ""
    property string tip: ""
    property real value: 0
    property bool muted: false
    property var format: v => Math.round(v * 100) + "%"
    property int textWidth: 38
    signal moved(real value)
    signal iconClicked()
    property bool dragging: false
    property real dragValue: 0
    readonly property real shown: dragging ? dragValue : value
    Layout.fillWidth: true
    spacing: 10
    QuickRound { visible: lv.glyph !== ""; glyph: lv.glyph; tip: lv.tip; small: true; onClicked: lv.iconClicked() }
    Item {
        id: track
        Layout.fillWidth: true
        implicitHeight: 28
        Accessible.role: Accessible.Slider
        Accessible.name: lv.tip
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 8
            radius: 4
            color: Quick.theme.bgSelected
            Rectangle {
                width: Math.max(8, parent.width * lv.shown)
                height: parent.height
                radius: 4
                color: lv.muted ? Quick.theme.textMuted : Quick.theme.accentPrimary
            }
        }
        Rectangle {
            width: 18; height: 18; radius: 9
            anchors.verticalCenter: parent.verticalCenter
            x: lv.shown * (track.width - width)
            color: Quick.theme.textPrimary
            border.color: lv.muted ? Quick.theme.textMuted : Quick.theme.accentPrimary
            border.width: 4
        }
        MouseArea {
            anchors.fill: parent
            preventStealing: true
            cursorShape: Qt.PointingHandCursor
            function at(x) { return Math.max(0, Math.min(1, (x - 9) / Math.max(1, track.width - 18))); }
            onPressed: m => { lv.dragValue = at(m.x); lv.dragging = true; lv.moved(lv.dragValue); }
            onPositionChanged: m => { if (lv.dragging) { lv.dragValue = at(m.x); lv.moved(lv.dragValue); } }
            onReleased: lv.dragging = false
            onCanceled: lv.dragging = false
            onWheel: w => lv.moved(Math.max(0, Math.min(1, lv.value + (w.angleDelta.y > 0 ? 0.05 : -0.05))))
        }
    }
    Text {
        Layout.preferredWidth: lv.textWidth
        horizontalAlignment: Text.AlignRight
        text: lv.format(lv.shown)
        color: Quick.theme.textSecondary
        font.family: Quick.mono
        font.pixelSize: 11
    }
}
