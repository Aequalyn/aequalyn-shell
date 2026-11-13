// A bit of desktop for the bar and dock previews to sit on.
import QtQuick

Rectangle {
    property var theme
    radius: 9
    gradient: Gradient {
        GradientStop { position: 0; color: Qt.darker(theme.accentPrimary, 2.6) }
        GradientStop { position: 1; color: Qt.darker(theme.accentCyan, 3.2) }
    }
}
