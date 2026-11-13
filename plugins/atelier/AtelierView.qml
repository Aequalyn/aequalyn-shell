// The whole of Atelier as one view: header, tabs, content and footer. The
// docked panel, the popped out window and the full screen overlay all show
// this same view; what it shows and does lives in Atelier.qml (`host`), so
// switching between them keeps the tab, the search and the selection.
import QtQuick
import QtQuick.Layouts
import "layouts"
import "controls"
import "root:/settings"

FocusScope {
    id: view

    property var host
    property string surface: "overlay"          // overlay | panel | window
    readonly property var theme: host.theme
    readonly property string font: host.font

    // Spotlight in full screen: the picture fills everything, header and
    // footer float over it.
    readonly property bool fullBleed: surface === "overlay" && host.spotlight
    readonly property real r: surface === "overlay" ? 18 : 14

    function focusInput() {
        if (host.searchable) searchInput.forceActiveFocus();
        else view.forceActiveFocus();
    }
    function resetLayoutsPane() {
        layoutsPane.workspace = LayoutService.focusedWorkspace;
        layoutsPane.selectActive();
    }

    Connections {
        target: view.host
        function onCollectionOpened(c) { if (c === "layouts") view.resetLayoutsPane(); }
    }
    Component.onCompleted: resetLayoutsPane()

    // ---- keys ------------------------------------------------------------
    function handleKey(event) {
        const ctrl = event.modifiers & Qt.ControlModifier;
        const shift = event.modifiers & Qt.ShiftModifier;
        const alt = event.modifiers & Qt.AltModifier;
        const cols = layoutLoader.item && layoutLoader.item.columns !== undefined ? layoutLoader.item.columns : 0;

        if (event.key === Qt.Key_Escape) {
            if (host.searchText !== "") { host.searchText = ""; searchInput.text = ""; }
            else host.close();
        } else if (event.key === Qt.Key_Tab || (alt && event.key === Qt.Key_Right)) {
            host.cycleCollection(1);
        } else if (event.key === Qt.Key_Backtab || (alt && event.key === Qt.Key_Left)) {
            host.cycleCollection(-1);
        } else if (ctrl && event.key >= Qt.Key_1 && event.key <= Qt.Key_6) {
            host.setLayout(host.layoutKeys[event.key - Qt.Key_1]);
        } else if (ctrl && event.key === Qt.Key_L) {
            host.setLayout(host.layoutKeys[(host.layoutKeys.indexOf(host.layout) + 1) % host.layoutKeys.length]);
        } else if (ctrl && event.key === Qt.Key_N) {
            host.step(1);
        } else if (ctrl && event.key === Qt.Key_P) {
            host.step(-1);
        } else if (ctrl && event.key === Qt.Key_R) {
            AtelierService.random();
        } else if (host.collection === "layouts") {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                layoutsPane.handleKey(event);
                if (!shift && host.surface === "overlay") host.close();
                return true;
            }
            return layoutsPane.handleKey(event);
        } else if (!host.browsing) {
            return false;
        } else if (event.key === Qt.Key_Left) {
            host.move(-1);
        } else if (event.key === Qt.Key_Right) {
            host.move(1);
        } else if (event.key === Qt.Key_Up) {
            host.move(cols > 0 ? -cols : -1);
        } else if (event.key === Qt.Key_Down) {
            host.move(cols > 0 ? cols : 1);
        } else if (event.key === Qt.Key_PageUp) {
            host.move(cols > 0 ? -cols * 3 : -5);
        } else if (event.key === Qt.Key_PageDown) {
            host.move(cols > 0 ? cols * 3 : 5);
        } else if (event.key === Qt.Key_Home && ctrl) {
            host.currentIndex = 0;
        } else if (event.key === Qt.Key_End && ctrl) {
            host.currentIndex = Math.max(0, host.items.length - 1);
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            // In the full screen picker Enter applies and closes, like Omarchy's
            // menus; docked or popped out it applies and stays.
            host.apply(host.currentIndex, !shift && host.surface === "overlay");
        } else {
            return false;
        }
        return true;
    }

    Keys.onPressed: event => {
        if (handleKey(event)) { event.accepted = true; return; }
        if (host.searchable && event.text && event.text.length === 1 && event.text > " ") {
            searchInput.forceActiveFocus();
            searchInput.insert(searchInput.cursorPosition, event.text);
            event.accepted = true;
        }
    }

    // ---- background --------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        radius: view.fullBleed ? 0 : view.r
        color: view.fullBleed ? "black" : view.theme.bgBase
        border.width: view.fullBleed ? 0 : 1
        border.color: view.theme.bgBorder
    }
    MouseArea { anchors.fill: parent; onClicked: view.forceActiveFocus() }

    // ---- content -------------------------------------------------------------
    Rectangle {
        id: contentCard
        anchors.top: view.fullBleed ? parent.top : headerBlock.bottom
        anchors.bottom: view.fullBleed ? parent.bottom : footer.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: view.fullBleed ? 0 : 10
        anchors.bottomMargin: view.fullBleed ? 0 : 8
        anchors.leftMargin: view.fullBleed ? 0 : 14
        anchors.rightMargin: view.fullBleed ? 0 : 14
        radius: view.fullBleed ? 0 : 12
        color: view.fullBleed ? "transparent" : Qt.rgba(view.theme.textPrimary.r, view.theme.textPrimary.g, view.theme.textPrimary.b, 0.025)
        border.width: view.fullBleed ? 0 : 1
        border.color: Qt.rgba(view.theme.textPrimary.r, view.theme.textPrimary.g, view.theme.textPrimary.b, 0.07)
        clip: true

        Item {
            id: body
            anchors.fill: parent
            anchors.margins: view.fullBleed ? 0 : 12

            Loader {
                id: layoutLoader
                anchors.fill: parent
                active: view.host.browsing
                sourceComponent: {
                    switch (view.host.layout) {
                    case "carousel": return carouselC;
                    case "filmstrip": return filmstripC;
                    case "radial": return radialC;
                    case "list": return listC;
                    case "spotlight": return spotlightC;
                    default: return gridC;
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: view.host.browsing && view.host.items.length === 0
                horizontalAlignment: Text.AlignHCenter
                text: AtelierService.loading ? "Looking for wallpapers…"
                    : view.host.searchText !== "" ? "Nothing matches “" + view.host.searchText + "”"
                    : view.host.collection === "wallpapers" ? "󰋩  No wallpapers yet\nAdd images to " + (AequalynSettings.wallpaperCfg.folder || "~/Pictures/Wallpapers")
                    : "No themes found"
                color: view.theme.textMuted
                font.family: view.font
                font.pixelSize: 13
            }

            LayoutsPane {
                id: layoutsPane
                anchors.fill: parent
                visible: view.host.collection === "layouts"
                theme: view.theme
                font: view.font
                searchText: view.host.collection === "layouts" ? view.host.searchText : ""
            }
            RotationPane {
                anchors.fill: parent
                visible: view.host.collection === "rotation"
                theme: view.theme
                font: view.font
            }
            PalettePane {
                anchors.fill: parent
                visible: view.host.collection === "palette"
                theme: view.theme
                font: view.font
            }
            BarPane {
                anchors.fill: parent
                visible: view.host.collection === "bar"
                theme: view.theme
                font: view.font
            }
            DocksPane {
                anchors.fill: parent
                visible: view.host.collection === "docks"
                theme: view.theme
                font: view.font
            }
            PanelPane {
                anchors.fill: parent
                visible: view.host.collection === "panel"
                host: view.host
                theme: view.theme
                font: view.font
            }
        }
    }

    // ---- header --------------------------------------------------------------
    Rectangle {
        id: headerBlock
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: view.fullBleed ? 20 : 0
        height: headerCol.implicitHeight + 28
        radius: view.fullBleed ? 16 : view.r
        color: view.fullBleed ? Qt.rgba(view.theme.bgBase.r, view.theme.bgBase.g, view.theme.bgBase.b, 0.88) : "transparent"

        ColumnLayout {
            id: headerCol
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            // Card: badge, title + status, buttons
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: titleRow.implicitHeight + 22
                radius: 12
                color: Qt.rgba(view.theme.textPrimary.r, view.theme.textPrimary.g, view.theme.textPrimary.b, 0.05)
                border.width: 1
                border.color: Qt.rgba(view.theme.textPrimary.r, view.theme.textPrimary.g, view.theme.textPrimary.b, 0.08)

                RowLayout {
                    id: titleRow
                    anchors.fill: parent
                    anchors.margins: 11
                    spacing: 10

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: 2
                        Text {
                            Layout.fillWidth: true
                            text: "Atelier"
                            color: view.theme.textPrimary
                            font.family: view.font
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: view.host.statusLine
                            color: view.theme.textMuted
                            font.family: view.font
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }

                    HeaderButton { view: view; text: "‹"; square: true; onClicked: view.host.step(-1) }
                    HeaderButton { view: view; text: "›"; square: true; onClicked: view.host.step(1) }
                    HeaderButton {
                        view: view
                        primary: view.host.confirmReset
                        text: view.host.confirmReset ? "Really reset?" : "Reset all"
                        onClicked: view.host.resetAll()
                    }
                    HeaderButton {
                        view: view
                        visible: view.surface !== "panel"
                        enabled: view.host.canDock
                        opacity: enabled ? 1 : 0.45
                        text: "Dock"
                        onClicked: view.host.dock()
                    }
                    HeaderButton {
                        view: view
                        visible: view.surface !== "window"
                        text: "Pop out"
                        onClicked: view.host.popOut()
                    }
                    HeaderButton {
                        view: view
                        visible: view.surface !== "overlay"
                        text: "Full screen"
                        onClicked: view.host.fullscreen()
                    }
                    HeaderButton { view: view; text: "×"; square: true; onClicked: view.host.close() }
                }
            }

            // Tabs, search, layout picker
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Row {
                    id: tabs
                    spacing: 2
                    Repeater {
                        model: view.host.collections
                        Item {
                            id: tab
                            required property var modelData
                            readonly property bool on: view.host.collection === modelData.key
                            width: tabText.implicitWidth + 26
                            height: 32
                            Row {
                                id: tabText
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    text: tab.modelData.icon
                                    color: tab.on ? view.theme.accentPrimary : view.theme.textMuted
                                    font.family: view.font
                                    font.pixelSize: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: tab.modelData.name
                                    color: tab.on ? view.theme.textPrimary : (tabArea.containsMouse ? view.theme.textSecondary : view.theme.textMuted)
                                    font.family: view.font
                                    font.pixelSize: 12
                                    font.weight: tab.on ? Font.DemiBold : Font.Normal
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width - 8
                                height: 2
                                radius: 1
                                color: tab.on ? view.theme.accentPrimary : "transparent"
                            }
                            MouseArea {
                                id: tabArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { view.host.setCollection(tab.modelData.key); Qt.callLater(view.focusInput); }
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }
            }

            // Filters, count, search and the view picker
            RowLayout {
                visible: view.host.searchable
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: view.host.browsing ? view.host.filters : []
                    Chip {
                        required property var modelData
                        theme: view.theme
                        font: view.font
                        compact: true
                        text: modelData[1]
                        selected: view.host.filter === modelData[0]
                        onClicked: view.host.setFilter(modelData[0])
                    }
                }
                Text {
                    visible: view.host.browsing
                    Layout.leftMargin: 6
                    text: layoutPicker.hoveredName !== "" ? layoutPicker.hoveredName
                        : view.host.items.length + (view.host.collection === "themes" ? " themes" : " wallpapers")
                    color: view.theme.textMuted
                    font.family: view.font
                    font.pixelSize: 11
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    visible: view.host.searchable
                    Layout.preferredWidth: Math.min(260, view.width * 0.22)
                    Layout.preferredHeight: 32
                    radius: 9
                    color: view.theme.bgSurface
                    border.color: searchInput.activeFocus ? view.theme.accentPrimary : view.theme.bgBorder
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8
                        Text { text: "󰍉"; color: view.theme.textMuted; font.family: view.font; font.pixelSize: 13 }
                        Item {
                            Layout.fillWidth: true
                            implicitHeight: searchInput.implicitHeight
                            TextInput {
                                id: searchInput
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: view.host.searchText
                                color: view.theme.textPrimary
                                font.family: view.font
                                font.pixelSize: 12
                                clip: true
                                selectByMouse: true
                                onTextChanged: if (text !== view.host.searchText) view.host.search(text)
                                Keys.onPressed: event => { if (view.handleKey(event)) event.accepted = true; }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: searchInput.text === ""
                                text: view.host.collection === "themes" ? "Search themes…"
                                    : view.host.collection === "layouts" ? "Search layouts…" : "Search wallpapers…"
                                color: view.theme.textMuted
                                font.family: view.font
                                font.pixelSize: 12
                            }
                        }
                    }
                }

                LayoutPicker {
                    id: layoutPicker
                    visible: view.host.browsing
                    theme: view.theme
                    font: view.font
                    current: view.host.layout
                    onChosen: name => view.host.setLayout(name)
                }
            }
        }
    }

    // ---- footer --------------------------------------------------------------
    Rectangle {
        id: footer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: view.fullBleed ? 20 : 0
        anchors.bottomMargin: view.fullBleed ? 176 : 0
        height: 40
        radius: view.fullBleed ? 14 : view.r
        color: view.fullBleed ? Qt.rgba(view.theme.bgBase.r, view.theme.bgBase.g, view.theme.bgBase.b, 0.88) : "transparent"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 8

            Rectangle {
                implicitWidth: escText.implicitWidth + 12
                implicitHeight: 18
                radius: 4
                color: Qt.rgba(view.theme.textPrimary.r, view.theme.textPrimary.g, view.theme.textPrimary.b, 0.08)
                Text { id: escText; anchors.centerIn: parent; text: "Esc"; color: view.theme.textMuted; font.family: view.font; font.pixelSize: 10 }
            }
            Text { text: "close"; color: view.theme.textMuted; opacity: 0.8; font.family: view.font; font.pixelSize: 10 }
            Text {
                Layout.fillWidth: true
                text: view.host.changed === 0 ? "All defaults"
                    : view.host.changed === 1 ? "1 setting changed" : view.host.changed + " settings changed"
                color: view.theme.textMuted
                opacity: 0.8
                elide: Text.ElideRight
                font.family: view.font
                font.pixelSize: 10
            }
            Text {
                text: view.host.browsing ? "⏎  apply  ·  Ctrl+1–6  view  ·  Alt+← →  tabs  ·  changes show right away"
                    : view.host.collection === "layouts" ? "⏎  apply  ·  Ctrl+Space  in Super + L  ·  Alt+← →  tabs"
                    : "Ctrl+N / P  next / previous wallpaper  ·  Alt+← →  tabs  ·  changes show right away"
                color: view.theme.textMuted
                opacity: 0.8
                font.family: view.font
                font.pixelSize: 10
            }
        }
    }

    // ---- layouts -------------------------------------------------------------
    Component {
        id: gridC
        LayoutGrid {
            theme: view.theme; font: view.font; items: view.host.items; currentIndex: view.host.currentIndex
            onHovered: i => view.host.currentIndex = i
            onPicked: i => view.host.apply(i, false)
        }
    }
    Component {
        id: carouselC
        LayoutCarousel {
            theme: view.theme; font: view.font; items: view.host.items; currentIndex: view.host.currentIndex
            onHovered: i => view.host.currentIndex = i
            onPicked: i => view.host.apply(i, false)
        }
    }
    Component {
        id: filmstripC
        LayoutFilmstrip {
            theme: view.theme; font: view.font; items: view.host.items; currentIndex: view.host.currentIndex
            onHovered: i => view.host.currentIndex = i
            onPicked: i => view.host.apply(i, false)
        }
    }
    Component {
        id: radialC
        LayoutRadial {
            theme: view.theme; font: view.font; items: view.host.items; currentIndex: view.host.currentIndex
            onHovered: i => view.host.currentIndex = i
            onPicked: i => view.host.apply(i, false)
        }
    }
    Component {
        id: listC
        LayoutList {
            theme: view.theme; font: view.font; items: view.host.items; currentIndex: view.host.currentIndex
            onHovered: i => view.host.currentIndex = i
            onPicked: i => view.host.apply(i, false)
        }
    }
    Component {
        id: spotlightC
        LayoutSpotlight {
            theme: view.theme; font: view.font; items: view.host.items; currentIndex: view.host.currentIndex
            onHovered: i => view.host.currentIndex = i
            onPicked: i => view.host.apply(i, false)
        }
    }
}
