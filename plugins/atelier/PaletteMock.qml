// A tiny desktop drawn in a palette: bar, two windows, accent dots.
// Used as the card image of themes that have no preview or background.
import QtQuick

Rectangle {
    id: mock
    property var colors: ({})
    readonly property real u: Math.min(width, height) / 100

    color: colors.bgBase || "#1e1e2e"
    clip: true

    // Bar
    Rectangle {
        x: 0; y: 0
        width: parent.width
        height: mock.u * 8
        color: mock.colors.bgSurface || "#313244"
        Row {
            anchors.left: parent.left
            anchors.leftMargin: mock.u * 3
            anchors.verticalCenter: parent.verticalCenter
            spacing: mock.u * 1.6
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    width: mock.u * 3; height: width; radius: width / 2
                    color: index === 0 ? (mock.colors.accentPrimary || "#89b4fa") : (mock.colors.textMuted || "#6c7086")
                }
            }
        }
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: mock.u * 3
            anchors.verticalCenter: parent.verticalCenter
            width: mock.u * 14; height: mock.u * 3; radius: height / 2
            color: mock.colors.textSecondary || "#bac2de"
            opacity: 0.6
        }
    }

    // Back window
    Rectangle {
        x: parent.width * 0.52; y: parent.height * 0.2
        width: parent.width * 0.42; height: parent.height * 0.66
        radius: mock.u * 2.4
        color: mock.colors.bgSurface || "#313244"
        border.width: Math.max(1, mock.u * 0.6)
        border.color: mock.colors.bgBorder || "#45475a"
        Column {
            anchors.fill: parent
            anchors.margins: mock.u * 4
            spacing: mock.u * 3
            Repeater {
                model: [0.9, 0.6, 0.75, 0.4]
                Rectangle {
                    required property var modelData
                    width: parent.width * modelData; height: mock.u * 2.6; radius: height / 2
                    color: mock.colors.textMuted || "#6c7086"
                }
            }
        }
    }

    // Focused window
    Rectangle {
        x: parent.width * 0.07; y: parent.height * 0.17
        width: parent.width * 0.52; height: parent.height * 0.72
        radius: mock.u * 2.4
        color: mock.colors.bgBase || "#1e1e2e"
        border.width: Math.max(1, mock.u * 0.8)
        border.color: mock.colors.accentPrimary || "#89b4fa"
        Column {
            anchors.fill: parent
            anchors.margins: mock.u * 4
            spacing: mock.u * 3
            Rectangle {
                width: parent.width * 0.55; height: mock.u * 3.4; radius: height / 2
                color: mock.colors.textPrimary || "#cdd6f4"
            }
            Repeater {
                model: [0.85, 0.7, 0.5]
                Rectangle {
                    required property var modelData
                    width: parent.width * modelData; height: mock.u * 2.4; radius: height / 2
                    color: mock.colors.textSecondary || "#bac2de"
                    opacity: 0.75
                }
            }
            Row {
                spacing: mock.u * 2
                Repeater {
                    model: ["accentPrimary", "accentCyan", "accentGreen", "accentOrange", "accentRed"]
                    Rectangle {
                        required property var modelData
                        width: mock.u * 5; height: width; radius: width / 2
                        color: mock.colors[modelData] || "#888888"
                    }
                }
            }
        }
    }
}
