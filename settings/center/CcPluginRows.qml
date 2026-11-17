// A plugin's own settings rows, drawn for a small panel (plugins/<id>/.../SettingRow.qml),
// shown a quarter larger so every plugin's settings read alike on its page. Put the rows
// inside; `rowWidth` is the width they are laid out at. See PLUGINS.md.
import QtQuick
import QtQuick.Layouts

Item {
    id: holder
    default property alias content: rowsCol.data
    readonly property real k: 1.25
    readonly property real rowWidth: width / k
    Layout.fillWidth: true
    implicitHeight: rowsCol.implicitHeight * k

    ColumnLayout {
        id: rowsCol
        width: holder.rowWidth
        scale: holder.k
        transformOrigin: Item.TopLeft
        spacing: 0
    }
}
