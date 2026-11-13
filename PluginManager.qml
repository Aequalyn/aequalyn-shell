// PluginManager -- loads the shell's elements as independent plugins.
//
// Each plugin is a self-contained module under plugins/<id>/ with its own
// entry file, theme fallback and IPC. Enabled plugins are instantiated here;
// disabling one removes its surfaces, IPC and state. ThemeSwitcher stays
// outside so every plugin can bind to ts.theme.
import QtQuick
import Quickshell
import "root:/settings"

Item {
    id: pm
    property var theme
    property var themeSwitcher

    // plugin id -> loaded instance, for cross-plugin wiring
    property var items: ({})

    function pluginItem(id) { return pm.items[id] || null; }

    readonly property var allPlugins: [
        { id: "bar",            source: "plugins/bar/Bar.qml" },
        { id: "appLauncher",    source: "plugins/appLauncher/AppLauncher.qml" },
        { id: "notifications",  source: "plugins/notifications/NotificationPopup.qml" },
        { id: "atelier",        source: "plugins/atelier/Atelier.qml" },
        { id: "osd",            source: "plugins/osd/OSD.qml" },
        { id: "monitorManager", source: "plugins/monitorManager/MonitorManager.qml" },
        { id: "idleInhibitor",  source: "plugins/idleInhibitor/CaffeineToggle.qml" },
        { id: "clipboard",      source: "plugins/clipboard/ClipboardPanel.qml" },
        { id: "powerMenu",      source: "plugins/powerMenu/PowerMenu.qml" },
        { id: "docks",          source: "plugins/docks/DocksService.qml" },
        { id: "settings",       source: "settings/Settings.qml" }
    ]

    readonly property var enabledIds: (AequalynSettings.enabledPlugins && AequalynSettings.enabledPlugins.length)
        ? AequalynSettings.enabledPlugins : allPlugins.map(p => p.id)

    Repeater {
        model: pm.allPlugins.filter(p => pm.enabledIds.indexOf(p.id) >= 0)
        delegate: Loader {
            id: loader
            required property var modelData
            source: modelData.source
            onLoaded: {
                const it = loader.item;
                if (!it) return;
                try { if (it.theme !== undefined) it.theme = Qt.binding(() => pm.theme); } catch (e) {}
                if (modelData.id === "docks" && it.shellTheme !== undefined) it.shellTheme = Qt.binding(() => pm.theme);
                if (modelData.id === "atelier" && pm.themeSwitcher) {
                    pm.themeSwitcher.onOpenRequested.connect((collection) => { if (it.open) it.open(collection); });
                }
                // cross-plugin wiring: docks follow the bar's visibility
                if (modelData.id === "docks") {
                    it.barShown = Qt.binding(() => {
                        const b = pm.pluginItem("bar");
                        return b && b.barVisible !== undefined ? b.barVisible : true;
                    });
                }
                const n = Object.assign({}, pm.items);
                n[modelData.id] = it;
                pm.items = n;
            }
            onStatusChanged: if (status === Loader.Error) console.error("Plugin failed to load:", modelData.id, source)
        }
    }
}
