import QtQuick
import "root:/settings"

// Spartan segmented control: a row of flat chips, 10px corners, 120ms colour
// fade. Keeps the ButtonGroup API (options/current/onPicked/width).
Item {
    id: bg

    property var options: []
    property string current: ""
    property int h: 36

    signal picked(string key)

    implicitHeight: bg.h
    implicitWidth: row.implicitWidth

    Row {
        id: row
        spacing: 8
        anchors.verticalCenter: parent.verticalCenter

        Repeater {
            model: bg.options
            delegate: Rectangle {
                required property var modelData
                readonly property bool on: modelData.key === bg.current
                height: bg.h
                width: lbl.implicitWidth + 24
                radius: 10
                color: on ? Theme.primary : (ma.containsMouse ? Theme.stateHover : Theme.bgSelected)
                Behavior on color { ColorAnimation { duration: 120 } }

                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        visible: modelData.icon !== undefined && modelData.icon !== ""
                        text: modelData.icon || ""
                        color: on ? Theme.fgAccent : Theme.text
                        font.family: AequalynSettings.monoFont
                        font.pixelSize: 16
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        id: lbl
                        text: modelData.label || ""
                        color: on ? Theme.fgAccent : Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: bg.picked(modelData.key)
                }
            }
        }
    }
}
