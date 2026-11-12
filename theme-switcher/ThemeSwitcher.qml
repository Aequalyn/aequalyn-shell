// Theme provider for the whole shell.
// Exposes the active palette as `theme` (curated palettes, folder themes or
// the wallpaper-derived matugen palette, see Theme.qml) and the `theme` IPC
// target. Picking themes and wallpapers happens in Atelier.

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

        // Regenerate colours from an image and let them follow the wallpaper.
        function wallpaper(image: string): void {
            root.theme.setWallpaperFromImage(image);
        }

        // Colours follow the wallpaper again (keeps the current backgrounds).
        function follow(): void {
            root.theme.setWallpaperMode();
        }

        // A folder-theme id, a curated "Family/Name" or a palette index.
        function set(key: string): bool {
            return root.theme.setByKey(key);
        }

        // Re-read installed folder themes (after aequalyn-themes install).
        function reload(): void {
            root.theme.reloadFolderThemes();
        }

        function current(): string {
            if (root.theme.wallpaperMode) return "wallpaper";
            if (root.theme.currentFolderId !== "") return root.theme.currentFolderId;
            return root.theme.currentFamily + "/" + root.theme.currentName;
        }

        // Kept for older keybinds: opens Atelier on the themes collection.
        function toggle(): void {
            root.openRequested("themes");
        }
    }
}
