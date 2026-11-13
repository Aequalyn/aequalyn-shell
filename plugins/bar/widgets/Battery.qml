import QtQuick
import Quickshell
import QtQuick.Layouts
import Quickshell.Io
import ".."

Rectangle {
  // the bar this widget sits in: theme, font, shared state and actions (Bar.qml)
  required property var bar
  id: battPill
  height: 24
  width: battContent.width + 12
  radius: 12
  color: bar.chipColor
  readonly property color batteryColor: {
    if (SystemInfo.batteryCharging) return bar.theme.accentGreen;
    if (SystemInfo.batteryLevelRaw > 20) return bar.theme.batteryGood;
    if (SystemInfo.batteryLevelRaw > 10) return bar.theme.batteryWarning;
    return bar.theme.batteryCritical;
  }

  Row {
    id: battContent
    anchors.centerIn: parent
    spacing: 6
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: SystemInfo.batteryIcon
      color: parent.parent.batteryColor
      font.pixelSize: 14
      font.family: bar.font
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: SystemInfo.batteryLevel
      color: bar.theme.textPrimary
      font.pixelSize: 11
      font.family: bar.font
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton
    onClicked: {
      const w = battPill.QsWindow.window;
      if (w) {
        powerProfilePopup.anchor.window = w;
        powerProfilePopup.anchor.rect.x = battPill.mapToItem(null, 0, 0).x;
        powerProfilePopup.anchor.rect.y = w.height;
        powerProfilePopup.anchor.rect.width = battPill.width;
        powerProfilePopup.anchor.rect.height = 1;
      }
      bar.powerProfileVisible = bar.togglePopup(bar.powerProfileVisible, w ? w.screen : null);
      if (bar.powerProfileVisible) {
        powerProfileListProc.running = true;
        powerProfileGetProc.running = true;
      }
    }
  }

  Process {
    id: powerProfileListProc
    command: ["powerprofilesctl", "list"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.split("\n");
        const profiles = [];
        for (const line of lines) {
          if (/^  [A-Za-z0-9_-]+:$/.test(line) || /^\* [A-Za-z0-9_-]+:$/.test(line)) {
            const name = line.trim().replace(/^\*\s*/, "").replace(/:$/, "");
            if (name !== "" && profiles.indexOf(name) === -1) profiles.push(name);
          }
        }
        bar.powerProfiles = profiles;
      }
    }
  }

  Process {
    id: powerProfileGetProc
    command: ["powerprofilesctl", "get"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        bar.currentPowerProfile = text.trim();
      }
    }
  }

  Process {
    id: powerProfileSetProc
    running: false
    stdout: StdioCollector {
      onStreamFinished: powerProfileGetProc.running = true
    }
    onExited: powerProfileGetProc.running = true
  }

  PopupWindow {
    id: powerProfilePopup
    visible: bar.powerProfileVisible && !!battPill.QsWindow.window && battPill.QsWindow.window.screen === bar.popupScreen
    Shortcut {
      sequence: "Escape"
      onActivated: bar.powerProfileVisible = false
    }
    implicitWidth: 200
    implicitHeight: powerProfileColumn.implicitHeight + 24
    color: "transparent"

    anchor.window: battPill.QsWindow.window
    anchor.rect.x: battPill.mapToItem(null, 0, 0).x
    anchor.rect.y: battPill.QsWindow.window ? battPill.QsWindow.window.height : 32
    anchor.rect.width: battPill.width
    anchor.rect.height: 1
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.adjustment: PopupAdjustment.Slide

    onVisibleChanged: {
      if (visible) {
        powerProfileListProc.running = true;
        powerProfileGetProc.running = true;
      }
    }

    Rectangle {
      anchors.fill: parent
      color: bar.theme.bgBase
      border.color: bar.theme.bgBorder
      border.width: 1
      radius: 12

      ColumnLayout {
        id: powerProfileColumn
        anchors.fill: parent
        anchors.margins: 12
        spacing: 6

        Text {
          text: "CPU Power Profile"
          color: bar.theme.accentPrimary
          font.pixelSize: 12
          font.bold: true
          font.family: bar.font
          Layout.fillWidth: true
        }

        Repeater {
          model: bar.powerProfiles
          Rectangle {
            required property string modelData
            Layout.fillWidth: true
            implicitHeight: 36
            radius: 8
            color: bar.currentPowerProfile === modelData ? bar.theme.bgSelected : bar.theme.bgSurface
            border.color: bar.currentPowerProfile === modelData ? bar.theme.accentPrimary : bar.theme.bgBorder
            border.width: 1

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 10
              anchors.rightMargin: 10
              spacing: 8
              Text {
                text: modelData === "performance" ? "󰓅" : (modelData === "power-saver" ? "󰾆" : "󰾅")
                color: bar.currentPowerProfile === modelData ? bar.theme.accentPrimary : bar.theme.textPrimary
                font.pixelSize: 14
                font.family: bar.font
              }
              Text {
                text: modelData
                color: bar.theme.textPrimary
                font.pixelSize: 11
                font.family: bar.font
                Layout.fillWidth: true
              }
              Text {
                visible: bar.currentPowerProfile === modelData
                text: "✓"
                color: bar.theme.accentPrimary
                font.pixelSize: 12
                font.family: bar.font
              }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                powerProfileSetProc.command = ["powerprofilesctl", "set", modelData];
                powerProfileSetProc.running = true;
                bar.currentPowerProfile = modelData;
              }
            }
          }
        }

        Text {
          visible: bar.powerProfiles.length === 0
          text: "No profiles found"
          color: bar.theme.textMuted
          font.pixelSize: 10
          font.family: bar.font
          Layout.fillWidth: true
        }

        Rectangle {
          Layout.fillWidth: true
          height: 1
          color: bar.theme.bgBorder
          visible: bar.powerProfiles.length > 0
        }

        Rectangle {
          Layout.fillWidth: true
          implicitHeight: 28
          radius: 6
          color: closeHover.containsMouse ? bar.theme.bgSelected : bar.theme.bgSurface
          border.color: bar.theme.bgBorder
          border.width: 1
          Text {
            anchors.centerIn: parent
            text: "Close"
            color: bar.theme.textPrimary
            font.pixelSize: 10
            font.family: bar.font
          }
          MouseArea {
            id: closeHover
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: bar.powerProfileVisible = false
          }
        }
      }
    }
  }
}
