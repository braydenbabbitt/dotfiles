#!/bin/bash
#
# Exit center-only mode (idempotent).
#
# Thin wrapper around single-monitor-toggle.sh C — re-enables all three monitors
# and restores every window to its original workspace, exactly like pressing the
# $mainMod+CTRL+C hotkey a second time. Used as a Sunshine prep "undo" command.
#
# single-monitor-toggle.sh is a *toggle*, so we only invoke it when we're
# currently collapsed onto center; otherwise calling it would collapse instead.

export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export HYPRLAND_INSTANCE_SIGNATURE=$(ls "$XDG_RUNTIME_DIR/hypr/" | head -1)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="$XDG_RUNTIME_DIR/hypr-single-monitor.state"

ACTIVE_LETTER=""
[ -f "$STATE_FILE" ] && ACTIVE_LETTER="$(head -n1 "$STATE_FILE")"

# Only restore if we're actually collapsed onto center. Pressing the same letter
# again is how the toggle restores.
[ "$ACTIVE_LETTER" = "C" ] && "$SCRIPT_DIR/single-monitor-toggle.sh" C

exit 0
