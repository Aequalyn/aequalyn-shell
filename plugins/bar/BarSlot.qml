// One widget's place in a bar region: loads the widget's file (widgets/Widgets.js), keeps
// a little room around it, hides when the widget is switched off, its plugin is off, or
// it has nothing to show, and lets you drag it to another place, another region, or off
// the bar.
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
  property var screen                  // the screen this bar is on

  readonly property string file: Widgets.fileFor(modelData)
  // or the widget of a plugin from the Store, by the plugin's id
  readonly property string userFile: file === "" ? UserPlugins.widgetOf(modelData) : ""
  // a widget of a plugin that is off is not loaded at all (Widgets.js: plugins)
  readonly property string plugin: userFile !== "" ? modelData : Widgets.pluginFor(modelData)
  readonly property bool pluginOn: plugin === "" || AequalynSettings.enabledPlugins.indexOf(plugin) >= 0
  readonly property bool beingDragged: band.dragging && band.dragRegion === region && band.dragIndex === index
  // BarDecor measures these slots and only counts the ones that say whether they're hovered
  readonly property bool hovered: hh.hovered
  // and whether the widget's panel is open: the bar draws its own mark for that
  readonly property bool open: bar && (bar.widgetPopup === modelData || bar.widgetPopup === "atelier-" + modelData)

  // ---- its colour, when the widgets take the theme's (Bar page) -----------------------
  // A widget that can take one says so with `property color ink`; the others (the tray's
  // app icons, Media with colours of its own) keep theirs and aren't counted in the
  // pattern, so it never shows a step that isn't there.
  property int inkStart: 0
  readonly property bool inkable: !!loader.item && loader.item.ink !== undefined
  // its place among the widgets here that take a colour and show
  readonly property int inkOrder: {
    if (!parent) return -1;
    let n = 0;
    const kids = parent.children;
    for (let i = 0; i < kids.length; i++) {
      if (kids[i] === slot) return n;
      if (kids[i].inkable && kids[i].visible) n++;
    }
    return -1;
  }
  readonly property color tone: inkable && inkOrder >= 0 ? bar.inkAt(inkStart + inkOrder) : "transparent"
  Binding {
    target: loader.item
    property: "ink"
    value: slot.tone
    when: slot.inkable
  }

  // along the bar: the widget's own size and some room; across it: the whole band
  readonly property real itemW: loader.item ? (loader.item.implicitWidth > 0 ? loader.item.implicitWidth : (loader.item.width > 0 ? loader.item.width : 24)) : 24
  readonly property real itemH: loader.item ? (loader.item.implicitHeight > 0 ? loader.item.implicitHeight : (loader.item.height > 0 ? loader.item.height : 24)) : 24
  width: bar.vertical ? band.width : (loader.item ? itemW + 8 : 32)
  height: bar.vertical ? (loader.item ? itemH + 8 : 32) : band.height
  opacity: beingDragged ? 0.35 : (AequalynSettings.pluginVisible(modelData) ? 1.0 : 0.0)
  // a widget with nothing to show (`wanted: false`) or an unknown id takes no room and gets no shape
  visible: ((file !== "" || (userFile !== "" && loader.status !== Loader.Error)) && pluginOn && AequalynSettings.pluginVisible(modelData) && !(loader.item && loader.item.wanted === false))
           || beingDragged

  Loader {
    id: loader
    anchors.centerIn: parent
    active: slot.pluginOn && (slot.file !== "" || slot.userFile !== "")
    visible: AequalynSettings.pluginVisible(slot.modelData)
    HoverHandler { id: hh }
    // (an update of a Store plugin: its folder is new, so its widget is loaded again)
    onStatusChanged: if (status === Loader.Error && slot.userFile !== "") console.error("Plugin widget failed to load:", slot.modelData)
    function loadUser() { if (slot.userFile !== "") setSource(slot.userFile, { bar: slot.bar }); }
    Connections {
      target: slot
      function onUserFileChanged() { if (slot.userFile !== "") loader.loadUser(); else if (slot.file === "") loader.source = ""; }
    }
    // setSource hands the widget its bar before its bindings first run
    Component.onCompleted: if (slot.userFile !== "") loadUser(); else if (slot.file !== "") {
      const props = { bar: slot.bar };
      if (slot.file === "Workspaces.qml") props.screen = slot.screen;
      setSource(Qt.resolvedUrl("widgets/" + slot.file), props);
    }
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
