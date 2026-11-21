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

    // ---- the sandbox ------------------------------------------------------
    // A plugin marked sandbox: true in Plugins.js (and a Store plugin whose
    // manifest says group "background") is NOT loaded in-process: the
    // aequalyn-watchdog supervisor runs it as its own QuickShell instance, so
    // a crash, a hang or a leak in it can only take that one process down.
    // See tools/watchdog/README.md. Everything else stays right here.
    function findPlugin(id) {
        return allPlugins.find(p => p.id === id) || UserPlugins.byId(id) || null
    }
    function isSandboxed(p) {
        if (!p) return false
        if (noSandboxIds.indexOf(p.id) >= 0) return false
        return !!p.sandbox || (!!p.info && !!p.info.user && p.info.group === "background")
    }
    function labelOf(id) {
        const p = findPlugin(id)
        return p ? (p.label || p.id) : id
    }
    // ids the supervisor must never move out of process, even if listed here
    // (settings/watchdog.json can add to this from outside the shell)
    readonly property var noSandboxIds: (AequalynSettings.noSandboxPlugins || [])

    // One loader per plugin, on while the plugin is: turning one on or off in the
    // control center loads or drops that plugin alone, at once, without a restart.
    // A sandboxed plugin is deliberately never loaded here: the supervisor runs
    // it out of process (pm.isSandboxed), and toggling it here would run a second
    // copy of it inside the shell.
    Repeater {
        model: pm.allPlugins
        delegate: Loader {
            id: loader
            required property var modelData
            readonly property bool wanted: pm.enabledIds.indexOf(modelData.id) >= 0 && pm.reloading !== modelData.id
                                           && !pm.isSandboxed(modelData)
            active: wanted
            source: wanted ? modelData.source : ""
            property var openHandler: null       // Atelier's link to the theme switcher
            onLoaded: {
                pm.loadSucceeded(modelData.id)                 // a good load ends any streak
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
            // a plugin that cannot even load is turned off, once, with a message
            // in the corner: the shell keeps running, and it comes back on when
            // the plugin is fixed and re-enabled in Settings.
            onStatusChanged: if (status === Loader.Error) {
                console.error("Plugin failed to load:", modelData.id, source)
                pm.loadFailed(modelData.id, source)
            }
        }
    }

    // The Store's plugins: the same, on only while they are in enabledPlugins (a user
    // plugin is never on by default). A rescan that finds nothing new leaves them alone.
    // A Store plugin whose manifest group is "background" runs in the sandbox instead
    // (pm.isSandboxed), for the same reasons as a marked built-in.
    Repeater {
        model: pm.userPlugins
        delegate: Loader {
            id: userLoader
            required property var modelData
            // A Store plugin may never sit on a built-in's id (UserPlugins
            // refuses those; this is the second lock on the same door).
            readonly property bool clash: pm.allPlugins.some(p => p.id === modelData.id)
            readonly property bool wanted: !userLoader.clash
                                           && (AequalynSettings.enabledPlugins || []).indexOf(modelData.id) >= 0
                                           && pm.reloading !== modelData.id
                                           && !pm.isSandboxed(modelData)
            active: wanted
            source: wanted ? modelData.source : ""
            onLoaded: {
                pm.loadSucceeded(modelData.id)                 // a good load ends any streak
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
            onStatusChanged: if (status === Loader.Error) {
                console.error("Plugin failed to load:", modelData.id, source)
                pm.loadFailed(modelData.id, source)
            }
        }
    }

    // A failed load must never take anything with it -- but a failure is only
    // real if it persists. An update swaps the config tree under the running
    // shell, its file watcher reloads onto a half-copied tree, and loads fail
    // in that moment only to succeed seconds later on the finished swap (a
    // reload storm can fire the same loader's error several times, too). So:
    // a failure starts a grace clock, a good load stops it, and only a plugin
    // whose most recent event is still a failure when the clock runs out is
    // turned off, with a notification. The supervisor's own decisions (crash,
    // hang, memory) come through the watchdog IPC target, not here.
    property var loadFailAt: ({})     // id -> last load failure
    property var loadOkAt: ({})      // id -> last successful load
    property var loadFailFirst: ({}) // id -> first failure of the current streak
    property var forceTried: ({})    // id -> a grace-expiry reload was forced
    property var disableQueue: []     // ids whose grace clock is running
    function loadFailed(id, why) {
        if (enabledIds.indexOf(id) < 0) return
        const now = Date.now()
        if (!pm.loadFailFirst[id]) {
            if (pm.forceTried[id]) {
                // it already had its second chance, forced: this one is real
                delete pm.forceTried[id]
                pm.turnOffFailed(id)
                return
            }
            pm.loadFailFirst[id] = now
            pm.disableQueue = pm.disableQueue.concat(id)   // assigned, not pushed: the clock's running binding must see it
            console.warn("Plugin failed to load:", id, "- it has a moment to recover before it is turned off.", why || "")
        }
        pm.loadFailAt[id] = now
    }
    function loadSucceeded(id) {
        pm.loadOkAt[id] = Date.now()
        delete pm.forceTried[id]
        delete pm.loadFailFirst[id]
        if (pm.disableQueue.indexOf(id) >= 0)
            pm.disableQueue = pm.disableQueue.filter(x => x !== id)   // assigned: stops the clock when empty
    }
    function turnOffFailed(id) {
        try { AequalynSettings.togglePlugin(id, false) } catch (e) { console.warn("could not turn off", id, e) }
        Quickshell.execDetached(["notify-send", "-a", "Aequalyn", "Plugin turned off",
            labelOf(id) + " kept failing to load and was turned off; the rest of the shell is unaffected."
            + "\nFix it and turn it back on in Settings \u2192 Plugins."])
    }
    // one clock for every struggling plugin: acts only on ids past their grace
    Timer {
        running: pm.disableQueue.length > 0
        repeat: true
        interval: 1000
        onTriggered: {
            const grace = 10000, now = Date.now()
            const due = pm.disableQueue.filter(id => now - (pm.loadFailFirst[id] || now) >= grace)
            if (!due.length) return
            pm.disableQueue = pm.disableQueue.filter(id => due.indexOf(id) < 0)
            for (const id of due) {
                delete pm.loadFailFirst[id]
                // the newest event decides: a load that came good leaves it alone
                if ((pm.loadFailAt[id] || 0) > (pm.loadOkAt[id] || 0)) {
                    // one forced, fresh attempt: a file repaired in the meantime
                    // loads now and clears everything; a plugin that fails this
                    // too is turned off on that error
                    pm.forceTried[id] = true
                    pm.reloading = id
                    reloadTimer.restart()
                }
            }
        }
    }

    Timer { id: reloadTimer; interval: 150; onTriggered: pm.reloading = "" }

    // drop one plugin and load it again (in-process ones; the sandboxed ones
    // are restarted by aequalyn-watchdog, not here)
    function reloadPlugin(id): bool {
        if (!findPlugin(id)) return false
        pm.reloading = id
        reloadTimer.restart()
        return true
    }

    // qs ipc call plugins rescan | reload <id> | list
    IpcHandler {
        target: "plugins"
        // look for new, updated and removed Store plugins: a new one that is on loads at once
        function rescan(): string { UserPlugins.rescan(); return "ok"; }
        // drop one plugin and load it again
        function reload(id: string): string {
            return pm.reloadPlugin(id) ? "ok" : "no plugin " + id
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














