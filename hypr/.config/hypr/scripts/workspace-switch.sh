#!/usr/bin/env bash
# Switch to workspace N on the currently focused monitor.
# Usage: workspace-switch.sh <1-5> [move]
# If "move" is passed as $2, moves the active window to that workspace instead.

NUM="$1"
ACTION="$2"

FOCUSED_MONITOR=$(hyprctl monitors -j | jq -r '.[] | select(.focused==true) | .name')

case "$FOCUSED_MONITOR" in
  HDMI-A-1) OFFSET=0 ;;
  DP-2)     OFFSET=5 ;;
  DP-3)     OFFSET=10 ;;
  *)        OFFSET=0 ;;
esac

WORKSPACE=$((NUM + OFFSET))

if [ "$ACTION" = "move" ]; then
  hyprctl dispatch movetoworkspace "$WORKSPACE"
else
  hyprctl dispatch workspace "$WORKSPACE"
fi
