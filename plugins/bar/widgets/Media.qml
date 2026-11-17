import QtQuick
import Quickshell
import "root:/plugins/media"
import "root:/plugins/media/qml" as MediaPlugin

// The bar's media widget. While the Media plugin is on: its widget (a live visualizer,
// the title, the cover and the buttons, on a plate of its own if you like; every
// setting on the control center's Media page). With the plugin off: the plain Now
// playing chip (NowPlaying.qml). Either way, nothing playing hides the slot.
Item {
  id: media
  // the bar this widget sits in: theme, font, shared state and actions (Bar.qml)
  required property var bar
  readonly property bool rich: !!MediaHost.svc
  readonly property bool wanted: loader.item ? loader.item.wanted !== false && (!media.rich || loader.item.shouldShow) : false
  implicitWidth: loader.item ? loader.item.implicitWidth || loader.item.width : 0
  implicitHeight: loader.item ? loader.item.implicitHeight || loader.item.height : 24
  width: implicitWidth
  height: implicitHeight

  Loader {
    id: loader
    anchors.verticalCenter: parent.verticalCenter
    sourceComponent: media.rich ? richC : plainC
  }
  Component { id: richC; MediaPlugin.BarWidget { bar: media.bar } }
  Component { id: plainC; NowPlaying { bar: media.bar } }
}
