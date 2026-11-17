// Plugins: the parts of the desktop, each on or off, grouped by where they live: on
// screen, opened with a key, or in the background. Each card says what it does, the
// key that calls it up and, when it has one, opens its own page. A switch applies at
// once: the plugin loads or leaves without a restart. What each card says comes from
// PluginInfo.js; the list itself is Plugins.js.
//
// The built-in pack's plugins are here too, marked Built-in. Opening one (its card)
// shows it alone, Plugins › Name: its switch, its key, and its settings when it has
// any (PluginSettings.qml).
import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/settings"
import "../../../Plugins.js" as PluginRegistry
import "../../../PluginInfo.js" as PluginInfo
import "root:/plugins/kit"
import ".."

CcPage {
    id: page
    // a plugin opened on its own (Plugins › Name), or "" for them all
    property string detail: ""
    readonly property var detailEntry: detail !== "" ? (PluginRegistry.list.find(p => p.id === detail) || null) : null
    title: detailEntry ? detailEntry.label : "Plugins"
    sub: detailEntry ? "Plugins › " + detailEntry.label + (PluginInfo.of(detail).pack ? " · built in" : "")
        : "The parts of your desktop. Turn off what you don't use: it leaves at once, and comes back when you turn it on."
    plugin: detail
    function open(id) {
        const i = PluginInfo.of(id)
        if (i.page !== "") Cc.go(i.page)
        else page.detail = id
    }
    // asked to open on one (a plugin's own link to its settings)
    Component.onCompleted: if (KitHost.pendingDetail !== "") { page.detail = KitHost.pendingDetail; KitHost.pendingDetail = "" }
    Connections {
        target: KitHost
        function onDetailRequested(id) { page.detail = id; KitHost.pendingDetail = "" }
    }
    onVisibleChanged: if (!visible) page.detail = ""

    // this window itself is a plugin too, but turning it off here would lock you out
    readonly property var plugins: PluginRegistry.list.filter(p => p.id !== "settings")
    function isOn(id) { return AequalynSettings.enabledPlugins.indexOf(id) >= 0; }
    readonly property int onCount: plugins.filter(p => isOn(p.id)).length

    // what the list shows
    property string filter: "all"
    function shows(p) {
        const i = PluginInfo.of(p.id);
        if (page.filter === "pack") return i.pack === true;
        if (page.filter === "on") return page.isOn(p.id);
        if (page.filter === "off") return !page.isOn(p.id);
        if (page.filter === "keys") return i.keys !== "";
        if (page.filter === "page") return i.page !== "";
        return true;
    }

    // ---- one plugin, opened -----------------------------------------------------------
    CcButton {
        visible: page.detail !== ""
        text: "All plugins"; icon: "\u{F004D}"
        onClicked: page.detail = ""
    }
    PluginSettings {
        visible: page.detail !== ""
        plugin: page.detail
    }
    CcNote {
        visible: page.detail !== "" && PluginInfo.of(page.detail).settings !== true
        text: PluginInfo.of(page.detail).keys !== ""
            ? "Nothing to set here. " + PluginInfo.of(page.detail).keys + " calls it up while it is on."
            : "Nothing to set here: it works by itself while it is on."
    }

    // ---- them all ---------------------------------------------------------------------
    CcChoice {
        visible: page.detail === ""
        options: [
            { key: "all", label: "All " + page.plugins.length },
            { key: "on", label: "On " + page.onCount },
            { key: "off", label: "Off " + (page.plugins.length - page.onCount) },
            { key: "keys", label: "Has a shortcut " + page.plugins.filter(p => PluginInfo.of(p.id).keys !== "").length },
            { key: "page", label: "Has its own page " + page.plugins.filter(p => PluginInfo.of(p.id).page !== "").length },
            { key: "pack", label: "Built-in pack " + page.plugins.filter(p => PluginInfo.of(p.id).pack === true).length }
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
            visible: page.detail === "" && members.length > 0
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
        visible: page.detail === "" && page.plugins.filter(p => page.shows(p)).length === 0
        text: "Nothing here with this filter."
    }
    CcNote {
        visible: page.detail === ""
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
        color: cardArea.containsMouse ? Cc.theme.bgHover : Cc.theme.bgSurface
        border.width: 1
        border.color: on ? Cc.alpha(Cc.theme.accentPrimary, 0.35) : Cc.theme.bgBorder
        Accessible.role: Accessible.CheckBox
        Accessible.name: plugin.label
        Accessible.checked: on

        MouseArea {
            id: cardArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: page.open(card.plugin.id)
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
                    Rectangle {
                        visible: card.info.pack === true
                        implicitWidth: packText.implicitWidth + 12
                        implicitHeight: 18
                        radius: 9
                        color: Cc.alpha(Cc.theme.accentPrimary, 0.14)
                        Text {
                            id: packText
                            anchors.centerIn: parent
                            text: "Built-in"
                            color: Cc.theme.accentPrimary
                            font.family: Cc.sans
                            font.pixelSize: 10
                        }
                    }
                    Text {
                        visible: card.info.page !== "" || card.info.settings === true
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
