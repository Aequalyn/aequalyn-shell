import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

Item {
  // the bar this widget sits in: theme, font, shared state and actions (Bar.qml)
  required property var bar
  // the colour the bar gives it (Bar page: the widgets' colours), transparent for its own
  property color ink: "transparent"
  // a window title cannot fit a side bar: it takes no room there
  readonly property bool wanted: !bar.vertical
  visible: wanted
  implicitWidth: wanted ? Math.min(titleText.implicitWidth, 360) : 0
  implicitHeight: 24
  width: implicitWidth
  Text {
    id: titleText
    anchors.fill: parent
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
}
