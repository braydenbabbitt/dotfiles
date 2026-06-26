#!/bin/bash
#
# Enter center-only mode (idempotent).
#
# Thin wrapper around single-monitor-toggle.sh C — collapses everything onto the
# center monitor (DP-2), disables the side monitors, and relocates all windows,
# exactly like the $mainMod+CTRL+C hotkey. Used as a Sunshine prep "do" command.
#
# single-monitor-toggle.sh is a *toggle*, so we only invoke it when we're not
# already collapsed onto center; otherwise calling it would toggle back OFF.

export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export HYPRLAND_INSTANCE_SIGNATURE=$(ls "$XDG_RUNTIME_DIR/hypr/" | head -1)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="$XDG_RUNTIME_DIR/hypr-single-monitor.state"

ACTIVE_LETTER=""
[ -f "$STATE_FILE" ] && ACTIVE_LETTER="$(head -n1 "$STATE_FILE")"

# Already collapsed onto center → nothing to do.
[ "$ACTIVE_LETTER" = "C" ] && exit 0

# Not collapsed (or collapsed onto a different monitor) → the toggle restores any
# other-monitor state first, then collapses onto center.
"$SCRIPT_DIR/single-monitor-toggle.sh" C
