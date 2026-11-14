// Clock: how the time shows on the bar.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/settings"
import ".."

CcPage {
    id: page
    title: "Clock"
    sub: "How the time shows on the bar."

    property date now: new Date()
    Timer { interval: 1000; repeat: true; running: true; onTriggered: page.now = new Date() }
    function format(h24, seconds) {
        return (h24 ? "HH:mm" : "h:mm") + (seconds ? ":ss" : "") + (h24 ? "" : " AP");
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.maximumWidth: 460
        implicitHeight: 130
        radius: 16
        color: Cc.theme.bgSurface
        Column {
            anchors.centerIn: parent
            spacing: 4
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(page.now, page.format(AequalynSettings.use24h, AequalynSettings.clockSeconds))
                color: Cc.theme.textPrimary
                font.family: Cc.mono
                font.pixelSize: 44
                font.weight: Font.Medium
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(page.now, "dddd d MMMM")
                color: Cc.theme.textMuted
                font.family: Cc.sans
                font.pixelSize: 13
            }
        }
    }
    CcSection {
        title: "Hours"
        CcChoice {
            setting: "use24h"
            options: [
                { key: true, label: Qt.formatDateTime(page.now, "HH:mm") + "  (24 hours)" },
                { key: false, label: Qt.formatDateTime(page.now, "h:mm AP") + "  (12 hours)" }
            ]
        }
    }
    CcToggle { setting: "clockSeconds"; title: "Show seconds" }
    CcToggle { setting: "showClock"; title: "Clock on the bar" }
}
