// A setting you turn on or off, in plain words. `setting` binds it to an
// AequalynSettings key; otherwise use `checked` and `toggled`.
import QtQuick
import QtQuick.Layouts
import "root:/settings"

Rectangle {
    id: t
    property string title: ""
    property string sub: ""
    property string setting: ""
    property bool checked: false
    signal toggled(bool value)

    readonly property bool on: setting !== "" ? !!AequalynSettings[setting] : checked
    function flip(v) {
        if (setting !== "") AequalynSettings.apply(setting, v);
        toggled(v);
    }

    Layout.fillWidth: true
    implicitHeight: Math.max(54, col.implicitHeight + 24)
    radius: grouped ? 8 : 12
    color: area.containsMouse && enabled ? Cc.theme.bgHover : (grouped ? "transparent" : Cc.theme.bgSurface)
    border.width: grouped ? 0 : 1
    border.color: Cc.theme.bgBorder
    opacity: enabled ? 1 : 0.5
    // the pattern (Cc.qml): a row of its section's group, or a group of its own
    property var section: null
    readonly property bool grouped: !!section
    readonly property bool firstRow: Cc.firstShown(parent) === t
    Component.onCompleted: { t.section = Cc.sectionOf(t); if (t.section) t.section.rows++; }
    Component.onDestruction: { try { if (t.section) t.section.rows--; } catch (e) {} }
    Rectangle {
        visible: t.grouped && !t.firstRow
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        height: 1
        color: Cc.theme.bgBorder
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: t.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: t.flip(!t.on)
    }
    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: sw.left
        anchors.leftMargin: 16
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Text {
            text: t.title
            color: Cc.theme.textPrimary
            font.family: Cc.sans
            font.pixelSize: 13
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
        Text {
            visible: t.sub !== ""
            text: t.sub
            color: Cc.theme.textMuted
            font.family: Cc.sans
            font.pixelSize: 11
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }
    CcSwitch {
        id: sw
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        enabled: t.enabled
        checked: t.on
        onToggled: v => t.flip(v)
    }
}
