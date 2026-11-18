// PluginManager -- loads the shell's elements as independent plugins.
//
// Each plugin is a self-contained module under plugins/<id>/ with its own
// entry file, theme fallback and IPC. Enabled plugins are instantiated here;
// disabling one removes its surfaces, IPC and state. ThemeSwitcher stays
// outside so every plugin can bind to ts.theme.
import QtQuick
import Quickshell
import "root:/settings"
import "Plugins.js" as PluginRegistry

Item {
    id: pm
    property var theme
    property var themeSwitcher

    // plugin id -> loaded instance, for cross-plugin wiring
    property var items: ({})

    function pluginItem(id) { return pm.items[id] || null; }

    readonly property var allPlugins: PluginRegistry.list

    readonly property var enabledIds: (AequalynSettings.enabledPlugins && AequalynSettings.enabledPlugins.length)
        ? AequalynSettings.enabledPlugins : allPlugins.map(p => p.id)

    // One loader per plugin, on while the plugin is: turning one on or off in the
    // control center loads or drops that plugin alone, at once, without a restart.
    Repeater {
        model: pm.allPlugins
        delegate: Loader {
            id: loader
            required property var modelData
            readonly property bool wanted: pm.enabledIds.indexOf(modelData.id) >= 0
            active: wanted
            source: wanted ? modelData.source : ""
            property var openHandler: null       // Atelier's link to the theme switcher
            onLoaded: {
                const it = loader.item;
                if (!it) return;
                // Bind the shared theme to every plugin that exposes a `theme`
                // property, including ones (like Atelier) whose property has no
                // default value. The previous `it.theme !== undefined` guard
                // skipped those, so they never inherited ts.theme as plugins.
                try { it.theme = Qt.binding(() => pm.theme); } catch (e) {}
                // the docks' palette: their `shellTheme` starts out undefined too, so it is
                // bound the same way, without a guard that would skip it
                if (modelData.id === "docks") { try { it.shellTheme = Qt.binding(() => pm.theme); } catch (e) {} }
                if (modelData.id === "atelier" && pm.themeSwitcher) {
                    loader.openHandler = (collection) => { if (loader.item && loader.item.open) loader.item.open(collection); };
                    pm.themeSwitcher.onOpenRequested.connect(loader.openHandler);
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
            // turned off: forget it, and unhook what it was hooked to
            onItemChanged: {
                if (loader.item) return;
                if (loader.openHandler && pm.themeSwitcher) {
                    pm.themeSwitcher.onOpenRequested.disconnect(loader.openHandler);
                    loader.openHandler = null;
                }
                if (pm.items[modelData.id] !== undefined) {
                    const n = Object.assign({}, pm.items);
                    delete n[modelData.id];
                    pm.items = n;
                }
            }
            onStatusChanged: if (status === Loader.Error) console.error("Plugin failed to load:", modelData.id, source)
        }
    }
}
