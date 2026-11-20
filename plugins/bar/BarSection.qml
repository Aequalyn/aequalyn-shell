// One region of the bar (left, center or right): its widgets in a row, kept against its
// own side (the center one centered). When they don't fit, the row scrolls sideways
// instead of running into the next region: with the mouse wheel or a touchpad's swipe
// anywhere over it, or by dragging the space between widgets. The widgets themselves
// never take the wheel.
// A full right region starts at its end, so the widgets nearest the screen edge stay in
// view, and the center at its middle; where you scroll to stays put while widgets change
// width (the CPU reading does every few seconds).
import QtQuick
import "root:/settings"
import "root:/style/Wheel.js" as Wheel

Item {
  id: section
  required property string region   // "left", "center" or "right"
  required property var bar         // Bar.qml
  required property var band        // the strip the bar's shapes and regions live in
  property var screen               // the screen this bar is on
  // the widget slots, for BarDecor (where to draw) and drag and drop (where to drop)
  readonly property alias row: row
  // the widgets' colour pattern (Bar page): where it stands at this region's first widget,
  // and how many widgets here take a colour, for the next region to go on from
  property int inkStart: 0
  readonly property int shown: {
    let n = 0;
    const kids = row.children;
    for (let i = 0; i < kids.length; i++) if (kids[i].inkable && kids[i].visible) n++;
    return n;
  }

  readonly property var ids: region === "left" ? AequalynSettings.barLeft
                           : region === "center" ? AequalynSettings.barCenter : AequalynSettings.barRight
  // a side bar runs top to bottom: "along" is down it, and its regions scroll up and down
  readonly property bool vertical: bar.vertical === true
  readonly property bool overflowing: vertical ? row.height > height + 0.5 : row.width > width + 0.5
  readonly property real maxX: vertical ? Math.max(0, flick.contentHeight - height) : Math.max(0, flick.contentWidth - width)
  function pos() { return vertical ? flick.contentY : flick.contentX; }
  function setPos(v) { if (vertical) flick.contentY = v; else flick.contentX = v; }

  // where a full region rests: the right one at its end, the center at its middle
  function home() { return region === "right" ? maxX : region === "center" ? maxX / 2 : 0; }
  // how far you scrolled from there; kept while widgets change width
  property real offset: 0
  function settle() {
    if (!overflowing) { offset = 0; flick.contentX = 0; flick.contentY = 0; return; }
    setPos(Math.max(0, Math.min(maxX, home() + offset)));
  }
  function scrollBy(dx) {
    if (!overflowing) return;
    setPos(Math.max(0, Math.min(maxX, pos() + dx)));
    offset = pos() - home();
  }
  onWidthChanged: settle()
  onHeightChanged: settle()
  onVerticalChanged: { offset = 0; settle(); }
  // a region that briefly overflowed (its widgets still loading, a long window title) and
  // then fits again goes back to rest: left scrolled, its widgets sat partly outside it
  onOverflowingChanged: settle()
  onMaxXChanged: if (!flick.moving) settle()

  Flickable {
    id: flick
    anchors.fill: parent
    clip: true
    contentWidth: section.vertical ? width : Math.max(width, row.width)
    contentHeight: section.vertical ? Math.max(height, row.height) : height
    flickableDirection: section.vertical ? Flickable.VerticalFlick : Flickable.HorizontalFlick
    boundsBehavior: Flickable.StopAtBounds
    interactive: section.overflowing && !section.band.dragging
    onMovementEnded: section.offset = section.pos() - section.home()
    // the row's width only reaches contentWidth (and maxX) after this updates, so settle here,
    // not when the row changes: settling earlier used the old maxX and left a full right
    // region at its start
    onContentWidthChanged: if (!moving) section.settle()
    onContentHeightChanged: if (!moving) section.settle()

    // the widgets in a row, or a column on a side bar (one column, as many rows as widgets)
    Grid {
      id: row
      columns: section.vertical ? 1 : Math.max(1, section.ids.length)
      // across the bar: centered; along it: against its own end of the region
      x: section.vertical ? (flick.contentWidth - width) / 2
       : section.region === "left" ? 0
       : section.region === "right" ? flick.contentWidth - width
       : (flick.contentWidth - width) / 2
      y: !section.vertical ? (flick.contentHeight - height) / 2
       : section.region === "left" ? 0
       : section.region === "right" ? flick.contentHeight - height
       : (flick.contentHeight - height) / 2
      columnSpacing: section.bar.widgetSpacing
      rowSpacing: section.bar.widgetSpacing
      horizontalItemAlignment: Grid.AlignHCenter
      verticalItemAlignment: Grid.AlignVCenter
      Repeater {
        model: section.ids
        delegate: BarSlot {
          region: section.region
          bar: section.bar
          band: section.band
          screen: section.screen
          inkStart: section.inkStart
        }
      }
    }
  }

  // The mouse wheel (and a touchpad's two-finger swipe) slides a full region, over its
  // widgets and the room between them alike. No widget takes the wheel itself: it never
  // changes the volume, the brightness or anything else. Taken here, over the whole
  // region, so it always means the same. A MouseArea, not a WheelHandler: a
  // WheelHandler never hears a real mouse wheel here.
  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.NoButton
    onWheel: wheel => {
      wheel.accepted = true;
      if (section.overflowing && !section.band.dragging)
        section.scrollBy(-Wheel.amount(wheel) / 2);
    }
  }
}
