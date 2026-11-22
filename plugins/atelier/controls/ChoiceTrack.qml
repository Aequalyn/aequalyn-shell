// A row of joined buttons: one choice, filled with the accent. The same shape
// the desktop's other settings use, including Clipboard history.
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: track
    property var theme
    property string font: "JetBrainsMono Nerd Font"
    property var options: []
    property var labels: ({})
    property var value
    signal picked(var value)

    function tint(a) {
        return theme ? Qt.rgba(theme.textPrimary.r, theme.textPrimary.g, theme.textPrimary.b, a) : "transparent";
    }
    function labelOf(v) {
        return labels[v] !== undefined ? String(labels[v]) : String(v);
    }

    Layout.fillWidth: true
    implicitHeight: grid.implicitHeight + 8
    radius: 6
    color: tint(0.05)
    border.width: 1
    border.color: tint(0.08)
    opacity: enabled ? 1 : 0.45

    readonly property int columns: options.length === 0 ? 1
        : Math.max(1, Math.min(options.length, Math.floor((width + 2) / 110)))

    GridLayout {
        id: grid
        anchors.fill: parent
        anchors.margins: 3
        columns: track.columns
        columnSpacing: 2
        rowSpacing: 2

        Repeater {
            model: track.options
            delegate: Rectangle {
                id: opt
                required property var modelData
                readonly property bool on: opt.modelData === track.value

                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                Layout.preferredHeight: 32
                Layout.minimumWidth: 64
                radius: 4
                color: opt.on ? track.theme.accentPrimary
                              : (area.containsMouse ? track.tint(0.08) : "transparent")
                Behavior on color { ColorAnimation { duration: 90 } }

                Accessible.role: Accessible.RadioButton
                Accessible.name: track.labelOf(opt.modelData)
                Accessible.checked: opt.on

                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 5
                    anchors.rightMargin: 5
                    text: track.labelOf(opt.modelData)
                    color: opt.on ? track.theme.bgBase : track.theme.textPrimary
                    opacity: opt.on ? 1 : 0.8
                    font.family: "sans-serif"
                    font.pixelSize: 11
                    font.weight: opt.on ? Font.DemiBold : Font.Normal
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: track.picked(opt.modelData)
                }
            }
        }
    }
}
