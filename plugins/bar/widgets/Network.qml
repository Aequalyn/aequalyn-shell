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
  // icon and value side by side; stacked, narrower, on a side bar
  height: bar.vertical ? netContent.height + 10 : 24
  width: bar.vertical ? bar.chipAcross : netContent.width + 12
  radius: 12
  color: quick.visible ? bar.theme.bgSelected : bar.chipColor

  Grid {
    id: netContent
    anchors.centerIn: parent
    columns: bar.vertical ? 1 : 99
    columnSpacing: 6
    rowSpacing: 1
    horizontalItemAlignment: Grid.AlignHCenter
    verticalItemAlignment: Grid.AlignVCenter
    Text {
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
      readonly property string full: SystemInfo.networkInfo
      color: bar.theme.textPrimary
      font.pixelSize: bar.vertical ? 9 : 11
      font.family: bar.font
      // on a side bar: shorter (no %%, no decimals), centred under the icon
      text: bar.vertical ? bar.compact(full) : full
      horizontalAlignment: Text.AlignHCenter
      // the network's name does not fit a side bar: the icon says it all there
      visible: !bar.vertical
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
