import QtQuick
import "root:/settings"

// Spartan button: flat rectangle, 10px corners, 120ms colour fade, no spring,
// no ripple. Keeps the M3-ish variant/size API the dialogs expect.
Item {
    id: btn

    property string variant: "filled"
    property string size: "s"
    property string text: ""
    property string icon: ""
    property bool checkable: false
    property bool checked: false
    property bool disabled: false
    property bool danger: false
    property color containerOverride: "transparent"
    property color contentOverride: "transparent"

    signal clicked()
    signal toggled(bool value)

    readonly property int h: btn.size === "xs" ? 30 : (btn.size === "m" ? 48 : 36)
    readonly property int pad: btn.size === "xs" ? 12 : (btn.size === "m" ? 24 : 16)
    readonly property int iconPx: btn.size === "m" ? 22 : (btn.size === "xs" ? 17 : 19)
    readonly property bool selected: btn.checkable && btn.checked

    readonly property color container: {
        if (btn.containerOverride.a > 0) return btn.containerOverride;
        if (btn.disabled) return (btn.variant === "text" || btn.variant === "outlined") ? Qt.rgba(0,0,0,0) : Theme.disabledContainer;
        if (btn.danger) return btn.variant === "filled" ? Theme.error : (btn.variant === "tonal" ? Theme.errorContainer : Qt.rgba(0,0,0,0));
        if (btn.checkable && btn.checked) {
            if (btn.variant === "filled") return Theme.primary;
            if (btn.variant === "tonal") return Theme.secondaryContainer;
            if (btn.variant === "outlined") return Theme.inverseSurface;
        }
        switch (btn.variant) {
        case "filled": return Theme.primary;
        case "tonal": return Theme.bgSelected;
        case "elevated": return Theme.surfaceHigh;
        }
        return Qt.rgba(0, 0, 0, 0);
    }
    readonly property color content: {
        if (btn.contentOverride.a > 0) return btn.contentOverride;
        if (btn.disabled) return Theme.disabledContent;
        if (btn.danger) return (btn.variant === "filled" || btn.variant === "tonal") ? Theme.fgErrorContainer : Theme.error;
        if (btn.checkable && btn.checked && btn.variant === "outlined") return Theme.fgInverseSurface;
        if (btn.variant === "filled") return Theme.fgAccent;
        if (btn.variant === "tonal") return Theme.text;
        return Theme.text;
    }

    implicitHeight: btn.h
    implicitWidth: Math.max(btn.h, row.implicitWidth + btn.pad * 2)

    Rectangle {
        id: box
        anchors.fill: parent
        radius: 10
        color: btn.container
        border.width: btn.variant === "outlined" ? 1 : 0
        border.color: btn.disabled ? Theme.disabledContent : Theme.outline
        Behavior on color { ColorAnimation { duration: 120 } }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: btn.icon !== "" && btn.text !== "" ? 6 : 0

            Text {
                visible: btn.icon !== ""
                text: btn.icon
                color: btn.content
                font.family: AequalynSettings.monoFont
                font.pixelSize: btn.iconPx
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                visible: btn.text !== ""
                text: btn.text
                color: btn.content
                font.family: Theme.fontFamily
                font.pixelSize: btn.size === "xs" ? 11 : 12
                font.weight: Font.DemiBold
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: !btn.disabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (btn.checkable) { btn.checked = !btn.checked; btn.toggled(btn.checked); }
                btn.clicked();
            }
        }
    }
}
