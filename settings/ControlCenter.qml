// The control center: every setting of the desktop in one window, in plain words.
// Each page starts with a picture of what it changes, then the choices, with the
// rarely needed ones folded under "More options". The search at the top finds any
// setting by what you type ("bigger bar", "headphones", "dark").
//
// Opens over the blurred desktop: Super + comma, the bar's gear, or
//   qs ipc call aequalyn settings            toggle
//   qs ipc call aequalyn page <name>         open a page (see center/Pages.js)
//   qs ipc call aequalyn wifi | bluetooth | bar | dock | ...   the same, by name
//
// Keys: type to search (Ctrl+K or / from anywhere), ↑ ↓ between pages, Esc closes.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "root:/settings"
import "center"
import "center/Pages.js" as Pages

Scope {
    id: root
    property var theme: AequalynDefaultTheme {}
    property bool panelVisible: false
    property string page: "home"
    readonly property string version: "0.1.0"

    // pages and the controls read the palette from here
    Binding { target: Cc; property: "theme"; value: root.theme }
    Binding { target: Cc; property: "apps"; value: apps }
    Binding { target: Cc; property: "updates"; value: updates }
    Binding { target: Cc; property: "backup"; value: backup }
    Connections {
        target: Cc
        function onGoRequested(p) { root.open(p); }
        function onCloseRequested() { root.panelVisible = false; }
    }

    AppsService { id: apps }
    UpdatesService { id: updates }
    BackupService { id: backup }
    Component.onCompleted: updates.refresh()

    // the wallpaper on the screen right now, for the pictures on the pages
    FileView {
        id: wallpaperFile
        path: Quickshell.env("HOME") + "/.config/quickshell/wallpaper.conf"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: Cc.wallpaper = text().trim()
    }

    function open(name) {
        const p = Pages.resolve(name || "home");
        if (p !== "") root.page = p;
        root.panelVisible = true;
    }
    function step(delta) {
        const i = Pages.order.indexOf(root.page);
        root.page = Pages.order[Math.max(0, Math.min(Pages.order.length - 1, i + delta))];
    }

    IpcHandler {
        target: "aequalyn"
        function settings(): void { root.panelVisible = !root.panelVisible }
        function openSettings(): void { root.panelVisible = true }
        function closeSettings(): void { root.panelVisible = false }
        function page(name: string): void { root.open(name) }
        function setDefault(category: string, appId: string): void { apps.set(category, appId, appId) }
        // the page names older parts of the shell use
        function appearance(): void { root.open("theme") }
        function defaultApps(): void { root.open("apps") }
        function displays(): void { root.open("screens") }
        function bluetooth(): void { root.open("bluetooth") }
        function wifi(): void { root.open("wifi") }
        function hyprland(): void { root.open("windows") }
        function bar(): void { root.open("bar") }
        function dock(): void { root.open("dock") }
        function updates(): void { root.open("updates") }
        function power(): void { root.open("sleep") }
    }

    PanelWindow {
        id: win
        visible: root.panelVisible
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "aequalyn-settings"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }

        onVisibleChanged: {
            if (visible) { search.text = ""; keys.forceActiveFocus(); backup.refresh(); }
        }

        Item {
            id: keys
            anchors.fill: parent
            focus: true

            Keys.onPressed: event => {
                const ctrl = event.modifiers & Qt.ControlModifier;
                if (event.key === Qt.Key_Escape) { root.panelVisible = false; event.accepted = true; }
                else if ((ctrl && event.key === Qt.Key_K) || event.key === Qt.Key_Slash) { search.forceActiveFocus(); event.accepted = true; }
                else if (event.key === Qt.Key_Up || (ctrl && event.key === Qt.Key_Backtab)) { root.step(-1); event.accepted = true; }
                else if (event.key === Qt.Key_Down || (ctrl && event.key === Qt.Key_Tab)) { root.step(1); event.accepted = true; }
                // just start typing: it goes to the search
                else if (!ctrl && event.text.length === 1 && event.text > " ") {
                    search.text += event.text;
                    search.forceActiveFocus();
                    event.accepted = true;
                }
            }

            // the desktop behind, dimmed (and blurred by the layer rule); a click closes
            MouseArea {
                anchors.fill: parent
                onClicked: root.panelVisible = false
                Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.35) }
            }

            Rectangle {
                id: card
                anchors.centerIn: parent
                width: Math.min(1320, parent.width * 0.9)
                height: Math.min(900, parent.height * 0.9)
                radius: 20
                color: Cc.theme.bgBase
                border.color: Cc.theme.bgBorder
                border.width: 1
                clip: true
                MouseArea { anchors.fill: parent; onClicked: keys.forceActiveFocus() }

                // ---- title bar: name, search, close ---------------------------------
                Item {
                    id: titleBar
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 68

                    Row {
                        id: brand
                        anchors.left: parent.left
                        anchors.leftMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10
                        Rectangle {
                            width: 30; height: 30; radius: 9
                            color: Cc.theme.accentPrimary
                            Text {
                                anchors.centerIn: parent
                                text: "æ"
                                color: Cc.theme.bgBase
                                font.family: Cc.sans
                                font.pixelSize: 16
                                font.bold: true
                            }
                        }
                        Text {
                            text: "Aequalyn"
                            color: Cc.theme.textPrimary
                            font.family: Cc.sans
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Rectangle {
                        id: searchBox
                        anchors.left: parent.left
                        anchors.leftMargin: 236
                        anchors.right: closeButton.left
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        height: 42
                        radius: 12
                        color: Cc.theme.bgSurface
                        border.width: search.activeFocus ? 2 : 1
                        border.color: search.activeFocus ? Cc.theme.accentPrimary : Cc.theme.bgBorder

                        Text {
                            id: searchIcon
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            text: "\u{F0349}"
                            color: Cc.theme.accentPrimary
                            font.family: Cc.mono
                            font.pixelSize: 16
                        }
                        TextInput {
                            id: search
                            anchors.left: searchIcon.right
                            anchors.leftMargin: 10
                            anchors.right: keyHint.left
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            color: Cc.theme.textPrimary
                            font.family: Cc.sans
                            font.pixelSize: 14
                            clip: true
                            selectByMouse: true
                            property int pick: 0
                            readonly property var results: Pages.search(text)
                            onTextChanged: pick = 0
                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Escape) {
                                    if (text !== "") text = "";
                                    else keys.forceActiveFocus();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Down) {
                                    pick = Math.min(results.length - 1, pick + 1); event.accepted = true;
                                } else if (event.key === Qt.Key_Up) {
                                    pick = Math.max(0, pick - 1); event.accepted = true;
                                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    if (results.length > 0) root.goTo(results[pick].page);
                                    event.accepted = true;
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: search.text === ""
                                text: "What would you like to change?"
                                color: Cc.theme.textMuted
                                font: search.font
                            }
                        }
                        Text {
                            id: keyHint
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            text: "ctrl k"
                            color: Cc.theme.textMuted
                            font.family: Cc.mono
                            font.pixelSize: 11
                        }
                    }

                    Rectangle {
                        id: closeButton
                        anchors.right: parent.right
                        anchors.rightMargin: 18
                        anchors.verticalCenter: parent.verticalCenter
                        width: 34; height: 34; radius: 10
                        color: closeArea.containsMouse ? Cc.theme.bgHover : "transparent"
                        Accessible.role: Accessible.Button
                        Accessible.name: "Close"
                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            color: Cc.theme.textSecondary
                            font.family: Cc.sans
                            font.pixelSize: 14
                        }
                        MouseArea {
                            id: closeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.panelVisible = false
                        }
                    }
                }
                Rectangle { anchors.top: titleBar.bottom; width: parent.width; height: 1; color: Cc.theme.bgBorder }

                // ---- sidebar ---------------------------------------------------------
                Flickable {
                    id: side
                    anchors.left: parent.left
                    anchors.top: titleBar.bottom
                    anchors.topMargin: 1
                    anchors.bottom: footer.top
                    width: 228
                    contentHeight: nav.implicitHeight + 24
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: nav
                        x: 12
                        y: 12
                        width: side.width - 24
                        spacing: 2
                        Repeater {
                            model: Pages.groups
                            delegate: Column {
                                id: grp
                                required property var modelData
                                width: nav.width
                                spacing: 2
                                Text {
                                    visible: grp.modelData.title !== ""
                                    leftPadding: 10
                                    topPadding: 14
                                    bottomPadding: 4
                                    text: grp.modelData.title.toUpperCase()
                                    color: Cc.theme.textMuted
                                    font.family: Cc.mono
                                    font.pixelSize: 10
                                    font.letterSpacing: 1
                                }
                                Repeater {
                                    model: grp.modelData.pages
                                    delegate: Rectangle {
                                        id: navItem
                                        required property string modelData
                                        readonly property var info: Pages.pages[modelData]
                                        readonly property bool on: root.page === modelData
                                        width: nav.width
                                        height: 36
                                        radius: 10
                                        color: on ? Cc.theme.bgSelected : (navArea.containsMouse ? Cc.theme.bgSurface : "transparent")
                                        Accessible.role: Accessible.PageTab
                                        Accessible.name: info.label
                                        Row {
                                            anchors.left: parent.left
                                            anchors.leftMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 10
                                            Rectangle {
                                                width: 24; height: 24; radius: 7
                                                color: navItem.on ? Cc.theme.accentPrimary : Cc.theme.bgSurface
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: navItem.info.icon
                                                    color: navItem.on ? Cc.theme.bgBase : Cc.theme.accentPrimary
                                                    font.family: Cc.mono
                                                    font.pixelSize: 13
                                                }
                                            }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: navItem.info.label
                                                color: navItem.on ? Cc.theme.textPrimary : Cc.theme.textSecondary
                                                font.family: Cc.sans
                                                font.pixelSize: 13
                                                font.weight: navItem.on ? Font.DemiBold : Font.Normal
                                            }
                                        }
                                        MouseArea {
                                            id: navArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.goTo(navItem.modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                Rectangle { anchors.left: side.right; anchors.top: titleBar.bottom; anchors.bottom: footer.top; width: 1; color: Cc.theme.bgBorder }

                // ---- the page ------------------------------------------------------------
                Loader {
                    id: pageLoader
                    anchors.left: side.right
                    anchors.leftMargin: 32
                    anchors.right: parent.right
                    anchors.rightMargin: 22
                    anchors.top: titleBar.bottom
                    anchors.topMargin: 26
                    anchors.bottom: footer.top
                    anchors.bottomMargin: 4
                    // pages are made when shown and dropped when left, so a page's scans
                    // and timers only run while you look at it
                    active: root.panelVisible
                    source: Qt.resolvedUrl("center/pages/" + Pages.pages[root.page].file + ".qml")
                    onStatusChanged: if (status === Loader.Error) console.error("control center: page failed to load:", root.page)
                }

                // ---- footer --------------------------------------------------------------
                Rectangle {
                    id: footer
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 34
                    color: "transparent"
                    Rectangle { width: parent.width; height: 1; color: Cc.theme.bgBorder }
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        text: "↑ ↓  pages     ctrl k  search     esc  close"
                        color: Cc.theme.textMuted
                        font.family: Cc.mono
                        font.pixelSize: 10
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Changes are saved as you make them"
                        color: Cc.theme.textMuted
                        font.family: Cc.sans
                        font.pixelSize: 11
                    }
                }

                // ---- search results, over the page --------------------------------------
                Rectangle {
                    visible: search.activeFocus && search.text !== ""
                    x: searchBox.x
                    y: titleBar.height - 6
                    width: searchBox.width
                    height: resultCol.implicitHeight + 12
                    radius: 14
                    color: Cc.theme.bgSurface
                    border.color: Cc.theme.bgBorder
                    border.width: 1
                    z: 10
                    Column {
                        id: resultCol
                        x: 6; y: 6
                        width: parent.width - 12
                        Text {
                            visible: search.results.length === 0
                            width: parent.width
                            padding: 12
                            text: "Nothing matches “" + search.text + "”. Try other words, like “dark”, “bigger” or “headphones”."
                            color: Cc.theme.textMuted
                            font.family: Cc.sans
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                        }
                        Repeater {
                            model: search.results
                            delegate: Rectangle {
                                id: res
                                required property var modelData
                                required property int index
                                readonly property bool on: search.pick === index
                                width: resultCol.width
                                height: 42
                                radius: 10
                                color: on ? Cc.theme.bgSelected : "transparent"
                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 12
                                    Text {
                                        text: res.modelData.icon
                                        color: Cc.theme.accentPrimary
                                        font.family: Cc.mono
                                        font.pixelSize: 15
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: res.modelData.label
                                        color: Cc.theme.textPrimary
                                        font.family: Cc.sans
                                        font.pixelSize: 13
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                Text {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: res.modelData.where
                                    color: Cc.theme.textMuted
                                    font.family: Cc.sans
                                    font.pixelSize: 11
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: search.pick = res.index
                                    onClicked: root.goTo(res.modelData.page)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // open a page from the window itself: the search is done with
    function goTo(p) {
        root.page = p;
        search.text = "";
        keys.forceActiveFocus();
    }
}
