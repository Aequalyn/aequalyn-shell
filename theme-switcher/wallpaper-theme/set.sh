#!/usr/bin/env sh
# Compatibility entry point used by theme-switcher/Theme.qml:
#     qs ipc call theme wallpaper <image>
#
# Aequalyn funnels every palette change through `aequalyn-theme`, which renders the
# shell palette AND all systemwide matugen templates (Hyprland, GTK, Qt,
# terminals, btop, hyprlock) in one pass. If the Aequalyn CLI is not installed
# (e.g. this module is used standalone) fall back to the local matugen config.
set -eu

img=${1:-}
[ -n "$img" ] || { echo "set.sh: usage: set.sh <image>" >&2; exit 1; }
[ -f "$img" ] || { echo "set.sh: no such image: $img" >&2; exit 1; }

if command -v aequalyn-theme >/dev/null 2>&1; then
    exec aequalyn-theme --colors-only "$img"
fi

dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if command -v matugen >/dev/null 2>&1; then
    exec matugen image "$img" -c "$dir/matugen/config.toml" \
        -m dark --prefer saturation -q
fi

echo "set.sh: need aequalyn-theme or matugen installed" >&2
exit 1
