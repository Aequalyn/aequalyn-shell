// Clipscape plugin entry for Aequalyn: the service is a singleton (qmldir), so the
// bar button and ipc all share one history; this component hosts the picker overlay.
import QtQuick
import "qml"

Item {
    id: root
    property var theme: null

    Picker { id: picker }

    Component.onDestruction: {}
}
