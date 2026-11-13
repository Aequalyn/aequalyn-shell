import QtQuick
import Quickshell
import "root:/settings"
import "root:/plugins/atelier"

AtelierBarButton {
  objectName: "aequalyn-layouts-button"
  tab: "layouts"
  icon: "󰕰"
  label: {
    const l = LayoutService.find(LayoutService.layoutOf(LayoutService.focusedWorkspace));
    return l ? l.name : "";
  }
  showName: AequalynSettings.atelierCfg.layoutsShowName !== false
  rightAction: AequalynSettings.atelierCfg.layoutsRightClick || "next-layout"
  middleAction: AequalynSettings.atelierCfg.layoutsMiddleClick || "prev-layout"
}
