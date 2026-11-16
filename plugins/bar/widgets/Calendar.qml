import QtQuick
import Quickshell
import Quickshell.Hyprland

Item {
  required property var bar
  id: calendarButton
  implicitWidth: 28
  implicitHeight: 24
  property date displayedMonth: new Date()
  property bool open: false

  Rectangle {
    anchors.fill: parent
    radius: 8
    color: calendarMouse.containsMouse || calendarButton.open ? bar.theme.bgSelected : bar.chipColor
    Text {
      anchors.centerIn: parent
      text: "\u{F0ED7}"
      color: bar.theme.accentPrimary
      font.family: bar.font
      font.pixelSize: 16
    }
    MouseArea {
      id: calendarMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: calendarButton.open = !calendarButton.open
    }
  }

  PopupWindow {
    id: popup
    anchor.item: calendarButton
    anchor.rect.x: 0
    anchor.rect.y: 0
    anchor.rect.width: calendarButton.width
    anchor.rect.height: calendarButton.height + 8
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.adjustment: PopupAdjustment.Slide
    visible: calendarButton.open
    implicitWidth: 300
    implicitHeight: 326
    color: "transparent"
    onVisibleChanged: if (!visible) calendarButton.open = false
    HyprlandFocusGrab {
      windows: [popup]
      active: popup.visible
      onCleared: calendarButton.open = false
    }

    Rectangle {
      anchors.fill: parent
      anchors.margins: 1
      radius: 16
      color: bar.theme.bgBase
      border.color: bar.theme.bgBorder
      border.width: 1

      Column {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        Row {
          width: parent.width
          height: 34
          spacing: 6
          Rectangle {
            width: 32; height: 32; radius: 9
            color: previousMouse.containsMouse ? bar.theme.bgHover : "transparent"
            Text { anchors.centerIn: parent; text: "\u{F0141}"; color: bar.theme.textPrimary; font.family: bar.font; font.pixelSize: 16 }
            MouseArea {
              id: previousMouse
              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: calendarButton.displayedMonth = new Date(calendarButton.displayedMonth.getFullYear(), calendarButton.displayedMonth.getMonth() - 1, 1)
            }
          }
          Text {
            width: parent.width - 76
            height: 32
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: Qt.formatDate(calendarButton.displayedMonth, "MMMM yyyy")
            color: bar.theme.textPrimary
            font.family: "sans-serif"
            font.pixelSize: 15
            font.weight: Font.DemiBold
          }
          Rectangle {
            width: 32; height: 32; radius: 9
            color: nextMouse.containsMouse ? bar.theme.bgHover : "transparent"
            Text { anchors.centerIn: parent; text: "\u{F0142}"; color: bar.theme.textPrimary; font.family: bar.font; font.pixelSize: 16 }
            MouseArea {
              id: nextMouse
              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: calendarButton.displayedMonth = new Date(calendarButton.displayedMonth.getFullYear(), calendarButton.displayedMonth.getMonth() + 1, 1)
            }
          }
        }

        Row {
          width: parent.width
          spacing: 0
          Repeater {
            model: ["M", "T", "W", "T", "F", "S", "S"]
            delegate: Text {
              required property string modelData
              width: parent.width / 7
              height: 22
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
              text: modelData
              color: bar.theme.textMuted
              font.family: "sans-serif"
              font.pixelSize: 11
              font.weight: Font.DemiBold
            }
          }
        }

        Grid {
          width: parent.width
          columns: 7
          rowSpacing: 2
          columnSpacing: 0
          Repeater {
            model: 42
            delegate: Rectangle {
              required property int index
              readonly property int monthStartOffset: (new Date(calendarButton.displayedMonth.getFullYear(), calendarButton.displayedMonth.getMonth(), 1).getDay() + 6) % 7
              readonly property date cellDate: new Date(calendarButton.displayedMonth.getFullYear(), calendarButton.displayedMonth.getMonth(), index - monthStartOffset + 1)
              readonly property date today: new Date()
              readonly property bool sameMonth: cellDate.getMonth() === calendarButton.displayedMonth.getMonth()
              readonly property bool isToday: cellDate.getFullYear() === today.getFullYear() && cellDate.getMonth() === today.getMonth() && cellDate.getDate() === today.getDate()
              width: parent.width / 7
              height: 34
              radius: 10
              color: isToday ? bar.theme.accentPrimary : "transparent"
              Text {
                anchors.centerIn: parent
                text: String(parent.cellDate.getDate())
                color: parent.isToday ? bar.theme.bgBase : (parent.sameMonth ? bar.theme.textPrimary : bar.theme.textMuted)
                opacity: parent.sameMonth ? 1 : 0.45
                font.family: "sans-serif"
                font.pixelSize: 12
                font.weight: parent.isToday ? Font.DemiBold : Font.Normal
              }
            }
          }
        }
      }
    }
  }
}
