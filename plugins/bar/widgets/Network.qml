import QtQuick
import Quickshell
import QtQuick.Layouts
import QtQuick.Controls
import "root:/plugins/wifi"
import ".."

Rectangle {
  // the bar this widget sits in: theme, font, shared state and actions (Bar.qml)
  required property var bar
  // the colour the bar gives it (Bar page: the widgets' colours), transparent for its own
  property color ink: "transparent"
  id: netPill
  height: 24
  width: netContent.width + 12
  radius: 12
  color: quick.visible ? bar.theme.bgSelected : bar.chipColor

  Row {
    id: netContent
    anchors.centerIn: parent
    spacing: 6
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: {
        if (SystemInfo.networkType === "ethernet") return "󰈀"
        if (SystemInfo.networkType === "wifi") return "󰖩"
        return "󰖪"
      }
      color: SystemInfo.networkType === "disconnected" ? bar.theme.textMuted : bar.inked(ink, bar.theme.accentGreen)
      font.pixelSize: 14
      font.family: bar.font
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: SystemInfo.networkInfo
      color: bar.theme.textPrimary
      font.pixelSize: 11
      font.family: bar.font
    }
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    cursorShape: Qt.PointingHandCursor
    onClicked: (mouse) => {
      const role = netPill.bar.clickRole("network", mouse.button);
      if (role === "quick") netPill.toggleQuick();
      else if (role !== "middle") netPill.bar.openPage("wifi");
    }
  }

  // its quick panel (WifiQuick.qml), on the click you chose (Bar page)
  function toggleQuick() {
    const w = netPill.QsWindow.window;
    netPill.bar.toggleWidgetPopup("network", w ? w.screen : null);
  }
  WifiQuick {
    id: quick
    bar: netPill.bar
    anchorItem: netPill
    open: netPill.bar.widgetPopup === "network" && !!netPill.QsWindow.window
          && netPill.QsWindow.window.screen === netPill.bar.popupScreen
    onDismissed: netPill.bar.widgetPopup = ""
  }
}
