// Dock: every dock, where it sits, how it looks and how it hides (Atelier's docks
// pane, a part per tab), under a picture of the desktop with the dock being set up
// marked.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/settings"
import "../../../plugins/atelier"
import "../../../style/BarLooks.js" as BarLooks
import ".."

CcPage {
    id: page
    title: "Dock"
    plugin: "docks"
    sub: "The apps you keep at hand. Up to 4 docks on each edge of each screen; right-click a dock to come here."
    tabs: ["Your docks", "Look", "Hiding"]
    actions: [
        CcButton { text: "Add a dock"; icon: "\u{F0415}"; onClicked: Cc.ipc(["dock", "add"], false) }
    ]

    readonly property var svc: AtelierHost.docks
    readonly property var stageDocks: svc ? svc.docks.map((d, i) => {
        const e = svc.effective(i);
        return { look: e, pal: svc.palette(e), edge: d.edge, icons: Math.max(3, Math.min(6, d.apps.length)) };
    }) : []

    stageHeight: 190
    stage: Stage {
        anchors.fill: parent
        theme: Cc.theme
        font: Cc.mono
        wallpaper: Cc.wallpaper
        barLook: BarLooks.clean(AequalynSettings.barStyleWorn)
        barSize: Math.round(AequalynSettings.barHeight * 0.75)
        docks: AequalynSettings.dockEnabled ? page.stageDocks : []
        marked: page.svc ? Math.max(0, Math.min(page.svc.docks.length - 1, AtelierHost.dockFocus)) : -1
        caption: !AequalynSettings.dockEnabled ? "Docks are off" : ""
    }

    // open apps that aren't pinned: on the primary dock (the first one), or nowhere
    CcSection {
        visible: page.tab === 0
        title: "Open apps that aren't pinned"
        hint: AequalynSettings.dockUnpinned === "primary"
            ? "They show on the primary dock, Dock 1, after its pinned apps, while they are open. Delete Dock 1 and the next dock becomes primary."
            : "Docks show only the apps pinned to them."
        CcChoice {
            options: [{ key: "primary", label: "On the primary dock" }, { key: "none", label: "Nowhere" }]
            current: AequalynSettings.dockUnpinned
            onChosen: key => { AequalynSettings.dockUnpinned = key; AequalynSettings.save(); }
        }
    }

    // each tab's part of the docks pane, made the first time the tab is opened
    Repeater {
        model: ["docks", "look", "hiding"]
        delegate: Loader {
            id: slot
            required property string modelData
            required property int index
            visible: page.tab === index
            active: page.opened(index)
            Layout.fillWidth: true
            Layout.preferredHeight: item ? item.contentHeight : 0
            sourceComponent: Component {
                DocksPane {
                    section: slot.modelData
                    showStage: false
                    interactive: false
                    theme: Cc.theme
                    font: Cc.mono
                }
            }
        }
    }
}
