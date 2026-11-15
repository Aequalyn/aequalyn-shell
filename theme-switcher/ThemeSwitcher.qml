// Theme provider for the whole shell.
// Exposes the active colours as `theme` (a theme's, or made from the wallpaper; see
// Theme.qml) and the `theme` IPC target. Picking themes and wallpapers happens in
// Atelier.

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

        // A theme's id: its colours (and its first wallpaper).
        function set(key: string): bool {
            return root.theme.setByKey(key);
        }

        // Apply the current colours everywhere again (apps, terminals, Hyprland),
        // changing nothing else.
        function reapply(): void {
            root.theme.applyTheme(root.theme.committed);
        }

        // Re-read installed folder themes (after aequalyn-themes install).
        function reload(): void {
            root.theme.reloadFolderThemes();
        }

        function current(): string {
            if (root.theme.wallpaperMode) return "wallpaper";
            if (root.theme.currentFolderId !== "") return root.theme.currentFolderId;
            return "";
        }

        // Kept for older keybinds: opens Atelier on the themes collection.
        function toggle(): void {
            root.openRequested("themes");
        }
    }
}
