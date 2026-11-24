// Showcase on the bar. Left click opens settings; right click (or configured
// bar click) opens the quick panel; middle click toggles arrange mode.
import QtQuick
import Quickshell
import "root:/plugins/kit"

Rectangle {
    required property var bar
    property color ink: "transparent"

    id: button
    objectName: "aequalyn-showcase-button"
    Accessible.role: Accessible.Button
    Accessible.name: "Open Showcase desktop widgets"

    width: 28
    height: 24
    radius: 8
    color: area.containsMouse || quick.visible ? bar.theme.bgSelected : bar.chipColor

    readonly property var svc: KitHost.get("showcase")
    readonly property bool on: svc && svc.cfg ? svc.cfg.enabled !== false : true

    Text {
        anchors.centerIn: parent
        text: "󰹉"
        color: bar.inked(ink, on ? bar.theme.accentPrimary : bar.theme.textDisabled)
        font.pixelSize: 13
        font.family: bar.iconFont
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: mouse => {
            const role = button.bar.clickRole("showcase", mouse.button)
            if (role === "quick") { button.toggleQuick(); return }
            if (role === "right") { button.bar.openPage("showcase"); return }
            if (mouse.button === Qt.MiddleButton) {
                if (button.svc) button.svc.arrange()
            } else {
                button.bar.openPage("showcase")
            }
        }
    }

    function toggleQuick() {
        const w = button.QsWindow.window
        button.bar.toggleWidgetPopup("showcase", w ? w.screen : null)
    }

    ShowcaseQuick {
        id: quick
        bar: button.bar
        anchorItem: button
        open: button.bar.widgetPopup === "showcase" && !!button.QsWindow.window
              && button.QsWindow.window.screen === button.bar.popupScreen
        onDismissed: button.bar.widgetPopup = ""
    }
}
