// The two-list picker shared by Super + I, Super + R and the Store's install
// section. The left list holds the groups; the right list follows the group
// under the cursor immediately, and a search covers every group. ↑ ↓ move in
// the active list, ← → change list, Enter runs the action on the current
// option. The same rows, colours and hairline accents make it read like a
// control center page wherever it is used.
import QtQuick
import QtQuick.Layouts
import "InstallOptions.js" as Options
import "../store/AppIcons.js" as Icons

pragma ComponentBehavior: Bound

Item {
    id: lists
    property var theme: null
    // install: everything (installed rows stay visible but cannot run);
    // remove: only choices that are here already; both: everything, with the
    // action each row can actually take. `ready` keeps both lists honest while
    // the package-manager sweep is still running.
    property string mode: "install"
    property var installed: null
    property bool ready: false
    property string query: ""
    // The Store's page has no text field under the cursor, so Delete can be a
    // remove shortcut there. In the panels Backspace belongs to the search line.
    property bool allowDeleteKey: false
    property string mono: "JetBrainsMono Nerd Font"
    property string sans: "sans-serif"
    property int categoryPick: 0
    property int optionPick: 0
    property string side: "category"         // category or option
    signal chosen(var option)
    signal removed(var option)

    function canInstall(o) {
        return lists.ready && !!o && !Options.isInstalled(o, lists.installed);
    }
    function canRemove(o) {
        return lists.ready && !!o && Options.isInstalled(o, lists.installed)
            && Options.removal(o, lists.installed).length > 0;
    }
    function actionable(o) {
        if (!o || !lists.ready) return false;
        if (lists.mode === "remove") return lists.canRemove(o);
        if (lists.mode === "both") return lists.canInstall(o) || lists.canRemove(o);
        return lists.canInstall(o);
    }
    function visibleOptions() {
        return Options.options.filter(o => lists.mode !== "remove" || lists.canRemove(o));
    }
    function categoryCount(c) {
        const pool = lists.visibleOptions();
        return c.key === "all" ? pool.length : pool.filter(o => o.category === c.key).length;
    }
    function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }

    readonly property var categoryRows: Options.categories.map(c => ({
        key: c.key, icon: c.icon,
        label: c.key === "all" ? "All options" : c.label,
        count: lists.categoryCount(c)
    }))
    readonly property var optionRows: {
        const q = String(lists.query || "").trim().toLowerCase();
        const cat = lists.categoryRows[lists.categoryPick];
        const key = cat ? cat.key : "all";
        return lists.visibleOptions().filter(o => (q !== ""
                ? Options.matches(o, q)
                : key === "all" || o.category === key))
            .map(o => ({
                option: o, icon: o.icon, title: o.label,
                // Every choice gets its own badge in the list, not the group's
                // shared glyph: initials from the name, a hue from name and id.
                badge: Icons.initials(o.label),
                badgeColor: Qt.hsla(Icons.hue(o.label + "|" + o.id) / 360, 0.42, 0.42, 1),
                sub: Options.categoryLabel(o.category) + " · " + o.source,
                installed: Options.isInstalled(o, lists.installed),
                enabled: lists.actionable(o),
                hint: Options.isInstalled(o, lists.installed) ? "Already installed"
                    : Options.related(o).length > 0 ? "See also: " + Options.related(o).join(", ") : ""
            }));
    }
    readonly property var currentOption: {
        const row = lists.optionRows[lists.optionPick];
        return row ? row.option : null;
    }
    readonly property string actionLabel: lists.mode === "remove" ? "Remove"
        : lists.mode === "both" ? "Install / Remove" : "Install"
    readonly property color cSurface: lists.theme ? lists.theme.bgSurface : "#1e1e1e"
    readonly property color cBase: lists.theme ? lists.theme.bgBase : "#141414"
    readonly property color cHover: lists.theme ? lists.theme.bgHover : "#2a2a2a"
    readonly property color cSelected: lists.theme ? lists.theme.bgSelected : "#283457"
    readonly property color cBorder: lists.theme ? lists.theme.bgBorder : "#333333"
    readonly property color cText: lists.theme ? lists.theme.textPrimary : "#e0e0e0"
    readonly property color cText2: lists.theme ? lists.theme.textSecondary : "#c0c0c0"
    readonly property color cMuted: lists.theme ? lists.theme.textMuted : "#8a8a8a"
    readonly property color cAccent: lists.theme ? lists.theme.accentPrimary : "#7aa2f7"

    onQueryChanged: lists.optionPick = 0
    onModeChanged: lists.reset()
    onOptionRowsChanged: if (lists.optionPick >= lists.optionRows.length)
        lists.optionPick = Math.max(0, lists.optionRows.length - 1)

    function reset() {
        lists.categoryPick = 0;
        lists.optionPick = 0;
        lists.side = "category";
    }
    function move(d) {
        if (lists.side === "category") {
            const n = lists.categoryRows.length;
            if (n) {
                lists.categoryPick = (lists.categoryPick + d + n) % n;
                lists.optionPick = 0;
            }
        } else {
            const n = lists.optionRows.length;
            if (n) lists.optionPick = Math.max(0, Math.min(n - 1, lists.optionPick + d));
        }
    }
    function focusCategory() { lists.side = "category"; return true; }
    function focusOptions() { lists.side = "option"; return true; }
    function activate() {
        if (lists.side === "category") return lists.focusOptions();
        const o = lists.currentOption;
        if (!lists.actionable(o)) return false;
        if (lists.mode === "remove") lists.removed(o);
        else lists.chosen(o);
        return true;
    }
    function key(event) {
        if (event.key === Qt.Key_Up) lists.move(-1);
        else if (event.key === Qt.Key_Down) lists.move(1);
        else if (event.key === Qt.Key_Left) { if (!lists.focusCategory()) return false; }
        else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) { if (!lists.focusOptions()) return false; }
        else if (event.key === Qt.Key_Backtab) { if (!lists.focusCategory()) return false; }
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { if (!lists.activate()) return false; }
        else if (lists.allowDeleteKey && lists.query.trim() === ""
                && (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace)
                && lists.canRemove(lists.currentOption)) {
            lists.removed(lists.currentOption);
        } else return false;
        event.accepted = true;
        return true;
    }

    RowLayout {
        anchors.fill: parent
        spacing: 12

        Rectangle {
            Layout.preferredWidth: Math.max(200, parent.width * 0.34)
            Layout.fillHeight: true
            radius: 10
            color: lists.cSurface
            border.width: 1
            border.color: lists.cBorder
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6
                Text {
                    Layout.fillWidth: true
                    text: "\u{F03A}  Categories"
                    color: lists.cAccent
                    font.family: lists.mono
                    font.pixelSize: 12
                    font.bold: true
                }
                Text {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 2
                    text: lists.categoryRows.length + " groups · ← → change list"
                    color: lists.cMuted
                    font.family: lists.mono
                    font.pixelSize: 10
                }
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 2
                    model: lists.categoryRows
                    currentIndex: lists.categoryPick
                    boundsBehavior: Flickable.StopAtBounds
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                    delegate: Item {
                        id: catRow
                        required property var modelData
                        required property int index
                        readonly property bool active: lists.side === "category" && catRow.index === lists.categoryPick
                        readonly property bool idle: lists.side !== "category" && catRow.index === lists.categoryPick
                        width: ListView.view.width
                        height: 40
                        Rectangle {
                            anchors.fill: parent
                            radius: 7
                            color: catRow.active ? lists.cSelected
                                : catRow.idle ? lists.tint(lists.cAccent, 0.12)
                                : catMa.containsMouse ? lists.cHover : "transparent"
                            Rectangle {
                                visible: catRow.active || catRow.idle
                                width: 3; height: 20; radius: 2
                                anchors.left: parent.left
                                anchors.leftMargin: 2
                                anchors.verticalCenter: parent.verticalCenter
                                color: lists.cAccent
                            }
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 10
                                spacing: 10
                                Text {
                                    Layout.preferredWidth: 22
                                    horizontalAlignment: Text.AlignHCenter
                                    text: catRow.modelData.icon || ""
                                    color: catRow.active ? lists.cAccent : lists.cText2
                                    font.family: lists.mono
                                    font.pixelSize: 16
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: catRow.modelData.label || ""
                                    color: catRow.active ? lists.cText : lists.cText2
                                    font.family: lists.sans
                                    font.pixelSize: 12
                                    font.weight: catRow.active ? Font.DemiBold : Font.Normal
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: String(catRow.modelData.count)
                                    color: lists.cMuted
                                    font.family: lists.mono
                                    font.pixelSize: 10
                                }
                            }
                        }
                        MouseArea {
                            id: catMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPositionChanged: lists.categoryPick = catRow.index
                            onClicked: { lists.categoryPick = catRow.index; lists.focusOptions() }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 10
            color: lists.cBase
            border.width: 1
            border.color: lists.cBorder
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6
                Text {
                    Layout.fillWidth: true
                    text: lists.mode === "remove" ? "\u{F1F8}  Remove options" : "\u{F067}  Install options"
                    color: lists.cAccent
                    font.family: lists.mono
                    font.pixelSize: 12
                    font.bold: true
                }
                Text {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 2
                    text: lists.optionRows.length + " choices"
                        + (lists.query.trim() !== "" ? " matching “" + lists.query.trim() + "”" : "")
                    color: lists.cMuted
                    font.family: lists.mono
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 2
                    model: lists.optionRows
                    currentIndex: lists.optionPick
                    boundsBehavior: Flickable.StopAtBounds
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                    delegate: Item {
                        id: optRow
                        required property var modelData
                        required property int index
                        readonly property bool active: lists.side === "option" && optRow.index === lists.optionPick
                        readonly property bool idle: lists.side !== "option" && optRow.index === lists.optionPick
                        width: ListView.view.width
                        height: 44
                        Rectangle {
                            anchors.fill: parent
                            radius: 7
                            opacity: optRow.modelData.enabled ? 1 : 0.55
                            color: optRow.active ? lists.cSelected
                                : optRow.idle ? lists.tint(lists.cAccent, 0.12)
                                : optMa.containsMouse ? lists.cHover : "transparent"
                            Rectangle {
                                visible: optRow.active || optRow.idle
                                width: 3; height: 20; radius: 2
                                anchors.left: parent.left
                                anchors.leftMargin: 2
                                anchors.verticalCenter: parent.verticalCenter
                                color: lists.cAccent
                            }
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 10
                                spacing: 10
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    Text {
                                        Layout.fillWidth: true
                                        text: optRow.modelData.title || ""
                                        color: optRow.active ? lists.cText : lists.cText2
                                        font.family: lists.sans
                                        font.pixelSize: 12
                                        font.weight: optRow.active ? Font.DemiBold : Font.Normal
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: optRow.modelData.sub || ""
                                        color: lists.cMuted
                                        font.family: lists.mono
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                    }
                                }
                                Text {
                                    visible: (optRow.modelData.hint || "") !== ""
                                    Layout.maximumWidth: 180
                                    text: optRow.modelData.hint || ""
                                    color: lists.cMuted
                                    font.family: lists.sans
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: optRow.modelData.installed && lists.mode === "install"
                                        ? "Installed" : lists.actionLabel
                                    color: optRow.modelData.enabled ? lists.cAccent : lists.cMuted
                                    font.family: lists.mono
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                }
                            }
                        }
                        MouseArea {
                            id: optMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPositionChanged: { lists.optionPick = optRow.index; lists.side = "option" }
                            onClicked: {
                                lists.optionPick = optRow.index;
                                lists.side = "option";
                                lists.activate();
                            }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: lists.optionRows.length === 0
                        text: lists.mode === "remove" && !lists.ready
                            ? "Checking what is installed…" : "Nothing here"
                        color: lists.cMuted
                        font.family: lists.sans
                        font.pixelSize: 12
                    }
                }
            }
        }
    }
}
