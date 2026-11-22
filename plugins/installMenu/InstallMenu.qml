// Install and remove choosers (Super + I, Super + R): a keyboard-first panel
// with two lists. The left list holds the groups; the right list follows the
// highlighted group immediately, and typing searches every group. ← → change
// list, ↑ ↓ move, Enter installs or removes the option under the cursor.
import QtQuick
import Quickshell
import Quickshell.Io
import "root:/plugins/kit"
import "root:/plugins/installMenu" as InstallUi
import "InstallOptions.js" as Options

pragma ComponentBehavior: Bound

Scope {
    id: root
    property var theme: null
    property string mode: "install"
    property var picker: null

    function show(m) {
        root.mode = m === "remove" ? "remove" : "install";
        if (root.picker) root.picker.reset();
        panel.open = true;
    }
    function toggle(m) {
        const next = m === "remove" ? "remove" : "install";
        if (panel.open && root.mode === next) panel.open = false;
        else root.show(next);
    }
    function run(o) {
        if (!o) return;
        const cmd = root.mode === "remove" ? Options.uninstall(o) : o.cmd;
        if (!cmd || cmd.length === 0) return;
        panel.open = false;
        KitHost.notify((root.mode === "remove" ? "Removing " : "Installing ") + o.label,
            "The " + (root.mode === "remove" ? "removal" : "install") + " has been started.");
        Quickshell.execDetached(cmd);
    }

    KitPanel {
        id: panel
        theme: root.theme
        name: "installMenu"
        title: root.mode === "remove" ? "Remove chooser" : "Install chooser"
        icon: root.mode === "remove" ? "\u{F1F8}" : "\u{F067}"
        placeholder: root.mode === "remove" ? "Search removable options" : "Search all install options"
        panelWidth: 920
        panelHeight: 620
        emptyText: root.mode === "remove" ? "Nothing removable by that name" : "Nothing to install by that name"
        status: root.picker ? root.picker.optionRows.length + " choices · ← → change list · Enter "
            + (root.mode === "remove" ? "removes" : "installs") : ""
        hints: [["↑ ↓", "move"], ["← →", "list"],
                ["Enter", root.mode === "remove" ? "remove" : "install"], ["Esc", "close"]]
        items: []
        onKeyPressed: event => {
            if (root.picker && root.picker.key(event)) return;
        }
        body: Component {
            Item {
                anchors.fill: parent
                InstallUi.InstallLists {
                    id: picker
                    anchors.fill: parent
                    theme: root.theme
                    mode: root.mode
                    query: panel.query
                    mono: panel.font
                    sans: panel.font
                    onChosen: o => root.run(o)
                    onRemoved: o => root.run(o)
                    Component.onCompleted: root.picker = picker
                    Component.onDestruction: if (root.picker === picker) root.picker = null
                }
            }
        }
    }

    IpcHandler {
        target: "installMenu"
        function toggle(): void { root.toggle("install") }
        function install(): void { root.show("install") }
        function open(): void { root.show("install") }
        function close(): void { panel.open = false }
    }
    IpcHandler {
        target: "removeMenu"
        function toggle(): void { root.toggle("remove") }
        function open(): void { root.show("remove") }
        function close(): void { panel.open = false }
    }

    Component.onCompleted: KitHost.register("installMenu", root)
    Component.onDestruction: KitHost.unregister("installMenu", root)
}
