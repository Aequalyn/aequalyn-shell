import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

Item {
  id: titleWidget
  // the bar this widget sits in: theme, font, shared state and actions (Bar.qml)
  required property var bar
  // the colour the bar gives it (Bar page: the widgets' colours), transparent for its own
  property color ink: "transparent"
  // on a side bar the title runs along it, turned a quarter: reading upward on the left,
  // downward on the right, up to 300 px long
  readonly property real titleLength: Math.min(titleText.implicitWidth, bar.vertical ? 300 : 360)
  implicitWidth: bar.vertical ? 24 : titleLength
  implicitHeight: bar.vertical ? titleLength : 24
  width: implicitWidth
  height: implicitHeight
  Text {
    id: titleText
    anchors.centerIn: parent
    // laid out as a line, then turned on a side bar
    width: parent.titleLength
    height: 24
    rotation: !bar.vertical ? 0 : (bar.position === "left" ? -90 : 90)
    // Hyprland.activeToplevel only fills in on the first focus change, so right after the
    // shell starts (login, aequalyn-update) it's empty; the Wayland toplevel list knows already
    text: Hyprland.activeToplevel ? Hyprland.activeToplevel.title
        : (ToplevelManager.activeToplevel ? ToplevelManager.activeToplevel.title : "")
    color: bar.inked(ink, bar.theme.textPrimary)
    font.pixelSize: 12
    font.family: bar.font
    elide: Text.ElideRight
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
  }

  // ---- a small live preview of the window, with its whole title, while the pointer
  // rests on the title (after a moment, so passing over it shows nothing) -------------
  HoverHandler { id: hover }
  Timer { id: hoverDelay; interval: 350; running: hover.hovered && titleText.text !== "" }
  property bool previewing: false
  Connections {
    target: hoverDelay
    function onTriggered() { titleWidget.previewing = true; }
  }
  Connections {
    target: hover
    function onHoveredChanged() { if (!hover.hovered) titleWidget.previewing = false; }
  }
  PopupWindow {
    id: preview
    readonly property var win: ToplevelManager.activeToplevel
    visible: titleWidget.previewing && !!win
    color: "transparent"
    implicitWidth: 236
    implicitHeight: 160
    // on the windows' side of the title, 6 px off
    readonly property int openEdge: bar.position === "bottom" ? Edges.Top : bar.position === "left" ? Edges.Right
                                  : bar.position === "right" ? Edges.Left : Edges.Bottom
    anchor.item: titleWidget
    anchor.rect.x: bar.position === "right" ? -6 : 0
    anchor.rect.y: bar.position === "bottom" ? -6 : 0
    anchor.rect.width: titleWidget.width + (bar.vertical ? 6 : 0)
    anchor.rect.height: titleWidget.height + (bar.vertical ? 0 : 6)
    anchor.edges: openEdge
    anchor.gravity: openEdge
    anchor.adjustment: PopupAdjustment.Slide
    Rectangle {
      anchors.fill: parent
      radius: 12
      color: bar.theme.bgBase
      border.width: 1
      border.color: Qt.rgba(bar.theme.textPrimary.r, bar.theme.textPrimary.g, bar.theme.textPrimary.b, 0.12)
      ScreencopyView {
        x: 8; y: 8
        width: parent.width - 16
        height: 120
        captureSource: preview.visible ? preview.win : null
        live: preview.visible
      }
      Text {
        x: 10; y: 132
        width: parent.width - 20
        text: titleText.text
        textFormat: Text.PlainText
        color: bar.theme.textPrimary
        font.pixelSize: 11
        font.family: bar.font
        elide: Text.ElideRight
      }
    }
  }
}
