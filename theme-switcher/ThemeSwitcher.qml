// Theme provider for the whole shell.
// Exposes the active theme's colours as `theme` (see Theme.qml) and the `theme`
// IPC target. Picking themes and wallpapers happens in Atelier.

import Quickshell
import Quickshell.Io
import QtQuick

Scope {
    id: root
    property var theme: Theme

    // Atelier listens to this to open on a given collection.
    signal openRequested(string collection)

    IpcHandler {
        target: "theme"

        // A theme's id: its colours and its first wallpaper.
        function set(key: string): bool {
            return root.theme.setByKey(key);
        }

        // Re-read installed folder themes (after aequalyn-themes install).
        function reload(): void {
            root.theme.reloadFolderThemes();
        }

        function current(): string {
            return root.theme.currentFolderId;
        }

        // Kept for older keybinds: opens Atelier on the themes collection.
        function toggle(): void {
            root.openRequested("themes");
        }
    }
}
