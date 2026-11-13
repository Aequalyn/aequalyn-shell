// One widget's place in a bar region: loads the widget's file (widgets/Widgets.js), keeps
// a little room around it, hides when the widget is switched off or has nothing to show,
// and lets you drag it to another place, another region, or off the bar.
import QtQuick
import "root:/settings"
import "widgets"
import "widgets/Widgets.js" as Widgets

Item {
  id: slot
  required property string modelData   // the widget id
  required property int index
  required property string region      // "left", "center" or "right"
  required property var bar            // Bar.qml
  required property var band           // the strip the bar's shapes and regions live in

  readonly property string file: Widgets.fileFor(modelData)
  readonly property bool beingDragged: band.dragging && band.dragRegion === region && band.dragIndex === index
  // BarDecor measures these slots and only counts the ones that say whether they're hovered
  readonly property bool hovered: hh.hovered

  width: loader.item ? ((loader.item.implicitWidth > 0 ? loader.item.implicitWidth : (loader.item.width > 0 ? loader.item.width : 24)) + 8) : 32
  height: band.height
  opacity: beingDragged ? 0.35 : (AequalynSettings.pluginVisible(modelData) ? 1.0 : 0.0)
  // a widget with nothing to show (`wanted: false`) or an unknown id takes no room and gets no shape
  visible: (file !== "" && AequalynSettings.pluginVisible(modelData) && !(loader.item && loader.item.wanted === false))
           || beingDragged

  Loader {
    id: loader
    anchors.centerIn: parent
    visible: AequalynSettings.pluginVisible(slot.modelData)
    HoverHandler { id: hh }
    // setSource hands the widget its bar before its bindings first run
    Component.onCompleted: if (slot.file !== "") setSource(Qt.resolvedUrl("widgets/" + slot.file), { bar: slot.bar })
  }

  readonly property bool dragActive: drag.active
  // going away mid-drag (its region's widget list changed): let go of the drag
  Component.onDestruction: if (band.dragSlot === slot) band.dragSlot = null
  DragHandler {
    id: drag
    target: null
    onActiveChanged: active ? slot.band.startDrag(slot, slot.region, slot.index, slot.modelData) : slot.band.finishDrag()
    onCentroidChanged: if (active) slot.band.trackDrag(slot, centroid.position)
  }
}
