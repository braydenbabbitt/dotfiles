#!/bin/bash

# Restores the center monitor (DP-2) to its original resolution,
# position, and scale (1x) from hyprland.conf.

export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export HYPRLAND_INSTANCE_SIGNATURE=$(ls "$XDG_RUNTIME_DIR/hypr/" | head -1)
HYPRCTL="/usr/bin/hyprctl"

# Monitor name mapping — update these if monitor ports change
CENTER="DP-2"

CENTER_MONITOR_CONFIG="$CENTER,2560x1440@144,2560x0,1"

$HYPRCTL keyword monitor "$CENTER_MONITOR_CONFIG"
