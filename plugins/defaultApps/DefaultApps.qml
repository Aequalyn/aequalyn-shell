// Per-category default app chooser overlay, opened with Super + Alt + A.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "root:/plugins/appLauncher"
import "root:/settings/center"
import "root:/style/backdrop"

Scope {
    id: root
    property var theme: DefaultTheme {}
    property string font: "JetBrainsMono Nerd Font"
    property bool open: false
    property string activeCategory: "browser"
    property bool appPaneFocused: false
    property int selectedChoiceIndex: 0
    readonly property var activeMeta: apps.categories.find(c => c.key === activeCategory) || apps.categories[0]
    readonly property var activeChoices: activeMeta ? apps.choices(activeMeta.key) : []

    function stepCategory(delta) {
        const categories = apps.categories;
        if (!categories.length) return;
        let index = categories.findIndex(c => c.key === root.activeCategory);
        index = (Math.max(0, index) + delta + categories.length) % categories.length;
        root.activeCategory = categories[index].key;
        root.appPaneFocused = false;
        root.selectedChoiceIndex = 0;
    }
    function focusChoices() {
        root.appPaneFocused = true;
        const current = root.activeChoices.findIndex(a => a.key === (apps.current[root.activeCategory] || ""));
        root.selectedChoiceIndex = Math.max(0, current);
    }
    function chooseFocused() {
        const choice = root.activeChoices[root.selectedChoiceIndex];
        if (choice) apps.set(root.activeCategory, choice.key, choice.label);
    }

    AppsService { id: apps }
    Component.onCompleted: apps.refresh()

    IpcHandler {
        target: "defaults"
        function toggle(): void {
            root.open = !root.open
            if (root.open) apps.refresh()
        }
        function open(): void { root.open = true; apps.refresh() }
        function close(): void { root.open = false }
    }

    PanelWindow {
        id: panel
        visible: veil.shown
        focusable: true
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: veil.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace: veil.layerName("default-apps")
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }

        Item {
            anchors.fill: parent
            MouseArea {
                anchors.fill: parent
                onClicked: root.open = false
                Backdrop {
                    id: veil
                    open: root.open
                    theme: root.theme
                    tintAlpha: root.theme.bgOverlay.a
                }
            }

            Rectangle {
                id: chooser
                anchors.centerIn: parent
                width: Math.min(840, parent.width * 0.92)
                height: Math.min(570, parent.height * 0.88)
                radius: 18
                color: root.theme.bgBase
                border.color: root.theme.bgBorder
                border.width: 1
                opacity: veil.progress
                scale: 0.97 + 0.03 * veil.progress
                focus: veil.open
                Keys.onEscapePressed: root.open = false
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Left) {
                        if (root.appPaneFocused) root.appPaneFocused = false;
                        else root.stepCategory(-1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Right) {
                        if (!root.appPaneFocused) root.focusChoices();
                        else root.stepCategory(1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
                        if (root.appPaneFocused && root.activeChoices.length) {
                            const step = event.key === Qt.Key_Down ? 1 : -1;
                            root.selectedChoiceIndex = (root.selectedChoiceIndex + step + root.activeChoices.length) % root.activeChoices.length;
                        } else {
                            root.stepCategory(event.key === Qt.Key_Down ? 1 : -1);
                        }
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (root.appPaneFocused) root.chooseFocused();
                        else root.focusChoices();
                        event.accepted = true;
                    }
                }

                MouseArea { anchors.fill: parent }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 22
                    spacing: 16

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Default apps"
                            color: root.theme.accentPrimary
                            font.pixelSize: 18
                            font.bold: true
                            font.family: root.font
                            Layout.fillWidth: true
                        }
                        Text {
                            text: "Choose what opens each category"
                            color: root.theme.textMuted
                            font.pixelSize: 11
                            font.family: root.font
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 12
                        color: root.theme.bgSurface
                        border.color: root.theme.bgBorder
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 12

                            ColumnLayout {
                                Layout.minimumWidth: 210
                                Layout.preferredWidth: 210
                                Layout.maximumWidth: 210
                                Layout.fillHeight: true
                                spacing: 4
                                Repeater {
                                    model: apps.categories
                                    delegate: Rectangle {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 44
                                        radius: 9
                                        color: modelData.key === root.activeCategory
                                            ? root.theme.bgSelected
                                            : categoryMouse.containsMouse ? root.theme.bgHover : "transparent"
                                        border.color: modelData.key === root.activeCategory
                                            ? root.theme.accentPrimary : "transparent"
                                        border.width: 1
                                        Text {
                                            anchors.fill: parent
                                            anchors.leftMargin: 12
                                            verticalAlignment: Text.AlignVCenter
                                            text: modelData.label
                                            color: modelData.key === root.activeCategory
                                                ? root.theme.textPrimary : root.theme.textSecondary
                                            font.pixelSize: 12
                                            font.family: root.font
                                            font.bold: modelData.key === root.activeCategory
                                        }
                                        MouseArea {
                                            id: categoryMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: { root.activeCategory = modelData.key; root.appPaneFocused = false; root.selectedChoiceIndex = 0; chooser.forceActiveFocus(); }
                                        }
                                    }
                                }
                                Item { Layout.fillHeight: true }
                            }

                            Rectangle {
                                Layout.fillHeight: true
                                width: 1
                                color: root.theme.bgBorder
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.margins: 12
                                spacing: 10

                                Text {
                                    text: root.activeMeta ? root.activeMeta.label : "Apps"
                                    color: root.theme.textPrimary
                                    font.pixelSize: 16
                                    font.bold: true
                                    font.family: root.font
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: root.activeMeta ? root.activeMeta.hint : ""
                                    color: root.theme.textMuted
                                    font.pixelSize: 11
                                    font.family: root.font
                                    wrapMode: Text.WordWrap
                                }
                                Text {
                                    text: "Current default: " + (root.activeChoices.find(a => a.key === (apps.current[root.activeCategory] || ""))?.label || "Not set")
                                    color: root.theme.textSecondary
                                    font.pixelSize: 11
                                    font.family: root.font
                                    Layout.topMargin: 8
                                }

                                Flickable {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    contentWidth: width
                                    contentHeight: appOptions.implicitHeight
                                    clip: true
                                    boundsBehavior: Flickable.StopAtBounds
                                    Flow {
                                        id: appOptions
                                        width: parent.width
                                        spacing: 8
                                        Repeater {
                                            model: root.activeChoices
                                            delegate: Rectangle {
                                                required property var modelData
                                                required property int index
                                                readonly property bool selected: modelData.key === (apps.current[root.activeCategory] || "")
                                                readonly property bool keyboardSelected: root.appPaneFocused && index === root.selectedChoiceIndex
                                                implicitWidth: optionLabel.implicitWidth + 28
                                                implicitHeight: 38
                                                radius: 10
                                                color: selected || keyboardSelected ? Qt.alpha(root.theme.accentPrimary, 0.18)
                                                    : optionMouse.containsMouse ? root.theme.bgHover : root.theme.bgBase
                                                border.color: selected || keyboardSelected ? root.theme.accentPrimary : root.theme.bgBorder
                                                border.width: 1
                                                Text {
                                                    id: optionLabel
                                                    anchors.centerIn: parent
                                                    text: modelData.label
                                                    color: selected || keyboardSelected ? root.theme.textPrimary : root.theme.textSecondary
                                                    font.pixelSize: 11
                                                    font.family: root.font
                                                }
                                                MouseArea {
                                                    id: optionMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: { root.appPaneFocused = true; root.selectedChoiceIndex = index; apps.set(root.activeCategory, modelData.key, modelData.label); chooser.forceActiveFocus(); }
                                                }
                                            }
                                        }
                                    }
                                }

                                Text {
                                    visible: root.activeCategory === "aiTool" && apps.choices("aiTool").length <= 1
                                    text: "Install an agent in Settings → AI tools, then reopen this chooser."
                                    color: root.theme.textMuted
                                    font.pixelSize: 10
                                    font.family: root.font
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Esc closes · Super + B opens your default browser · Super + E opens your default file manager"
                        color: root.theme.textMuted
                        font.pixelSize: 10
                        font.family: root.font
                    }
                }
            }
        }
    }
}
