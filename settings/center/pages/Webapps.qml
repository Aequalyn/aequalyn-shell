// Web apps: websites in their own window, in the launcher and on a shortcut, each in
// a category if you like, which the list can be filtered by. The categories are your
// own: add one (even with nothing in it yet), rename it or delete it.
// The aequalyn-webapp command does the work; this page shows what it holds.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/settings"
import ".."

CcPage {
    id: page
    title: "Web apps"
    sub: "Websites in their own window, in the launcher and on Super + Shift + a letter."
    readonly property var w: Cc.webapps
    Component.onCompleted: if (page.w) page.w.refresh()

    // the category picked for a new web app ("" = none)
    property string newCategory: ""
    // the list's filter: "" all, "-" those in no category, else a category id
    property string filter: ""
    // the web app whose category is being changed
    property string editing: ""
    // the category being renamed, and the one a click on Delete asked about
    property string renaming: ""
    property string confirmDelete: ""
    Timer { id: confirmTimer; interval: 3000; onTriggered: page.confirmDelete = "" }
    readonly property bool catMessage: page.w && page.w.lastKind.indexOf("cat") === 0 && page.w.lastKind !== "category"

    readonly property var cats: page.w ? page.w.categories : []
    function catLabel(id) { const c = page.cats.find(x => x.id === id); return c ? c.label : ""; }
    // the filter's choices: every category some web app is in, then those in none
    readonly property var filterOptions: {
        const apps = page.w ? page.w.apps : [];
        const out = [{ key: "", label: "All (" + apps.length + ")" }];
        for (const c of page.cats) {
            const n = apps.filter(a => a.category === c.id).length;
            if (n > 0) out.push({ key: c.id, label: c.label + " (" + n + ")" });
        }
        const none = apps.filter(a => !a.category).length;
        if (none > 0 && none < apps.length) out.push({ key: "-", label: "No category (" + none + ")" });
        return out;
    }
    // a filter whose category no longer has any web app falls back to All
    readonly property string activeFilter: page.filterOptions.some(o => o.key === page.filter) ? page.filter : ""
    readonly property var shown: (page.w ? page.w.apps : []).filter(a =>
        page.activeFilter === "" ? true : page.activeFilter === "-" ? !a.category : a.category === page.activeFilter)

    Connections {
        target: page.w
        function onAdded() {
            nameField.text = "";
            urlField.text = "";
            page.newCategory = "";
            nameField.forceInput();
        }
        function onCategoryAdded() {
            catField.text = "";
        }
    }

    function submit() {
        if (!page.w || page.w.busy) return;
        const name = nameField.text.trim();
        const url = urlField.text.trim();
        if (name === "" || url === "") return;
        page.w.add(name, url, page.newCategory);
    }

    CcSection {
        title: "Dock"
        hint: "Open web apps, and any other app you haven't pinned, can show on the primary dock while they are open."

        CcToggle {
            title: "Show open apps that aren't pinned on the primary dock"
            sub: "They appear on Dock 1, after its pinned apps, with a running indicator. Off keeps every dock to its pinned apps. Also on the Dock page."
            checked: AequalynSettings.dockUnpinned === "primary"
            onToggled: v => { AequalynSettings.dockUnpinned = v ? "primary" : "none"; AequalynSettings.save(); }
        }
    }

    CcSection {
        title: "Browser"
        hint: "Chromium-based browsers open a web app as its own app window. Firefox-based browsers use a separate profile with the navigation and tab bars hidden, so the window reads as an app too."

        CcChoice {
            options: (page.w ? page.w.browsers : []).map(b => ({
                key: b.id,
                label: b.available ? b.label : b.label + " (not installed)"
            }))
            current: page.w ? page.w.browser : "auto"
            onChosen: key => {
                if (!page.w) return;
                const b = (page.w.browsers || []).find(x => x.id === key);
                if (b && !b.available) page.w.installBrowser(key);
                else page.w.setBrowser(key);
            }
        }
        CcNote {
            visible: text !== ""
            text: page.w && page.w.resolvedLabel !== ""
                  ? "Web apps open in " + page.w.resolvedLabel + " now."
                  : ""
        }
    }

    CcSection {
        title: "Your web apps"
        hint: "Click one to open it. Closed windows come back with their session and logins. Click a category to change it."

        // show only one category
        CcChoice {
            visible: page.filterOptions.length > 1
            options: page.filterOptions
            current: page.activeFilter
            onChosen: key => page.filter = key
        }

        Repeater {
            model: page.shown
            delegate: ColumnLayout {
                id: entry
                required property var modelData
                readonly property bool editing: page.editing === modelData.slug
                Layout.fillWidth: true
                spacing: 6
                CcRow {
                    Layout.fillWidth: true
                    iconSource: entry.modelData.iconFile
                    title: entry.modelData.name
                    sub: entry.modelData.url + (entry.modelData.shortcut !== "" ? "   ·   " + entry.modelData.shortcut : "")
                    action: "Open"
                    action2: "Remove"
                    danger2: true
                    onActivated: if (page.w) page.w.open(entry.modelData.slug)
                    onActivated2: if (page.w) page.w.remove(entry.modelData.slug)
                    // its category: click to change it
                    Rectangle {
                        implicitWidth: catText.implicitWidth + 20
                        implicitHeight: 26
                        radius: 13
                        color: entry.editing || catArea.containsMouse ? Cc.alpha(Cc.theme.accentPrimary, 0.16) : Cc.theme.bgBase
                        border.width: 1
                        border.color: entry.editing ? Cc.theme.accentPrimary : Cc.theme.bgBorder
                        Text {
                            id: catText
                            anchors.centerIn: parent
                            text: entry.modelData.categoryLabel || "No category"
                            color: entry.modelData.categoryLabel ? Cc.theme.textSecondary : Cc.theme.textMuted
                            font.family: Cc.sans
                            font.pixelSize: 11
                        }
                        MouseArea {
                            id: catArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.editing = entry.editing ? "" : entry.modelData.slug
                        }
                    }
                }
                CcChoice {
                    visible: entry.editing
                    Layout.leftMargin: 12
                    options: [{ key: "", label: "No category" }].concat(page.cats.map(c => ({ key: c.id, label: c.label })))
                    current: entry.modelData.category || ""
                    onChosen: key => {
                        page.editing = "";
                        if (page.w && key !== (entry.modelData.category || "")) page.w.setCategory(entry.modelData.slug, key);
                    }
                }
            }
        }
        CcNote {
            visible: page.w && page.w.apps.length === 0
            text: "No web apps yet. Add one below, or choose a few in the installer."
        }
    }

    CcSection {
        title: "Add a web app"
        hint: "Name it as it should appear in the launcher, then give the address, and a category if you like. The icon comes from the site when it can."

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            CcField {
                id: nameField
                Layout.fillWidth: true
                placeholder: "Name, like Reddit"
                onAccepted: page.submit()
            }
            CcField {
                id: urlField
                Layout.fillWidth: true
                placeholder: "Address, like reddit.com"
                onAccepted: page.submit()
            }
            CcButton {
                text: "Add"
                primary: true
                enabled: !(page.w && page.w.busy)
                onClicked: page.submit()
            }
        }
        Text {
            text: "Category (optional)"
            color: Cc.theme.textSecondary
            font.family: Cc.sans
            font.pixelSize: 12
        }
        CcChoice {
            options: [{ key: "", label: "None" }].concat(page.cats.map(c => ({ key: c.id, label: c.label })))
            current: page.newCategory
            onChosen: key => page.newCategory = key
        }

        CcNote {
            visible: page.w && page.w.error !== "" && !page.catMessage
            text: page.w ? page.w.error : ""
            color: Cc.theme.accentRed
        }
        CcNote {
            visible: page.w && page.w.note !== "" && !page.catMessage
            text: page.w ? page.w.note : ""
            color: Cc.theme.accentGreen
        }
    }

    // ---- your categories -------------------------------------------------------------
    function addCategory() {
        const label = catField.text.trim();
        if (!page.w || page.w.busy || label === "") return;
        page.w.addCategory(label);
    }
    function saveRename(id, label) {
        label = label.trim();
        page.renaming = "";
        if (!page.w || label === "" || label === page.catLabel(id)) return;
        page.w.renameCategory(id, label);
    }

    CcSection {
        title: "Categories"
        hint: "Yours to change: add one (it can stay empty until you put a web app in it), rename it, or delete it. A deleted category's web apps simply have none."

        Repeater {
            model: page.cats
            delegate: ColumnLayout {
                id: cat
                required property var modelData
                readonly property bool renaming: page.renaming === modelData.id
                Layout.fillWidth: true
                spacing: 6
                CcRow {
                    Layout.fillWidth: true
                    icon: "\u{F0315}"
                    title: cat.modelData.label
                    sub: cat.modelData.count === 0 ? "Empty"
                        : cat.modelData.count === 1 ? "1 web app" : cat.modelData.count + " web apps"
                    action: cat.renaming ? "" : "Rename"
                    action2: page.confirmDelete === cat.modelData.id ? "Really delete?" : "Delete"
                    danger2: true
                    onActivated: {
                        page.renaming = cat.modelData.id;
                        renameField.text = cat.modelData.label;
                        renameField.forceInput();
                    }
                    onActivated2: {
                        if (!page.w) return;
                        // one with web apps in it asks once more
                        if (cat.modelData.count > 0 && page.confirmDelete !== cat.modelData.id) {
                            page.confirmDelete = cat.modelData.id;
                            confirmTimer.restart();
                            return;
                        }
                        page.confirmDelete = "";
                        if (page.renaming === cat.modelData.id) page.renaming = "";
                        if (page.filter === cat.modelData.id) page.filter = "";
                        page.w.removeCategory(cat.modelData.id);
                    }
                }
                RowLayout {
                    visible: cat.renaming
                    Layout.fillWidth: true
                    Layout.leftMargin: 12
                    spacing: 8
                    CcField {
                        id: renameField
                        Layout.fillWidth: true
                        placeholder: "A new name"
                        onAccepted: page.saveRename(cat.modelData.id, renameField.text)
                    }
                    CcButton {
                        text: "Save"; primary: true
                        enabled: !(page.w && page.w.busy)
                        onClicked: page.saveRename(cat.modelData.id, renameField.text)
                    }
                    CcButton {
                        text: "Cancel"
                        onClicked: page.renaming = ""
                    }
                }
            }
        }
        CcNote {
            visible: page.cats.length === 0
            text: "No categories. Add one below."
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            CcField {
                id: catField
                Layout.fillWidth: true
                placeholder: "New category, like Work"
                onAccepted: page.addCategory()
            }
            CcButton {
                text: "Add category"
                primary: true
                enabled: !(page.w && page.w.busy)
                onClicked: page.addCategory()
            }
        }
        CcNote {
            visible: page.catMessage && page.w.error !== ""
            text: page.w ? page.w.error : ""
            color: Cc.theme.accentRed
        }
        CcNote {
            visible: page.catMessage && page.w.note !== ""
            text: page.w ? page.w.note : ""
            color: Cc.theme.accentGreen
        }
    }
}
