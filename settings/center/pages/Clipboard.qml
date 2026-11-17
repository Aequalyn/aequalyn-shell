// Clipboard: Clipscape's settings, with the keybind underneath.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/settings"
import "root:/plugins/clipscape"
import "root:/plugins/clipscape/qml/panel" as ClipPanel
import ".."

CcPage {
    id: page
    title: "Clipboard Settings"

    CcSection {

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 600
            radius: 14
            color: "transparent"
            clip: true

            ClipPanel.SettingsView {
                anchors.fill: parent
                svc: ClipscapeService
            }
        }
    }

    CcSection {
        title: "Shortcut"
        hint: "The key that opens the clipboard history."

        RowLayout {
            Layout.fillWidth: true
            spacing: 14
            Row {
                Layout.preferredWidth: 220
                spacing: 4
                Repeater {
                    model: ["Super", "Ctrl", "V"]
                    delegate: Rectangle {
                        required property string modelData
                        width: keyText.implicitWidth + 16
                        height: 26
                        radius: 7
                        color: Cc.theme.bgSurface
                        border.color: Cc.theme.bgBorder
                        border.width: 1
                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 2; radius: 1; color: Cc.theme.bgBorder }
                        Text {
                            id: keyText
                            anchors.centerIn: parent
                            text: modelData
                            color: Cc.theme.textPrimary
                            font.family: Cc.mono
                            font.pixelSize: 11
                        }
                    }
                }
            }
            Text {
                text: "Open the clipboard history"
                color: Cc.theme.textSecondary
                font.family: Cc.sans
                font.pixelSize: 12
            }
        }
    }
}
