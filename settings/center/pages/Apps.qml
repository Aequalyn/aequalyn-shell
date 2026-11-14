// Apps: which app opens what. A click on an app makes it the one.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/settings"
import ".."

CcPage {
    id: page
    title: "Apps"
    sub: "Which app opens what. Click one to make it the one."
    Component.onCompleted: if (Cc.apps) Cc.apps.refresh()

    Repeater {
        model: Cc.apps ? Cc.apps.categories : []
        delegate: CcSection {
            id: cat
            required property var modelData
            readonly property var choices: Cc.apps.choices(modelData.key)
            title: modelData.label
            hint: modelData.hint
            CcNote { visible: cat.choices.length === 0; text: "Looking for apps…" }
            CcChoice {
                options: cat.choices
                current: Cc.apps.current[cat.modelData.key] || ""
                onChosen: key => {
                    const app = cat.choices.find(a => a.key === key);
                    Cc.apps.set(cat.modelData.key, key, app ? app.label : key);
                }
            }
        }
    }
}
