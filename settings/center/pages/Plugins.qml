// Plugins: the parts of the desktop, each on or off, grouped by where they live: on
// screen, opened with a key, or in the background. Each card says what it does, the
// key that calls it up and, when it has one, opens its own page. A switch applies at
// once: the plugin loads or leaves without a restart. What each card says comes from
// PluginInfo.js; the list itself is Plugins.js.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/settings"
import "../../../Plugins.js" as PluginRegistry
import "../../../PluginInfo.js" as PluginInfo
import ".."

CcPage {
    id: page
    title: "Plugins"
    sub: "The parts of your desktop. Turn off what you don't use: it leaves at once, and comes back when you turn it on."

    // this window itself is a plugin too, but turning it off here would lock you out
    readonly property var plugins: PluginRegistry.list.filter(p => p.id !== "settings")
    function isOn(id) { return AequalynSettings.enabledPlugins.indexOf(id) >= 0; }
    readonly property int onCount: plugins.filter(p => isOn(p.id)).length

    // what the list shows
    property string filter: "all"
    function shows(p) {
        const i = PluginInfo.of(p.id);
        if (page.filter === "on") return page.isOn(p.id);
        if (page.filter === "off") return !page.isOn(p.id);
        if (page.filter === "keys") return i.keys !== "";
        if (page.filter === "page") return i.page !== "";
        return true;
    }

    CcChoice {
        options: [
            { key: "all", label: "All " + page.plugins.length },
            { key: "on", label: "On " + page.onCount },
            { key: "off", label: "Off " + (page.plugins.length - page.onCount) },
            { key: "keys", label: "Has a shortcut " + page.plugins.filter(p => PluginInfo.of(p.id).keys !== "").length },
            { key: "page", label: "Has its own page " + page.plugins.filter(p => PluginInfo.of(p.id).page !== "").length }
        ]
        current: page.filter
        onChosen: key => page.filter = key
    }

    Repeater {
        model: PluginInfo.groups
        delegate: CcSection {
            id: group
            required property var modelData
            readonly property var members: page.plugins.filter(p => PluginInfo.of(p.id).group === group.modelData.key && page.shows(p))
            visible: members.length > 0
            title: modelData.title + " · " + members.length
            hint: modelData.hint
            GridLayout {
                Layout.fillWidth: true
                columns: Math.max(1, Math.floor(width / 330))
                columnSpacing: 10
                rowSpacing: 10
                Repeater {
                    model: group.members
                    delegate: PluginCard {
                        required property var modelData
                        Layout.fillWidth: true
                        plugin: modelData
                    }
                }
            }
        }
    }

    CcNote {
        visible: page.plugins.filter(p => page.shows(p)).length === 0
        text: "Nothing here with this filter."
    }
    CcNote {
        text: "Make your own: a plugin is a folder under plugins/ in the shell's folder, a line in Plugins.js and one in PluginInfo.js. PLUGINS.md there sets out how, so it looks and works like these."
    }

    // ---- one plugin -------------------------------------------------------------------
    component PluginCard: Rectangle {
        id: card
        property var plugin: ({})
        readonly property var info: PluginInfo.of(plugin.id)
        readonly property bool on: page.isOn(plugin.id)
        implicitHeight: 92
        radius: 12
        color: cardArea.containsMouse && info.page !== "" ? Cc.theme.bgHover : Cc.theme.bgSurface
        border.width: 1
        border.color: on ? Cc.alpha(Cc.theme.accentPrimary, 0.35) : Cc.theme.bgBorder
        Accessible.role: Accessible.CheckBox
        Accessible.name: plugin.label
        Accessible.checked: on

        MouseArea {
            id: cardArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: card.info.page !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (card.info.page !== "") Cc.go(card.info.page)
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12
            Rectangle {
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                radius: 10
                color: Cc.theme.bgBase
                opacity: card.on ? 1 : 0.55
                Text {
                    anchors.centerIn: parent
                    text: card.info.icon
                    color: Cc.theme.accentPrimary
                    font.family: Cc.mono
                    font.pixelSize: 18
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: 3
                Text {
                    Layout.fillWidth: true
                    text: card.plugin.label
                    color: card.on ? Cc.theme.textPrimary : Cc.theme.textMuted
                    font.family: Cc.sans
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: card.info.about
                    color: Cc.theme.textMuted
                    font.family: Cc.sans
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
                Item { Layout.fillHeight: true }
                RowLayout {
                    spacing: 8
                    Rectangle {
                        visible: card.info.keys !== ""
                        implicitWidth: keyText.implicitWidth + 14
                        implicitHeight: 20
                        radius: 6
                        color: Cc.theme.bgBase
                        border.width: 1
                        border.color: Cc.theme.bgBorder
                        Text {
                            id: keyText
                            anchors.centerIn: parent
                            text: card.info.keys
                            color: Cc.theme.textSecondary
                            font.family: Cc.mono
                            font.pixelSize: 10
                        }
                    }
                    Text {
                        visible: card.info.keys === ""
                        text: "No shortcut"
                        color: Cc.theme.textMuted
                        font.family: Cc.sans
                        font.pixelSize: 10
                    }
                    Text {
                        visible: card.info.page !== ""
                        text: "Settings  ›"
                        color: Cc.theme.accentPrimary
                        font.family: Cc.sans
                        font.pixelSize: 11
                    }
                }
            }
            CcSwitch {
                Layout.alignment: Qt.AlignTop
                checked: card.on
                onToggled: v => AequalynSettings.togglePlugin(card.plugin.id, v)
            }
        }
    }
}
