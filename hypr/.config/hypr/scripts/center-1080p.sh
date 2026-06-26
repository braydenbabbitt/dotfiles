#!/bin/bash
#
# Switch the center monitor (DP-2) to 1080p for remote streaming.
#
# Sets 1920x1080@144 at 1x scale. Position is 0x0 since this is paired with
# single-monitor.sh (side monitors disabled). Used as a Sunshine prep "do".

export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export HYPRLAND_INSTANCE_SIGNATURE=$(ls "$XDG_RUNTIME_DIR/hypr/" | head -1)
HYPRCTL="/usr/bin/hyprctl"

# Monitor name mapping — update these if monitor ports change
CENTER="DP-2"

$HYPRCTL keyword monitor "$CENTER,1920x1080@144,0x0,1"
