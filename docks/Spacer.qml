import QtQuick
import Quickshell
import Quickshell.Wayland

// invisible 1x1 window carrying the exclusive zone for one edge of one monitor.
// the compositor only honours zones from single-edge windows, so the docks can't do it
PanelWindow {
  id: sp

  required property var svc
  required property string edge

  readonly property int zone: svc.edgeZone(screen ? screen.name : "", edge)

  anchors {
    top: sp.edge === "top"
    bottom: sp.edge === "bottom"
    left: sp.edge === "left"
    right: sp.edge === "right"
  }
  implicitWidth: 1
  implicitHeight: 1
  // always Normal: switching to Ignore at runtime may never reach the compositor
  // (a 1x1 transparent window doesn't redraw), which left a stale zone behind.
  // a zone of 0 reserves nothing
  exclusionMode: ExclusionMode.Normal
  exclusiveZone: sp.zone
  color: "transparent"
  // never in the way of the mouse
  mask: Region {}

  // the compositor only takes a new zone with the window's next frame, and a window
  // that never changes never draws one, so an auto-hide dock kept its space while
  // hidden, or never got it back. change an invisible pixel to make it draw, and once
  // more a moment later in case that frame went out before the zone did
  property bool flip: false
  onZoneChanged: { flip = !flip; redraw.restart(); }
  Timer {
    id: redraw
    interval: 80
    onTriggered: sp.flip = !sp.flip
  }
  Rectangle {
    width: 1
    height: 1
    color: sp.flip ? Qt.rgba(0, 0, 0, 1 / 255) : Qt.rgba(0, 0, 0, 2 / 255)
  }
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.namespace: "aequalyn-dock-reserve"
}
