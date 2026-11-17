// Weather's quick panel: a right click on the bar's weather. Now, and the next days;
// a refresh; last, its settings (the place and the units) in Plugins.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/plugins/bar/quick"
import "root:/plugins/kit"

QuickPopup {
    id: q
    required property var bar
    readonly property var svc: KitHost.get("weather")
    readonly property var now: svc ? svc.now : null

    glyph: now ? now.icon : "\u{F0599}"
    title: now && now.place !== "" ? now.place : "Weather"
    sub: !svc ? "Turned off" : svc.error !== "" ? svc.error : now ? now.text : "Looking it up"
    settingsLabel: "Weather settings"
    onSettingsClicked: { q.dismissed(); KitHost.openSettings("weather") }
    actions: [
        QuickRound { small: true; glyph: "\u{F0450}"; tip: "Look again"; enabled: !!q.svc; onClicked: q.svc.fetch() }
    ]

    QuickCard {
        visible: !!q.now
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Text {
                text: q.now ? q.now.icon : ""
                color: Quick.theme.accentPrimary
                font.family: Quick.mono
                font.pixelSize: 40
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    text: q.now ? q.now.temp : ""
                    color: Quick.theme.textPrimary
                    font.family: Quick.mono
                    font.pixelSize: 32
                    font.weight: Font.Medium
                }
                Text {
                    Layout.fillWidth: true
                    text: q.now ? "Feels like " + q.now.feels : ""
                    color: Quick.theme.textMuted
                    font.family: Quick.sans
                    font.pixelSize: 11
                }
            }
        }
    }

    QuickLabel { visible: !!q.svc && q.svc.days.length > 0; text: "The next days" }
    QuickCard {
        visible: !!q.svc && q.svc.days.length > 0
        spacing: 6
        Repeater {
            model: q.svc ? q.svc.days : []
            delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 10
                Text {
                    Layout.preferredWidth: 78
                    text: Qt.formatDate(new Date(modelData.date + "T12:00:00"), "dddd")
                    color: Quick.theme.textPrimary
                    font.family: Quick.sans
                    font.pixelSize: 12
                }
                Text {
                    text: modelData.icon
                    color: Quick.theme.accentPrimary
                    font.family: Quick.mono
                    font.pixelSize: 15
                }
                Text {
                    Layout.fillWidth: true
                    text: modelData.text
                    color: Quick.theme.textMuted
                    font.family: Quick.sans
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
                Text {
                    text: modelData.min + " – " + modelData.max
                    color: Quick.theme.textSecondary
                    font.family: Quick.mono
                    font.pixelSize: 11
                }
            }
        }
    }
}
