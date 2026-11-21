#!/usr/bin/env bash
# apply-to-live -- lay this checkout's watchdog work onto the installed shell.
#
# aequalyn-update re-copies the shell from the newest release on GitHub; until
# that release includes the watchdog, this puts the layer back where it runs:
# the six changed shell files, the two new folders, the README section and the
# three Aequalyn commands (session-start, shell-restart, update).
#
# Safe to run any time: it only copies the watchdog's own files, and it
# restarts the shell once at the end (through the watchdog when it runs,
# the plain way when it does not).
#
#   AEQUALYN_QS_CONFIG   the installed shell (default ~/.config/quickshell)
#   AEQUALYN_BIN_REPO   the aequalyn checkout whose bin/ to take (default:
#                       the sibling of this repository)
set -Eeuo pipefail

REPO=$(cd "$(dirname "$0")/../.." && pwd)          # the aequalyn-shell checkout
LIVE=${AEQUALYN_QS_CONFIG:-$HOME/.config/quickshell}
BIN_LIVE=$HOME/.local/bin
BIN_REPO=${AEQUALYN_BIN_REPO:-$(cd "$REPO/.." && pwd)/aequalyn/bin}

[[ -f "$REPO/shell.qml" ]] || { echo "apply-to-live: $REPO is not a shell checkout" >&2; exit 1; }
[[ -f "$LIVE/shell.qml" ]] || { echo "apply-to-live: $LIVE is not an installed shell" >&2; exit 1; }
[[ -d "$BIN_REPO" ]] || { echo "apply-to-live: $BIN_REPO not found (clone Aequalyn beside this repo, or set AEQUALYN_BIN_REPO)" >&2; exit 1; }

for f in shell.qml PluginManager.qml Plugins.js PLUGINS.md README.md \
         settings/AequalynSettings.qml settings/UserPlugins.qml; do
    cp "$REPO/$f" "$LIVE/$f"
done
mkdir -p "$LIVE/plugins/watchdog" "$LIVE/tools/watchdog/host"
cp "$REPO/plugins/watchdog/Watchdog.qml" "$LIVE/plugins/watchdog/"
cp "$REPO/tools/watchdog/aequalyn-watchdog" "$LIVE/tools/watchdog/"
cp "$REPO/tools/watchdog/host/shell.qml" "$LIVE/tools/watchdog/host/"
cp "$REPO/tools/watchdog/README.md" "$LIVE/tools/watchdog/"
chmod +x "$LIVE/tools/watchdog/aequalyn-watchdog"

for f in aequalyn-session-start aequalyn-shell-restart aequalyn-update; do
    cp "$BIN_REPO/$f" "$BIN_LIVE/$f"
    chmod +x "$BIN_LIVE/$f"
done
# the command the shell and the autostart find on PATH
ln -sf "$LIVE/tools/watchdog/aequalyn-watchdog" "$BIN_LIVE/aequalyn-watchdog"

echo "watchdog layer applied to $LIVE"
if pgrep -x qs >/dev/null 2>&1; then
    aequalyn-shell-restart || true
fi
