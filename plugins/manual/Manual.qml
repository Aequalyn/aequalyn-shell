// Manual (Super + F1): a quick, searchable guide for Aequalyn and its common tools.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "root:/plugins/kit"
import "Content.js" as Content

Scope {
    id: root
    property var theme: null
    property string section: "keybindings"

    readonly property var current: Content.find(root.section)
    readonly property var sectionItems: Content.sections.map(s => ({
        icon: s.icon, title: s.title, sub: "Section", section: s.id
    }))

    function searchItems(q) {
        const needle = String(q || "").trim().toLowerCase()
        const out = []
        for (const s of Content.sections) {
            for (const group of s.body) {
                const groupTitle = group[0]
                for (const line of group[1]) {
                    const hay = (s.title + " " + groupTitle + " " + line).toLowerCase()
                    if (needle !== "" && hay.indexOf(needle) < 0) continue
                    out.push({
                        icon: s.icon,
                        title: line,
                        sub: s.title + " › " + groupTitle,
                        section: s.id,
                        line: line
                    })
                }
            }
        }
        return out.slice(0, 80)
    }

    KitPanel {
        id: panel
        theme: root.theme
        name: "manual"
        icon: "\u{F02D}"
        title: "Manual"
        placeholder: "Search keybindings, Aequalyn, Hyprland, Arch, Neovim..."
        panelWidth: 980
        panelHeight: 680
        emptyText: "No manual entry matches"
        chips: Content.sections.map(s => ({ key: s.id, label: s.title }))
        chip: root.section
        countText: panel.query.trim() === "" ? root.current.title : panel.items.length + (panel.items.length === 1 ? " match" : " matches")
        hints: [["↑ ↓", "move"], ["Enter", "open"], ["Tab", "section"], ["Esc", "close"]]
        items: panel.query.trim() === "" ? [] : root.searchItems(panel.query)
        body: panel.query.trim() === "" ? sectionBody : null
        onChipChosen: (key) => { root.section = key; panel.current = 0 }
        onActivated: (item) => {
            if (!item) return
            if (item.section) root.section = item.section
            if (panel.query.trim() !== "") panel.query = ""
        }
        onOpenChanged: if (open) panel.current = 0
    }

    Component {
        id: sectionBody
        RowLayout {
            spacing: 12
            Rectangle {
                Layout.preferredWidth: 230
                Layout.fillHeight: true
                radius: 12
                color: panel.c_surface
                border.width: 1
                border.color: panel.c_border
                ListView {
                    id: sectionList
                    anchors.fill: parent
                    anchors.margins: 8
                    clip: true
                    spacing: 4
                    model: Content.sections
                    currentIndex: Math.max(0, Content.sections.findIndex(s => s.id === root.section))
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: ListView.view.width
                        height: 40
                        radius: 8
                        color: root.section === modelData.id ? panel.c_selected : (area.containsMouse ? panel.c_hover : "transparent")
                        border.width: root.section === modelData.id ? 1 : 0
                        border.color: panel.c_accent
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10
                            Text { text: modelData.icon; color: panel.c_accent; font.family: panel.font; font.pixelSize: 14 }
                            Text { Layout.fillWidth: true; text: modelData.title; color: root.section === modelData.id ? panel.c_text : panel.c_text2; font.family: panel.font; font.pixelSize: 12; font.bold: root.section === modelData.id; elide: Text.ElideRight }
                        }
                        MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.section = modelData.id }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 12
                color: panel.c_surface
                border.width: 1
                border.color: panel.c_border
                Flickable {
                    id: flick
                    anchors.fill: parent
                    anchors.margins: 16
                    clip: true
                    contentWidth: width
                    contentHeight: contentCol.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { }
                    ColumnLayout {
                        id: contentCol
                        width: flick.width
                        spacing: 14
                        Text {
                            text: (root.current.icon || "") + "  " + root.current.title
                            color: panel.c_accent
                            font.family: panel.font
                            font.pixelSize: 20
                            font.bold: true
                        }
                        Repeater {
                            model: root.current.body || []
                            delegate: ColumnLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 6
                                Text {
                                    text: modelData[0]
                                    color: panel.c_text
                                    font.family: panel.font
                                    font.pixelSize: 14
                                    font.bold: true
                                }
                                Repeater {
                                    model: modelData[1] || []
                                    delegate: Rectangle {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        implicitHeight: lineText.implicitHeight + 14
                                        radius: 8
                                        color: panel.tint(panel.c_bg, 0.45)
                                        border.width: 1
                                        border.color: panel.c_border
                                        Text {
                                            id: lineText
                                            anchors.fill: parent
                                            anchors.margins: 10
                                            text: modelData
                                            textFormat: Text.PlainText
                                            wrapMode: Text.Wrap
                                            color: panel.c_text2
                                            font.family: panel.font
                                            font.pixelSize: 12
                                        }
                                    }
                                }
                            }
                        }
                        Item { Layout.fillHeight: true }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "manual"
        function toggle(): void { panel.toggle() }
        function open(section: string): void { if (section) root.section = section; panel.open = true }
    }

    Component.onCompleted: KitHost.register("manual", root)
    Component.onDestruction: KitHost.unregister("manual", root)
}
