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
        barLook: BarLooks.clean(AequalynSettings.barStyleCfg)
        barSize: Math.round(AequalynSettings.barHeight * 0.75)
        docks: AequalynSettings.dockEnabled ? page.stageDocks : []
        marked: page.svc ? Math.max(0, Math.min(page.svc.docks.length - 1, AtelierHost.dockFocus)) : -1
        caption: !AequalynSettings.dockEnabled ? "Docks are off" : ""
    }

    Repeater {
        model: ["docks", "look", "hiding"]
        delegate: DocksPane {
            required property string modelData
            required property int index
            visible: page.tab === index
            section: modelData
            showStage: false
            interactive: false
            Layout.fillWidth: true
            Layout.preferredHeight: contentHeight
            theme: Cc.theme
            font: Cc.mono
        }
    }
}
