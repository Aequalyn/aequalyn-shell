import QtQuick
import Quickshell

PopupWindow {
  id: popup
  required property var bar
  required property Item anchorItem
  signal dismissed()
  property date displayedMonth: new Date()
  anchor.item: anchorItem
  anchor.rect.x: 0
  anchor.rect.y: 0
  anchor.rect.width: anchorItem.width
  anchor.rect.height: anchorItem.height + 8
  anchor.edges: Edges.Bottom
  anchor.gravity: Edges.Bottom
  anchor.adjustment: PopupAdjustment.Slide
  implicitWidth: 300
  implicitHeight: 326
  color: "transparent"
  grabFocus: true

  Rectangle {
    anchors.fill: parent
    anchors.margins: 1
    radius: 16
    color: popup.bar.theme.bgBase
    border.color: popup.bar.theme.bgBorder
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
          color: previousMouse.containsMouse ? popup.bar.theme.bgHover : "transparent"
          Text { anchors.centerIn: parent; text: "\u{F0141}"; color: popup.bar.theme.textPrimary; font.family: popup.bar.font; font.pixelSize: 16 }
          MouseArea {
            id: previousMouse
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: popup.displayedMonth = new Date(popup.displayedMonth.getFullYear(), popup.displayedMonth.getMonth() - 1, 1)
          }
        }
        Text {
          width: parent.width - 76
          height: 32
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          text: Qt.formatDate(popup.displayedMonth, "MMMM yyyy")
          color: popup.bar.theme.textPrimary
          font.family: "sans-serif"
          font.pixelSize: 15
          font.weight: Font.DemiBold
        }
        Rectangle {
          width: 32; height: 32; radius: 9
          color: nextMouse.containsMouse ? popup.bar.theme.bgHover : "transparent"
          Text { anchors.centerIn: parent; text: "\u{F0142}"; color: popup.bar.theme.textPrimary; font.family: popup.bar.font; font.pixelSize: 16 }
          MouseArea {
            id: nextMouse
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: popup.displayedMonth = new Date(popup.displayedMonth.getFullYear(), popup.displayedMonth.getMonth() + 1, 1)
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
            color: popup.bar.theme.textMuted
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
            readonly property int monthStartOffset: (new Date(popup.displayedMonth.getFullYear(), popup.displayedMonth.getMonth(), 1).getDay() + 6) % 7
            readonly property date cellDate: new Date(popup.displayedMonth.getFullYear(), popup.displayedMonth.getMonth(), index - monthStartOffset + 1)
            readonly property date today: new Date()
            readonly property bool sameMonth: cellDate.getMonth() === popup.displayedMonth.getMonth()
            readonly property bool isToday: cellDate.getFullYear() === today.getFullYear() && cellDate.getMonth() === today.getMonth() && cellDate.getDate() === today.getDate()
            width: parent.width / 7
            height: 34
            radius: 10
            color: isToday ? popup.bar.theme.accentPrimary : "transparent"
            Text {
              anchors.centerIn: parent
              text: String(parent.cellDate.getDate())
              color: parent.isToday ? popup.bar.theme.bgBase : (parent.sameMonth ? popup.bar.theme.textPrimary : popup.bar.theme.textMuted)
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
