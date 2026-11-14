// Web apps: websites in their own window, in the launcher and on a shortcut.
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

    Connections {
        target: page.w
        function onAdded() {
            nameField.text = "";
            urlField.text = "";
            nameField.forceInput();
        }
    }

    function submit() {
        if (!page.w || page.w.busy) return;
        const name = nameField.text.trim();
        const url = urlField.text.trim();
        if (name === "" || url === "") return;
        page.w.add(name, url);
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
        hint: "Click one to open it. Closed windows come back with their session and logins."

        Repeater {
            model: page.w ? page.w.apps : []
            delegate: CcRow {
                required property var modelData
                iconSource: modelData.iconFile
                title: modelData.name
                sub: modelData.url + (modelData.shortcut !== "" ? "   ·   " + modelData.shortcut : "")
                action: "Open"
                action2: "Remove"
                danger2: true
                onActivated: if (page.w) page.w.open(modelData.slug)
                onActivated2: if (page.w) page.w.remove(modelData.slug)
            }
        }
        CcNote {
            visible: page.w && page.w.apps.length === 0
            text: "No web apps yet. Add one below, or choose a few in the installer."
        }
    }

    CcSection {
        title: "Add a web app"
        hint: "Name it as it should appear in the launcher, then give the address. The icon comes from the site when it can."

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

        CcNote {
            visible: page.w && page.w.error !== ""
            text: page.w ? page.w.error : ""
            color: Cc.theme.accentRed
        }
        CcNote {
            visible: page.w && page.w.note !== ""
            text: page.w ? page.w.note : ""
            color: Cc.theme.accentGreen
        }
    }
}
