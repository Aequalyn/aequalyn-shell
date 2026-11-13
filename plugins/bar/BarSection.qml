// One region of the bar (left, center or right): its widgets in a row, kept against its
// own side (the center one centered). When they don't fit, the row scrolls sideways
// instead of running into the next region; a full right region starts scrolled to its
// end, so the widgets nearest the screen edge stay in view, and the center to its middle.
import QtQuick
import "root:/settings"

Flickable {
  id: section
  required property string region   // "left", "center" or "right"
  required property var bar         // Bar.qml
  required property var band        // the strip the bar's shapes and regions live in
  // the widget slots, for BarDecor (where to draw) and drag and drop (where to drop)
  readonly property alias row: row

  readonly property var ids: region === "left" ? AequalynSettings.barLeft
                           : region === "center" ? AequalynSettings.barCenter : AequalynSettings.barRight
  readonly property bool overflowing: row.width > width

  clip: true
  contentWidth: Math.max(width, row.width)
  contentHeight: height
  flickableDirection: Flickable.HorizontalFlick
  boundsBehavior: Flickable.StopAtBounds
  interactive: overflowing && !band.dragging

  // where the row starts in its region when it fits, and where a full region is scrolled to
  function settle() {
    if (!overflowing) { contentX = 0; return; }
    if (region === "right") contentX = contentWidth - width;
    else if (region === "center") contentX = (contentWidth - width) / 2;
  }
  onOverflowingChanged: settle()
  onWidthChanged: settle()
  Connections { target: row; function onWidthChanged() { if (!section.moving) section.settle(); } }

  Row {
    id: row
    anchors.verticalCenter: parent.verticalCenter
    x: section.region === "left" ? 0
     : section.region === "right" ? section.contentWidth - width
     : (section.contentWidth - width) / 2
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
