// A thing in a list (a network, a device, an app): an icon, its name and state, and
// up to two buttons. Anything else (a switch) goes inside, before the buttons.
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: r
    property string icon: ""
    property string iconSource: ""
    property string title: ""
    property string sub: ""
    property string action: ""
    property bool primary: false
    property string action2: ""
    property bool danger2: false
    property bool busy: false
    property bool highlight: false
    property bool clickable: false
    default property alias trailing: tail.data
    signal activated()
    signal activated2()
    signal clicked()

    Layout.fillWidth: true
    implicitHeight: Math.max(58, texts.implicitHeight + 22)
    radius: grouped ? 8 : 12
    color: clickable && area.containsMouse ? Cc.theme.bgHover : (grouped ? "transparent" : Cc.theme.bgSurface)
    // the one in use: an accent edge, as everywhere
    border.width: highlight ? 1 : (grouped ? 0 : 1)
    border.color: highlight ? Cc.theme.accentPrimary : Cc.theme.bgBorder
    // the pattern (Cc.qml): a row of its section's group, or a group of its own
    property var section: null
    readonly property bool grouped: !!section
    readonly property bool firstRow: Cc.firstShown(parent) === r
    Component.onCompleted: { r.section = Cc.sectionOf(r); if (r.section) r.section.rows++; }
    Component.onDestruction: { try { if (r.section) r.section.rows--; } catch (e) {} }
    Rectangle {
        visible: r.grouped && !r.firstRow
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
        hoverEnabled: r.clickable
        enabled: r.clickable
        cursorShape: Qt.PointingHandCursor
        onClicked: r.clicked()
    }
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 12
        spacing: 12
        Rectangle {
            visible: r.icon !== "" || r.iconSource !== ""
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            radius: 10
            color: r.highlight ? Cc.theme.bgSelected : Cc.theme.bgBase
            border.width: r.highlight ? 1 : 0
            border.color: Cc.theme.accentPrimary
            Image {
                id: pic
                anchors.fill: parent
                anchors.margins: r.iconSource !== "" ? 2 : 0
                visible: r.iconSource !== ""
                source: r.iconSource
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
            }
            Text {
                anchors.centerIn: parent
                visible: r.icon !== "" || (r.iconSource !== "" && pic.status === Image.Error)
                text: r.icon !== "" ? r.icon : r.title.slice(0, 1).toUpperCase()
                color: Cc.theme.accentPrimary
                font.family: r.icon !== "" ? Cc.mono : Cc.sans
                font.pixelSize: 17
            }
        }
        ColumnLayout {
            id: texts
            Layout.fillWidth: true
            spacing: 1
            Text {
                text: r.title
                color: Cc.theme.textPrimary
                font.family: Cc.sans
                font.pixelSize: 13
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Text {
                visible: r.sub !== ""
                text: r.sub
                color: Cc.theme.textMuted
                font.family: Cc.sans
                font.pixelSize: 11
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
        RowLayout { id: tail; spacing: 8 }
        CcButton {
            visible: r.action2 !== ""
            text: r.action2
            danger: r.danger2
            onClicked: r.activated2()
        }
        CcButton {
            visible: r.action !== ""
            text: r.action
            primary: r.primary
            enabled: !r.busy
            onClicked: r.activated()
        }
    }
}
