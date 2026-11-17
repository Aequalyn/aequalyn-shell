// One page of the control center: a plain title and a line saying what the page is
// for, an optional row of sub pages, then the page itself, which scrolls.
//
// A sub page set in `fills` holds one big piece that scrolls by itself (an Atelier
// pane); it then takes the whole height instead of scrolling with the page.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "root:/settings"
import "../../Plugins.js" as PluginRegistry
import "../../PluginInfo.js" as PluginInfo

Item {
    id: page
    property string title: ""
    // a plugin's own page: its id (Plugins.js). The page then opens with the plugin's
    // strip: what it does, the key that calls it up, and its on/off switch (see PLUGINS.md)
    property string plugin: ""
    readonly property var pluginInfo: PluginInfo.of(plugin)
    readonly property var pluginEntry: plugin !== "" ? (PluginRegistry.list.find(p => p.id === plugin) || null) : null
    readonly property bool pluginOn: plugin !== "" && AequalynSettings.enabledPlugins.indexOf(plugin) >= 0
    property string sub: ""
    property var tabs: []           // names of the sub pages, if any
    property int tab: 0
    property var fills: []          // the sub pages that fill the page
    default property alias content: body.data
    property alias actions: actionRow.data
    // A live picture pinned under the title: it stays put while the choices below scroll,
    // and changes as they do. `stageHeight` 0 means none; `stageTabs` limits it to some
    // sub pages (empty: all of them).
    property alias stage: stageHolder.data
    property int stageHeight: 0
    property var stageTabs: []
    readonly property bool hasStage: stageHeight > 0 && (stageTabs.length === 0 || stageTabs.indexOf(tab) >= 0)

    readonly property bool fill: fills.indexOf(tab) >= 0
    // the sub pages opened so far: a heavy one can be made only once it is first opened
    // (a Loader with `active: page.opened(i)`), then kept
    property var seen: [0]
    // `settled` turns true a moment after the page is made: heavy parts wait for it, so the
    // pinned picture paints first instead of together with dozens of cards
    property bool settled: false
    Timer { interval: 60; running: true; onTriggered: page.settled = true }
    function opened(i) { return settled && seen.indexOf(i) >= 0; }
    onTabChanged: {
        flick.contentY = 0;
        if (seen.indexOf(tab) < 0) seen = seen.concat([tab]);
    }

    ColumnLayout {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Text {
                    text: page.title
                    color: Cc.theme.textPrimary
                    font.family: Cc.sans
                    font.pixelSize: 24
                    font.weight: Font.DemiBold
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
                Text {
                    visible: page.sub !== ""
                    text: page.sub
                    color: Cc.theme.textMuted
                    font.family: Cc.sans
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }
            RowLayout {
                id: actionRow
                Layout.alignment: Qt.AlignTop
                spacing: 8
            }
        }

        // a plugin's own page: the plugin, on or off
        Rectangle {
            visible: page.plugin !== ""
            Layout.fillWidth: true
            implicitHeight: 58
            radius: 12
            color: Cc.theme.bgSurface
            border.width: 1
            border.color: page.pluginOn ? Cc.alpha(Cc.theme.accentPrimary, 0.35) : Cc.theme.bgBorder
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 14
                spacing: 12
                Rectangle {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    radius: 10
                    color: Cc.theme.bgBase
                    Text {
                        anchors.centerIn: parent
                        text: page.pluginInfo.icon
                        color: Cc.theme.accentPrimary
                        font.family: Cc.mono
                        font.pixelSize: 17
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        Layout.fillWidth: true
                        text: (page.pluginEntry ? page.pluginEntry.label : page.title) + (page.pluginOn ? "  ·  on" : "  ·  off")
                        color: Cc.theme.textPrimary
                        font.family: Cc.sans
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: page.pluginOn ? page.pluginInfo.about
                            : "Turned off: nothing of it runs, and the settings below wait until it is back on."
                        color: Cc.theme.textMuted
                        font.family: Cc.sans
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                }
                Rectangle {
                    visible: page.pluginInfo.keys !== ""
                    implicitWidth: pluginKeys.implicitWidth + 14
                    implicitHeight: 22
                    radius: 6
                    color: Cc.theme.bgBase
                    border.width: 1
                    border.color: Cc.theme.bgBorder
                    Text {
                        id: pluginKeys
                        anchors.centerIn: parent
                        text: page.pluginInfo.keys
                        color: Cc.theme.textSecondary
                        font.family: Cc.mono
                        font.pixelSize: 10
                    }
                }
                CcSwitch {
                    checked: page.pluginOn
                    onToggled: v => AequalynSettings.togglePlugin(page.plugin, v)
                }
            }
        }

        // the sub pages, as a segmented row
        Rectangle {
            visible: page.tabs.length > 0
            implicitWidth: segs.implicitWidth + 8
            implicitHeight: 40
            radius: 12
            color: Cc.theme.bgSurface
            Row {
                id: segs
                anchors.centerIn: parent
                spacing: 4
                Repeater {
                    model: page.tabs
                    delegate: Rectangle {
                        required property string modelData
                        required property int index
                        readonly property bool on: page.tab === index
                        width: segText.implicitWidth + 32
                        height: 32
                        radius: 9
                        color: on ? Cc.theme.accentPrimary : (segArea.containsMouse ? Cc.theme.bgHover : "transparent")
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                            id: segText
                            anchors.centerIn: parent
                            text: modelData
                            color: parent.on ? Cc.theme.bgBase : Cc.theme.textSecondary
                            font.family: Cc.sans
                            font.pixelSize: 12
                            font.weight: parent.on ? Font.DemiBold : Font.Normal
                        }
                        MouseArea {
                            id: segArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.tab = index
                        }
                    }
                }
            }
        }
    }

    Item {
        id: stageHolder
        anchors.top: header.bottom
        anchors.topMargin: page.hasStage ? 18 : 0
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.rightMargin: 14
        height: page.hasStage ? page.stageHeight : 0
        visible: page.hasStage
    }

    Flickable {
        id: flick
        anchors.top: stageHolder.bottom
        anchors.topMargin: page.hasStage ? 16 : 20
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        interactive: !page.fill
        boundsBehavior: Flickable.StopAtBounds
        contentWidth: width
        contentHeight: page.fill ? height : body.implicitHeight + 24
        ScrollBar.vertical: ScrollBar { policy: page.fill ? ScrollBar.AlwaysOff : ScrollBar.AsNeeded }

        ColumnLayout {
            id: body
            width: flick.width - (page.fill ? 0 : 14)
            height: page.fill ? flick.height : implicitHeight
            spacing: 22
        }
    }
}
