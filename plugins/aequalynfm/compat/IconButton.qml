import QtQuick

// Spartan icon tile: 34x34 radius 10, no spring, no ripple. The Material Symbol
// is drawn by the (layer-disabled) Icon shim.
Item {
    id: ib

    property string icon: ""
    property string tooltip: ""
    property bool disabled: false
    property string variant: "standard"
    property string size: "m"
    property bool checkable: false
    property bool checked: false

    signal clicked()
    signal toggled(bool value)

    readonly property int h: ib.size === "xs" ? 30 : (ib.size === "m" ? 36 : 44)
    readonly property bool on: false

    implicitWidth: ib.h
    implicitHeight: ib.h

    Rectangle {
        id: box
        anchors.fill: parent
        radius: 10
        color: ib.disabled ? "transparent"
             : (ib.checked ? Theme.primary
             : (area.containsMouse ? Theme.stateHover : "transparent"))
        border.width: ib.variant === "outlined" ? 1 : 0
        border.color: Theme.outline
        Behavior on color { ColorAnimation { duration: 120 } }

        Icon {
            anchors.centerIn: parent
            name: ib.icon
            size: Math.round(ib.h * 0.56)
            color: ib.disabled ? Theme.disabledContent : (ib.checked ? Theme.fgAccent : Theme.text)
        }

        MouseArea {
            id: area
            anchors.fill: parent
            enabled: !ib.disabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ib.clicked()
        }
    }
}
