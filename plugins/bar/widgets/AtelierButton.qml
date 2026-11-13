import QtQuick
import Quickshell
import "root:/settings"

AtelierBarButton {
  objectName: "aequalyn-atelier-button"
  tab: "themes"
  icon: "󰉦"
  label: bar.theme && bar.theme.wallpaperMode ? "Wallpaper" : (bar.theme && bar.theme.committed ? bar.theme.committed.name : "")
  showName: AequalynSettings.atelierCfg.atelierShowName !== false
  rightAction: AequalynSettings.atelierCfg.atelierRightClick || "next-wallpaper"
  middleAction: AequalynSettings.atelierCfg.atelierMiddleClick || "random-wallpaper"
}
