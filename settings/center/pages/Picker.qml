// Theme picker: what Super + T and Super + W open. The real picker, small, sits on top
// and follows every choice below: its type, the shape of its cards, where it sits and
// how big it is, and what it shows.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../plugins/atelier"
import ".."

CcPage {
    id: page
    title: "Theme picker"
    sub: "What Super + T and Super + W open, over your blurred desktop."
    tabs: ["Type", "Shape", "Place and size", "What it shows"]
    actions: [
        CcButton { text: "Try it"; icon: "\u{F0E09}"; onClicked: Cc.ipc(["atelier", "open", page.showing], true) }
    ]

    // what the picture on top shows
    property string showing: "themes"

    stageHeight: 320
    stage: PickerPreview {
        anchors.fill: parent
        theme: Cc.theme
        font: Cc.mono
        wallpaper: Cc.wallpaper
        collection: page.showing
    }

    CcChoice {
        options: [{ key: "themes", label: "Show themes" }, { key: "wallpapers", label: "Show wallpapers" }]
        current: page.showing
        onChosen: key => page.showing = key
    }

    // each tab's part of the picker's settings, made the first time the tab is opened
    Repeater {
        model: ["type", "shape", "place", "parts"]
        delegate: Loader {
            id: slot
            required property string modelData
            required property int index
            visible: page.tab === index
            active: page.opened(index)
            Layout.fillWidth: true
            Layout.preferredHeight: item ? item.contentHeight : 0
            sourceComponent: Component {
                PanelPane {
                    section: slot.modelData
                    interactive: false
                    theme: Cc.theme
                    font: Cc.mono
                }
            }
        }
    }
}
