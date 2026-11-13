import QtQuick
import Quickshell

Rectangle {
  // the bar this widget sits in: theme, font, shared state and actions (Bar.qml)
  required property var bar
  height: 24
  width: nowPlayingContent.width + 16
  radius: 12
  color: bar.chipColor
  // nothing playing: the bar hides the whole slot (see `wanted` on the slots)
  readonly property bool wanted: bar.activePlayer !== null
  visible: wanted
  Row {
    id: nowPlayingContent
    anchors.verticalCenter: parent.verticalCenter
    anchors.left: parent.left
    anchors.leftMargin: 8
    spacing: 6
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: bar.activePlayer && bar.activePlayer.isPlaying ? "󰐊" : "󰏤"
      color: bar.theme.accentPrimary
      font.pixelSize: 14
      font.family: bar.font
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: {
        if (!bar.activePlayer) return "";
        const artist = bar.activePlayer.trackArtist || "";
        const title = bar.activePlayer.trackTitle || "";
        return artist ? artist + " - " + title : title;
      }
      color: bar.theme.textPrimary
      font.pixelSize: 11
      font.family: bar.font
      elide: Text.ElideRight
      width: Math.min(implicitWidth, 200)
    }
  }
  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: bar.activePlayer.togglePlaying()
  }
}
