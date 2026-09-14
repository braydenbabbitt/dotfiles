#!/usr/bin/env bash
# Switch to workspace N on the currently focused monitor.
# Usage: workspace-switch.sh <1-5> [move]
# If "move" is passed as $2, moves the active window to that workspace instead.

NUM="$1"
ACTION="$2"

FOCUSED_MONITOR=$(hyprctl monitors -j | jq -r '.[] | select(.focused==true) | .name')

# Monitor name mapping — update these if monitor ports change
LEFT="HDMI-A-1"
CENTER="DP-2"
RIGHT="DP-3"

case "$FOCUSED_MONITOR" in
"$LEFT") OFFSET=0 ;;
"$CENTER") OFFSET=5 ;;
"$RIGHT") OFFSET=10 ;;
*) OFFSET=0 ;;
esac

WORKSPACE=$((NUM + OFFSET))

# Hyprland 0.55+ uses a Lua config; dispatchers take their hl.dsp.* form.
if [ "$ACTION" = "move" ]; then
	hyprctl dispatch "hl.dsp.window.move({ workspace = $WORKSPACE })"
else
	hyprctl dispatch "hl.dsp.focus({ workspace = $WORKSPACE })"
fi
