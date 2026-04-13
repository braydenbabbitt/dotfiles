#!/bin/bash

# Changes the center monitor (DP-2) to MacBook Pro native resolution
# (3024x1964) with 2x scaling for a logical resolution of 1512x982.
# Sunshine streams at 3024x1964 which maps 1:1 to the MacBook's panel
# for maximum crispness. No black bars since aspect ratios match.
# Position is set to 0x0 since this is typically used with single-monitor.sh
# (side monitors disabled). Adjust position if used standalone.

export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export HYPRLAND_INSTANCE_SIGNATURE=$(ls "$XDG_RUNTIME_DIR/hypr/" | head -1)
HYPRCTL="/usr/bin/hyprctl"

# Monitor name mapping — update these if monitor ports change
CENTER="DP-2"

CENTER_MONITOR="$CENTER"

$HYPRCTL keyword monitor "$CENTER_MONITOR,3024x1964@60,0x0,2"
