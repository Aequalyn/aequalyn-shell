import QtQuick
import Quickshell
import QtQuick.Layouts
import QtQuick.Controls
import "root:/plugins/wifi"
import ".."

Rectangle {
  // the bar this widget sits in: theme, font, shared state and actions (Bar.qml)
  required property var bar
  id: netPill
  height: 24
  width: netContent.width + 12
  radius: 12
  color: bar.chipColor

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
      color: SystemInfo.networkType === "disconnected" ? bar.theme.textMuted : bar.theme.accentGreen
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
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onClicked: (mouse) => {
      if (mouse.button === Qt.RightButton) {
        bar.openSettingsPage("wifi")
      } else {
        const w = netPill.QsWindow.window;
        if (w) {
          wifiPopup.anchor.window = w;
          const r = netPill.mapToItem(null, 0, netPill.height);
          wifiPopup.anchor.rect.x = r.x;
          wifiPopup.anchor.rect.y = r.y;
          wifiPopup.anchor.rect.width = netPill.width;
          wifiPopup.anchor.rect.height = 1;
        }
        bar.wifiPopupVisible = bar.togglePopup(bar.wifiPopupVisible, w ? w.screen : null)
      }
    }
  }

  PopupWindow {
    id: wifiPopup
    visible: bar.wifiPopupVisible && !!netPill.QsWindow.window && netPill.QsWindow.window.screen === bar.popupScreen
    Shortcut {
      sequence: "Escape"
      onActivated: bar.wifiPopupVisible = false
    }
    implicitWidth: 320
    implicitHeight: 360
    color: "transparent"

    anchor.window: netPill.QsWindow.window
    anchor.rect.x: netPill.mapToItem(null, 0, 0).x
    anchor.rect.y: netPill.QsWindow.window ? netPill.QsWindow.window.height : 32
    anchor.rect.width: netPill.width
    anchor.rect.height: 1
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.adjustment: PopupAdjustment.Slide

    onVisibleChanged: if (visible) WifiService.scan()

    Rectangle {
      id: wifiPopupBg
      anchors.fill: parent
      color: bar.theme.bgBase
      border.color: bar.theme.bgBorder
      border.width: 1
      radius: 12

      ColumnLayout {
        id: wifiContent
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8
      width: parent.width

      RowLayout {
        Layout.fillWidth: true
        Text {
          text: WifiService.available ? (WifiService.wifiEnabled ? "Wi-Fi on" : "Wi-Fi off") : "No adapter"
          color: bar.theme.textPrimary
          font.pixelSize: 12
          font.family: bar.font
          Layout.fillWidth: true
        }
        Rectangle {
          implicitWidth: 52
          implicitHeight: 24
          radius: 6
          color: bar.theme.bgSelected
          border.color: bar.theme.bgBorder
          border.width: 1
          Text {
            anchors.centerIn: parent
            text: WifiService.wifiEnabled ? "Off" : "On"
            color: bar.theme.textPrimary
            font.pixelSize: 10
            font.family: bar.font
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: WifiService.toggleWifi()
          }
        }
        Rectangle {
          implicitWidth: 52
          implicitHeight: 24
          radius: 6
          color: bar.theme.bgSelected
          border.color: bar.theme.bgBorder
          border.width: 1
          Text {
            anchors.centerIn: parent
            text: WifiService.scanning ? "…" : "Scan"
            color: bar.theme.textPrimary
            font.pixelSize: 10
            font.family: bar.font
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: WifiService.scan()
          }
        }
        Rectangle {
          implicitWidth: 24
          implicitHeight: 24
          radius: 6
          color: bar.theme.bgSelected
          border.color: bar.theme.bgBorder
          border.width: 1
          Text { anchors.centerIn: parent; text: "✕"; color: bar.theme.textPrimary; font.pixelSize: 10; font.family: bar.font }
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: bar.wifiPopupVisible = false }
        }
      }

      Rectangle { Layout.fillWidth: true; height: 1; color: bar.theme.bgBorder }

      Text {
        visible: WifiService.networkCount === 0
        text: "No networks found"
        color: bar.theme.textMuted
        font.pixelSize: 11
        font.family: bar.font
      }

      ScrollView {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(260, WifiService.networkCount * 44 + 8)
        clip: true
        ColumnLayout {
          width: parent.width
          spacing: 4
          Repeater {
            model: WifiService.networks
            Rectangle {
              required property var modelData
              Layout.fillWidth: true
              implicitHeight: 40
              radius: 8
              color: bar.theme.bgSurface
              border.color: modelData.connected ? bar.theme.accentPrimary : bar.theme.bgBorder
              border.width: 1
              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 8
                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 0
                  Text {
                    Layout.fillWidth: true
                    text: modelData.name || "(hidden)"
                    color: bar.theme.textPrimary
                    font.pixelSize: 11
                    font.family: bar.font
                    elide: Text.ElideRight
                  }
                  Text {
                    Layout.fillWidth: true
                    text: Math.round(modelData.signalStrength || 0) + "% · " + WifiService.securityText(modelData.security)
                    color: bar.theme.textMuted
                    font.pixelSize: 9
                    font.family: bar.font
                  }
                }
                Rectangle {
                  implicitWidth: 64
                  implicitHeight: 22
                  radius: 6
                  color: connHover.containsMouse ? bar.theme.accentPrimary : bar.theme.bgSelected
                  border.color: bar.theme.bgBorder
                  border.width: 1
                  Text {
                    anchors.centerIn: parent
                    text: modelData.connected ? "Disconnect" : "Connect"
                    color: connHover.containsMouse ? bar.theme.bgBase : bar.theme.textPrimary
                    font.pixelSize: 9
                    font.family: bar.font
                  }
                  MouseArea {
                    id: connHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      if (modelData.connected) {
                        WifiService.disconnectNetwork(modelData)
                      } else if (WifiService.requiresCredentials(modelData.security) && !modelData.known) {
                        // fall back to settings for password entry
                        bar.wifiPopupVisible = false
                        bar.openSettingsPage("wifi")
                      } else {
                        WifiService.connectNetwork(modelData)
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
}
