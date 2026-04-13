#!/bin/bash

# Re-enables the left (HDMI-A-1) and right (DP-3) monitors with their
# original configuration.

export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export HYPRLAND_INSTANCE_SIGNATURE=$(ls "$XDG_RUNTIME_DIR/hypr/" | head -1)
HYPRCTL="/usr/bin/hyprctl"

# Monitor name mapping — update these if monitor ports change
LEFT="HDMI-A-1"
CENTER="DP-2"
RIGHT="DP-3"

LEFT_MONITOR_CONFIG="$LEFT,2560x1440@144,0x0,1"
RIGHT_MONITOR_CONFIG="$RIGHT,2560x1440@144,5120x0,1"

$HYPRCTL keyword monitor "$LEFT_MONITOR_CONFIG"
$HYPRCTL keyword monitor "$RIGHT_MONITOR_CONFIG"
