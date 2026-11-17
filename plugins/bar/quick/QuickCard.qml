// A card: a surface for things shown together (what is playing, the next days).
// Its children go in a column, 12 pixels in from the edges.
import QtQuick
import QtQuick.Layouts
import Quickshell

Rectangle {
    id: card
    default property alias content: inner.data
    property int padding: 12
    property int spacing: 8
    Layout.fillWidth: true
    implicitHeight: inner.implicitHeight + 2 * padding
    radius: 14
    color: Quick.theme.bgSurface
    ColumnLayout {
        id: inner
        x: card.padding; y: card.padding
        width: card.width - 2 * card.padding
        spacing: card.spacing
    }
}
