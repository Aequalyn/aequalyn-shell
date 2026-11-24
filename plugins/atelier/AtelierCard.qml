// One item in a collection: a wallpaper, a theme or a palette.
// Shows the image when there is one, otherwise the palette drawn as a
// tiny desktop, plus title, subtitle, swatches and badges.
import QtQuick
import QtQuick.Effects
import "../../style/Paint.js" as Paint
import "../../style/BarLooks.js" as BarLooks
import "root:/settings"

Item {
    id: card
    property var theme
    property string font: AequalynSettings.monoFont
    property var item: ({})
    property bool selected: false
    property bool showText: true
    property bool round: false        // radial layout: circular thumbnails
    property int imageWidth: 480      // decode size for thumbnails
    property string collection: "themes"

    // The settings stage passes its own collection explicitly. Never substitute
    // the live picker's collection here: that can make the wallpaper preview use
    // the theme picker's layout and shape while both are present in the shell.
    readonly property string pickerCollection: collection
    readonly property string pickerLayout: (AequalynSettings.atelierCfg.layouts || {})[pickerCollection] || "slices"
    readonly property var pickerCardCfg: AequalynSettings.pickerCfg("cards", pickerCollection)
    readonly property var barLook: BarLooks.clean(AequalynSettings.barStyleCfg)
    readonly property string cardEnds: pickerLayout !== "slices" && pickerLayout !== "showcase"
        ? (pickerCardCfg.shape === "original" ? "" : pickerCardCfg.shape === "bar" || !pickerCardCfg.shape ? barLook.ends : pickerCardCfg.shape)
        : ""
    readonly property bool customShape: cardEnds !== ""

    signal clicked()
    signal doubleClicked()
    signal entered()

    readonly property bool hasImage: !!(item && item.image)
    readonly property real r: round ? Math.min(width, height) / 2 : 12

    Rectangle {
        id: frame
        anchors.fill: parent
        radius: card.r
        color: card.customShape ? "transparent" : card.theme.bgSurface
        border.width: card.customShape ? 0 : (card.selected ? 2 : 1)
        border.color: card.selected ? card.theme.accentPrimary : (hover.containsMouse ? card.theme.textMuted : card.theme.bgBorder)
        Behavior on border.color { ColorAnimation { duration: 120 } }

        Canvas {
            id: shapedFrame
            visible: card.customShape
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                Paint.outline(ctx, 0.5, 0.5, width - 1, height - 1, Math.min(10, height / 4), card.cardEnds, "", "", "right", "");
                ctx.fillStyle = card.theme.bgSurface;
                ctx.fill();
                ctx.strokeStyle = card.selected ? card.theme.accentPrimary : (hover.containsMouse ? card.theme.textMuted : card.theme.bgBorder);
                ctx.lineWidth = card.selected ? 2 : 1;
                ctx.stroke();
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Connections {
                target: card
                function onCardEndsChanged() { shapedFrame.requestPaint(); }
                function onSelectedChanged() { shapedFrame.requestPaint(); }
            }
            Connections {
                target: hover
                function onContainsMouseChanged() { shapedFrame.requestPaint(); }
            }
            Connections {
                target: card.theme
                function onBgSurfaceChanged() { shapedFrame.requestPaint(); }
                function onAccentPrimaryChanged() { shapedFrame.requestPaint(); }
                function onTextMutedChanged() { shapedFrame.requestPaint(); }
                function onBgBorderChanged() { shapedFrame.requestPaint(); }
            }
        }

        Item {
            id: content
            anchors.fill: parent
            anchors.margins: card.selected ? 3 : 2
            // Rounded corners need shaders; the software renderer (some VMs)
            // simply gets square thumbnails instead of blank ones.
            layer.enabled: GraphicsInfo.api !== GraphicsInfo.Software
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: maskShape
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }

            Image {
                anchors.fill: parent
                visible: card.hasImage
                source: card.hasImage ? "file://" + card.item.image : ""
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: card.imageWidth
                asynchronous: true
                cache: true
            }
            PaletteMock {
                anchors.fill: parent
                visible: !card.hasImage && !!card.item.palette
                colors: card.item.palette || ({})
            }
            Text {
                anchors.centerIn: parent
                visible: !card.hasImage && !card.item.palette
                text: "󰋩"
                color: card.theme.textMuted
                font.family: card.font
                font.pixelSize: 26
            }

            // Bottom shade for legibility
            Rectangle {
                visible: card.showText && !card.round
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: Math.min(parent.height * 0.5, 64)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.72) }
                }
            }
        }

        Item {
            id: maskShape
            anchors.fill: content
            layer.enabled: true
            visible: false
            Rectangle {
                visible: !card.customShape
                anchors.fill: parent
                radius: Math.max(0, card.r - 2)
                color: "black"
            }
            Canvas {
                id: shapeMask
                visible: card.customShape
                anchors.fill: parent
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    Paint.outline(ctx, 0, 0, width, height, Math.min(10, height / 4), card.cardEnds, "", "", "right", "");
                    ctx.fillStyle = "black";
                    ctx.fill();
                }
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Connections {
                    target: card
                    function onCardEndsChanged() { shapeMask.requestPaint(); }
                }
            }
        }

        // Title + subtitle + swatches
        Column {
            visible: card.showText && !card.round
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 10
            spacing: 2

            Row {
                width: parent.width
                spacing: 6
                Text {
                    width: parent.width - swatches.width - 6
                    text: card.item.title || ""
                    color: "#ffffff"
                    font.family: card.font
                    font.pixelSize: 12
                    font.bold: true
                    elide: Text.ElideRight
                }
                Row {
                    id: swatches
                    spacing: 3
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !!card.item.palette
                    Repeater {
                        model: card.item.palette ? ["accentPrimary", "accentCyan", "accentGreen", "accentOrange", "accentRed"] : []
                        Rectangle {
                            required property var modelData
                            width: 9; height: 9; radius: 4.5
                            color: card.item.palette[modelData] || "transparent"
                            border.color: Qt.rgba(1, 1, 1, 0.35)
                            border.width: 1
                        }
                    }
                }
            }
            Text {
                width: parent.width
                visible: (card.item.subtitle || "") !== ""
                text: card.item.subtitle || ""
                color: Qt.rgba(1, 1, 1, 0.72)
                font.family: card.font
                font.pixelSize: 10
                elide: Text.ElideMiddle
            }
        }

        // Badges: LIVE / active
        Row {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: card.round ? parent.width * 0.16 : 8
            spacing: 4
            Rectangle {
                visible: !!card.item.badge
                width: badgeText.implicitWidth + 10; height: 16; radius: 8
                color: Qt.rgba(0, 0, 0, 0.6)
                Text {
                    id: badgeText
                    anchors.centerIn: parent
                    text: card.item.badge || ""
                    color: "#ffffff"
                    font.family: card.font
                    font.pixelSize: 9
                    font.bold: true
                }
            }
        }
        Rectangle {
            visible: !!card.item.active
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: card.round ? parent.width * 0.12 : 8
            width: 20; height: 20; radius: 10
            color: card.theme.accentGreen
            Text {
                anchors.centerIn: parent
                text: "󰄬"
                color: card.theme.bgBase
                font.family: card.font
                font.pixelSize: 12
            }
        }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: card.entered()
        onClicked: card.clicked()
        onDoubleClicked: card.doubleClicked()
    }
}
