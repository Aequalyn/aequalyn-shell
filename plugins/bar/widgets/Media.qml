import QtQuick
import Quickshell
import "root:/plugins/media"
import "root:/plugins/media/qml" as MediaPlugin

// The bar's media widget: Media's own (a live visualizer, the title, the cover and the
// buttons, on a plate of its own if you like; every setting on the control center's
// Media page). With the Media plugin off it is not on the bar; nothing playing hides
// the slot. The click you chose opens Media's quick panel (MediaQuick.qml).
Item {
  id: media
  // the bar this widget sits in: theme, font, shared state and actions (Bar.qml)
  required property var bar
  readonly property bool wanted: !!MediaHost.svc && !!loader.item && loader.item.shouldShow
  implicitWidth: loader.item ? loader.item.implicitWidth || loader.item.width : 0
  implicitHeight: loader.item ? loader.item.implicitHeight || loader.item.height : 24
  width: implicitWidth
  height: implicitHeight

  Loader {
    id: loader
    anchors.verticalCenter: parent.verticalCenter
    active: !!MediaHost.svc
    sourceComponent: MediaPlugin.BarWidget { bar: media.bar; onQuickRequested: media.toggleQuick() }
  }

  // gone from the bar: its quick panel closes too
  onWantedChanged: if (!wanted && media.bar.widgetPopup === "media") media.bar.widgetPopup = ""
  function toggleQuick() {
    const w = media.QsWindow.window;
    media.bar.toggleWidgetPopup("media", w ? w.screen : null);
  }
  MediaQuick {
    bar: media.bar
    anchorItem: media
    open: media.bar.widgetPopup === "media" && !!media.QsWindow.window
          && media.QsWindow.window.screen === media.bar.popupScreen
    onDismissed: media.bar.widgetPopup = ""
  }
}
