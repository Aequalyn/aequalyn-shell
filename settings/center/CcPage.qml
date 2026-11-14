// One page of the control center: a plain title and a line saying what the page is
// for, an optional row of sub pages, then the page itself, which scrolls.
//
// A sub page set in `fills` holds one big piece that scrolls by itself (an Atelier
// pane); it then takes the whole height instead of scrolling with the page.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
    id: page
    property string title: ""
    property string sub: ""
    property var tabs: []           // names of the sub pages, if any
    property int tab: 0
    property var fills: []          // the sub pages that fill the page
    default property alias content: body.data
    property alias actions: actionRow.data

    readonly property bool fill: fills.indexOf(tab) >= 0
    onTabChanged: flick.contentY = 0

    ColumnLayout {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Text {
                    text: page.title
                    color: Cc.theme.textPrimary
                    font.family: Cc.sans
                    font.pixelSize: 24
                    font.weight: Font.DemiBold
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
                Text {
                    visible: page.sub !== ""
                    text: page.sub
                    color: Cc.theme.textMuted
                    font.family: Cc.sans
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }
            RowLayout {
                id: actionRow
                Layout.alignment: Qt.AlignTop
                spacing: 8
            }
        }

        // the sub pages, as a segmented row
        Rectangle {
            visible: page.tabs.length > 0
            implicitWidth: segs.implicitWidth + 8
            implicitHeight: 40
            radius: 12
            color: Cc.theme.bgSurface
            Row {
                id: segs
                anchors.centerIn: parent
                spacing: 4
                Repeater {
                    model: page.tabs
                    delegate: Rectangle {
                        required property string modelData
                        required property int index
                        readonly property bool on: page.tab === index
                        width: segText.implicitWidth + 32
                        height: 32
                        radius: 9
                        color: on ? Cc.theme.accentPrimary : (segArea.containsMouse ? Cc.theme.bgHover : "transparent")
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                            id: segText
                            anchors.centerIn: parent
                            text: modelData
                            color: parent.on ? Cc.theme.bgBase : Cc.theme.textSecondary
                            font.family: Cc.sans
                            font.pixelSize: 12
                            font.weight: parent.on ? Font.DemiBold : Font.Normal
                        }
                        MouseArea {
                            id: segArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.tab = index
                        }
                    }
                }
            }
        }
    }

    Flickable {
        id: flick
        anchors.top: header.bottom
        anchors.topMargin: 20
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        interactive: !page.fill
        boundsBehavior: Flickable.StopAtBounds
        contentWidth: width
        contentHeight: page.fill ? height : body.implicitHeight + 24
        ScrollBar.vertical: ScrollBar { policy: page.fill ? ScrollBar.AlwaysOff : ScrollBar.AsNeeded }

        ColumnLayout {
            id: body
            width: flick.width - (page.fill ? 0 : 14)
            height: page.fill ? flick.height : implicitHeight
            spacing: 22
        }
    }
}
