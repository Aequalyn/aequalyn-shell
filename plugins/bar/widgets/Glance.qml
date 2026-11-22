// Glance face unlock in the bar: one icon, scanning state, and a quick panel
// with the daemon's status and arm/disarm/test-scan actions.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "root:/settings"
import "root:/plugins/bar/quick"
import ".."
import "GlanceLogic.js" as GlanceLogic

Rectangle {
    required property var bar
    property color ink: "transparent"

    id: button
    objectName: "aequalyn-glance-button"
    Accessible.role: Accessible.Button
    Accessible.name: "Glance face unlock"

    width: 28
    height: 24
    radius: 8
    color: area.containsMouse || quick.visible ? bar.theme.bgSelected : bar.chipColor

    readonly property var backend: backendObj
    StatusBackend {
        id: backendObj
        settings: ({ refreshIntervalSec: AequalynSettings.glanceRefreshIntervalSec,
                    glancectlPath: AequalynSettings.glancectlPath })
    }

    readonly property string stateLabel: GlanceLogic.stateLabel(backend.status)

    Text {
        anchors.centerIn: parent
        text: "󰱻"
        color: backend.scanning ? bar.theme.accentPrimary : bar.inked(ink, bar.theme.textPrimary)
        font.pixelSize: 14
        font.family: bar.font
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: mouse => {
            const role = button.bar.clickRole("glance", mouse.button)
            if (role === "quick") { button.toggleQuick(); return }
            if (mouse.button === Qt.RightButton) {
                if (button.backend.canScan) button.backend.testScan()
                return
            }
            button.toggleQuick()
        }
    }

    function toggleQuick() {
        const w = button.QsWindow.window
        button.bar.toggleWidgetPopup("glance", w ? w.screen : null)
    }

    // IPC parity with the original widget is provided by the bar:
    //   qs ipc call bar popup glance

    GlanceQuick {
        id: quick
        bar: button.bar
        backend: button.backend
        anchorItem: button
        open: button.bar.widgetPopup === "glance" && !!button.QsWindow.window
              && button.QsWindow.window.screen === button.bar.popupScreen
        onDismissed: button.bar.widgetPopup = ""
    }
}
