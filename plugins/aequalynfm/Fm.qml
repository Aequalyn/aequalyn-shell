import QtQuick
import Quickshell

// aequalyn-fm is a plugin of the one shell process: the FmApp scope owns the
// file daemon, the windows and the file-chooser portal. PluginManager injects
// the live palette into `theme`; the compat Theme also reads Aequalyn's Theme
// singleton directly, so every file window follows theme changes immediately.
Scope {
    id: root

    property var theme: DefaultTheme {}
    property string font: "sans-serif"

    FmApp {
        id: fm
    }
}
