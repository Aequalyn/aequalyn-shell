// One region of the bar (left, center or right): its widgets in a row, kept against its
// own side (the center one centered). When they don't fit, the row scrolls sideways
// instead of running into the next region: with the mouse wheel, or by dragging the
// space between widgets.
// A full right region starts at its end, so the widgets nearest the screen edge stay in
// view, and the center at its middle; where you scroll to stays put while widgets change
// width (the CPU reading does every few seconds).
import QtQuick
import "root:/settings"

Item {
  id: section
  required property string region   // "left", "center" or "right"
  required property var bar         // Bar.qml
  required property var band        // the strip the bar's shapes and regions live in
  // the widget slots, for BarDecor (where to draw) and drag and drop (where to drop)
  readonly property alias row: row

  readonly property var ids: region === "left" ? AequalynSettings.barLeft
                           : region === "center" ? AequalynSettings.barCenter : AequalynSettings.barRight
  readonly property bool overflowing: row.width > width + 0.5
  readonly property real maxX: Math.max(0, flick.contentWidth - width)

  // where a full region rests: the right one at its end, the center at its middle
  function home() { return region === "right" ? maxX : region === "center" ? maxX / 2 : 0; }
  // how far you scrolled from there; kept while widgets change width
  property real offset: 0
  function settle() {
    if (!overflowing) { offset = 0; flick.contentX = 0; return; }
    flick.contentX = Math.max(0, Math.min(maxX, home() + offset));
  }
  function scrollBy(dx) {
    if (!overflowing) return;
    flick.contentX = Math.max(0, Math.min(maxX, flick.contentX + dx));
    offset = flick.contentX - home();
  }
  onOverflowingChanged: settle()
  onWidthChanged: settle()
  Connections { target: row; function onWidthChanged() { if (!flick.moving) section.settle(); } }

  Flickable {
    id: flick
    anchors.fill: parent
    clip: true
    contentWidth: Math.max(width, row.width)
    contentHeight: height
    flickableDirection: Flickable.HorizontalFlick
    boundsBehavior: Flickable.StopAtBounds
    interactive: section.overflowing && !section.band.dragging
    onMovementEnded: section.offset = contentX - section.home()

    Row {
      id: row
      anchors.verticalCenter: parent.verticalCenter
      x: section.region === "left" ? 0
       : section.region === "right" ? flick.contentWidth - width
       : (flick.contentWidth - width) / 2
      spacing: section.bar.widgetSpacing
      Repeater {
        model: section.ids
        delegate: BarSlot {
          region: section.region
          bar: section.bar
          band: section.band
        }
      }
    }
  }

  // the mouse wheel scrolls a full region (widgets that use the wheel themselves, like
  // volume or workspaces, keep it)
  WheelHandler {
    target: null
    enabled: section.overflowing && !section.band.dragging
    onWheel: event => {
      const d = event.angleDelta.x !== 0 ? event.angleDelta.x : event.angleDelta.y;
      section.scrollBy(-d / 2);
    }
  }
}
