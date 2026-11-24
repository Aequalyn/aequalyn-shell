import QtQuick
import Quickshell
import "root:/settings"
import "../../../style/BarLooks.js" as BarLooks

// The button on the bar that opens these settings. Its look and its two other
// clicks come from the Bar -> Bar button group: icon or text, next shape, next
// look or on/off. The Themes and Layouts buttons have their own clicks.
Rectangle {
  id: btn
  required property var bar
  property color ink: "transparent"
  objectName: "aequalyn-bar-button"

  readonly property var cfg: BarLooks.clean(AequalynSettings.barStyleCfg)
  readonly property string label: cfg.barButton === "text"
    ? (cfg.barText.trim() !== "" ? cfg.barText : "Bar") : "󰕮"
  // a hidden button says so, and the bar leaves its slot out altogether
  readonly property bool wanted: cfg.barButton !== "hidden"

  function act(what) {
    const raw = Object.assign({}, AequalynSettings.barStyleCfg);
    if (what === "shape") {
      const shapes = ["full", "pill", "islands", "widgets"];
      const i = shapes.indexOf(raw.shape);
      AequalynSettings.setBarStyle(Object.assign(raw, {
        shape: shapes[(i + 1) % shapes.length], enabled: true
      }));
    } else if (what === "look") {
      AequalynSettings.setBarStyle(BarLooks.withNextLook(raw, 1));
    } else if (what === "toggle") {
      AequalynSettings.setBarStyle(Object.assign(raw, { enabled: !raw.enabled }));
    }
  }

  height: 24
  width: bar.vertical ? bar.chipAcross : row.implicitWidth + 16
  radius: 12
  color: area.containsMouse ? bar.theme.bgSelected : bar.chipColor
  Text {
    id: row
    anchors.centerIn: parent
    text: btn.label
    color: bar.inked(btn.ink, bar.theme.accentPrimary)
    font.pixelSize: 14
    font.family: bar.iconFont
  }
  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    onClicked: mouse => {
      if (mouse.button === Qt.LeftButton) btn.bar.openPage("bar");
      else if (mouse.button === Qt.RightButton) btn.act(btn.cfg.rightClick);
      else btn.act(btn.cfg.middleClick);
    }
  }
}
