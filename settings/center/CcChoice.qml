// One of a few answers, as the shared row of joined buttons. `options` are strings
// or { key, label } objects; `setting` binds the choice to an AequalynSettings key,
// otherwise use `current` and `chosen`.
import QtQuick
import QtQuick.Layouts
import "root:/settings"

Item {
    id: c
    property var options: []
    property var current
    property string setting: ""
    signal chosen(var key)

    readonly property var value: setting !== "" ? AequalynSettings[setting] : current

    Layout.fillWidth: true
    implicitHeight: segments.implicitHeight

    // in a section's group: room of its own beside the rows
    readonly property bool grouped: Cc.inGroup(c)
    readonly property bool roomy: Cc.inGroupBody(c)
    Layout.leftMargin: c.options.length === 0 ? 0 : (roomy ? 12 : 0)
    Layout.rightMargin: c.options.length === 0 ? 0 : (roomy ? 12 : 0)
    Layout.topMargin: c.options.length === 0 ? 0 : (roomy ? 8 : 0)
    Layout.bottomMargin: c.options.length === 0 ? 0 : (roomy ? 8 : 0)

    CcSegments {
        id: segments
        anchors.fill: parent
        enabled: c.enabled
        options: c.options
        current: c.value
        onChosen: key => {
            if (c.setting !== "") AequalynSettings.apply(c.setting, key);
            c.chosen(key);
        }
    }
}
