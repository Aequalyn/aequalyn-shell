// PluginManager -- loads the shell's elements as independent plugins.
//
// Each plugin is a self-contained module under plugins/<id>/ with its own
// entry file, theme fallback and IPC. Enabled plugins are instantiated here;
// disabling one removes its surfaces, IPC and state. ThemeSwitcher stays
// outside so every plugin can bind to ts.theme.
import QtQuick
import Quickshell
import Quickshell.Io
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
    // plugins the Store installed (~/.local/share/aequalyn/plugins/<id>, a plugin.json each)
    readonly property var userPlugins: UserPlugins.list
    // a plugin being reloaded is off for a moment
    property string reloading: ""

    readonly property var enabledIds: (AequalynSettings.enabledPlugins && AequalynSettings.enabledPlugins.length)
        ? AequalynSettings.enabledPlugins : allPlugins.map(p => p.id)

    // One loader per plugin, on while the plugin is: turning one on or off in the
    // control center loads or drops that plugin alone, at once, without a restart.
    Repeater {
        model: pm.allPlugins
        delegate: Loader {
            id: loader
            required property var modelData
            readonly property bool wanted: pm.enabledIds.indexOf(modelData.id) >= 0 && pm.reloading !== modelData.id
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

    // The Store's plugins: the same, on only while they are in enabledPlugins (a user
    // plugin is never on by default). A rescan that finds nothing new leaves them alone.
    Repeater {
        model: pm.userPlugins
        delegate: Loader {
            id: userLoader
            required property var modelData
            readonly property bool wanted: (AequalynSettings.enabledPlugins || []).indexOf(modelData.id) >= 0
                                           && pm.reloading !== modelData.id
            active: wanted
            source: wanted ? modelData.source : ""
            onLoaded: {
                const it = userLoader.item;
                if (!it) return;
                try { it.theme = Qt.binding(() => pm.theme); } catch (e) {}
                const n = Object.assign({}, pm.items);
                n[modelData.id] = it;
                pm.items = n;
            }
            onItemChanged: {
                if (userLoader.item || pm.items[modelData.id] === undefined) return;
                const n = Object.assign({}, pm.items);
                delete n[modelData.id];
                pm.items = n;
            }
            onStatusChanged: if (status === Loader.Error) console.error("Plugin failed to load:", modelData.id, source)
        }
    }

    Timer { id: reloadTimer; interval: 150; onTriggered: pm.reloading = "" }

    // qs ipc call plugins rescan | reload <id> | list
    IpcHandler {
        target: "plugins"
        // look for new, updated and removed Store plugins: a new one that is on loads at once
        function rescan(): string { UserPlugins.rescan(); return "ok"; }
        // drop one plugin and load it again
        function reload(id: string): string {
            if (!pm.allPlugins.some(p => p.id === id) && !UserPlugins.byId(id)) return "no plugin " + id;
            pm.reloading = id;
            reloadTimer.restart();
            return "ok";
        }
        // every plugin: id, loaded, active, source (built-in or store), version
        function list(): string {
            const on = AequalynSettings.enabledPlugins || [];
            const rows = pm.allPlugins.map(p => ({ id: p.id, source: "built-in", version: "",
                active: pm.enabledIds.indexOf(p.id) >= 0, loaded: pm.items[p.id] !== undefined }))
                .concat(pm.userPlugins.map(p => ({ id: p.id, source: "store", version: p.version,
                active: on.indexOf(p.id) >= 0, loaded: pm.items[p.id] !== undefined })));
            return JSON.stringify(rows);
        }
    }
}
