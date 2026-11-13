// List: names on the left (fast to scan and search), details on the right.
// The closest to Omarchy's own menus.
import QtQuick
import QtQuick.Layouts
import ".."

Item {
    id: root
    property var theme
    property string font
    property var items: []
    property int currentIndex: 0
    readonly property int columns: 1
    signal picked(int index)
    signal hovered(int index)

    readonly property var cur: items[currentIndex] || ({})
    readonly property var keys: [
        ["bgBase", "Base"], ["bgSurface", "Surface"], ["bgSelected", "Selected"], ["bgBorder", "Border"],
        ["textPrimary", "Text"], ["textMuted", "Muted"], ["accentPrimary", "Primary"], ["accentCyan", "Cyan"],
        ["accentGreen", "Green"], ["accentOrange", "Orange"], ["accentRed", "Red"]
    ]

    RowLayout {
        anchors.fill: parent
        spacing: 16

        ListView {
            id: list
            Layout.preferredWidth: Math.max(260, root.width * 0.36)
            Layout.fillHeight: true
            model: root.items
            clip: true
            spacing: 2
            currentIndex: root.currentIndex
            highlightMoveDuration: 120
            boundsBehavior: Flickable.StopAtBounds
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
            highlight: Rectangle {
                radius: 8
                color: root.theme.bgSelected
                Rectangle {
                    width: 3; height: 22; radius: 2
                    anchors.left: parent.left; anchors.leftMargin: 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.theme.accentPrimary
                }
            }

            delegate: Item {
                id: row
                required property var modelData
                required property int index
                width: list.width
                height: 44

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    Rectangle {
                        Layout.preferredWidth: 46
                        Layout.preferredHeight: 28
                        radius: 5
                        clip: true
                        color: (row.modelData.palette && row.modelData.palette.bgBase) || root.theme.bgSurface
                        border.color: root.theme.bgBorder
                        Image {
                            anchors.fill: parent
                            visible: !!row.modelData.image
                            source: row.modelData.image ? "file://" + row.modelData.image : ""
                            sourceSize.width: 92
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                        Rectangle {
                            visible: !row.modelData.image && !!row.modelData.palette
                            anchors.centerIn: parent
                            width: 12; height: 12; radius: 6
                            color: row.modelData.palette ? row.modelData.palette.accentPrimary : "transparent"
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.title || ""
                            color: row.index === root.currentIndex ? root.theme.textPrimary : root.theme.textSecondary
                            font.family: root.font
                            font.pixelSize: 12
                            font.bold: row.index === root.currentIndex
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: (row.modelData.subtitle || "") !== ""
                            text: row.modelData.subtitle || ""
                            color: root.theme.textMuted
                            font.family: root.font
                            font.pixelSize: 9
                            elide: Text.ElideMiddle
                        }
                    }
                    Text {
                        visible: !!row.modelData.active
                        text: "󰄬"
                        color: root.theme.accentGreen
                        font.family: root.font
                        font.pixelSize: 13
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.hovered(row.index)
                    onClicked: root.picked(row.index)
                }
            }
        }

        Item {
            id: details
            Layout.fillWidth: true
            Layout.fillHeight: true

            Column {
                width: details.width
                spacing: 12

                AtelierCard {
                    width: parent.width
                    height: Math.min(width / 1.7, details.height * 0.62)
                    theme: root.theme
                    font: root.font
                    item: root.cur
                    selected: true
                    showText: false
                    imageWidth: 1200
                    onClicked: root.picked(root.currentIndex)
                }
                Text {
                    text: root.cur.title || ""
                    color: root.theme.textPrimary
                    font.family: root.font
                    font.pixelSize: 16
                    font.bold: true
                }
                Text {
                    width: parent.width
                    text: root.cur.detail || root.cur.subtitle || ""
                    color: root.theme.textMuted
                    font.family: root.font
                    font.pixelSize: 11
                    wrapMode: Text.WrapAnywhere
                }
                Flow {
                    width: parent.width
                    spacing: 6
                    visible: !!root.cur.palette
                    Repeater {
                        model: root.cur.palette ? root.keys : []
                        Row {
                            required property var modelData
                            spacing: 6
                            Rectangle {
                                width: 18; height: 18; radius: 4
                                color: root.cur.palette[modelData[0]] || "transparent"
                                border.color: root.theme.bgBorder
                            }
                            Text {
                                width: 96
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData[1] + " " + String(root.cur.palette[modelData[0]] || "").toUpperCase()
                                color: root.theme.textSecondary
                                font.family: root.font
                                font.pixelSize: 9
                            }
                        }
                    }
                }
            }
        }
    }
}
