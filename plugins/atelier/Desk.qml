// A bit of desktop for the bar and dock previews to sit on: the wallpaper when one
// is given (an image; for a video the colours stay), else the theme's colours.
import QtQuick
import QtQuick.Effects

Rectangle {
    id: desk
    property var theme
    property string source: ""
    radius: 9
    gradient: Gradient {
        GradientStop { position: 0; color: Qt.darker(desk.theme.accentPrimary, 2.6) }
        GradientStop { position: 1; color: Qt.darker(desk.theme.accentCyan, 3.2) }
    }

    Image {
        id: pic
        anchors.fill: parent
        visible: false
        source: desk.source !== "" ? "file://" + desk.source : ""
        sourceSize.width: 960
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }
    // the picture, cut to the desk's round corners
    Rectangle {
        id: corners
        anchors.fill: parent
        radius: desk.radius
        visible: false
        layer.enabled: true
    }
    MultiEffect {
        anchors.fill: parent
        visible: desk.source !== "" && pic.status === Image.Ready
        source: pic
        maskEnabled: true
        maskSource: corners
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
    }
}
