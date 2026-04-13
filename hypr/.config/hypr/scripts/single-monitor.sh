#!/bin/bash

# Disables the left (HDMI-A-1) and right (DP-3) monitors, leaving only
# the center monitor (DP-2) active.

export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export HYPRLAND_INSTANCE_SIGNATURE=$(ls "$XDG_RUNTIME_DIR/hypr/" | head -1)
HYPRCTL="/usr/bin/hyprctl"

# Monitor name mapping — update these if monitor ports change
LEFT="HDMI-A-1"
CENTER="DP-2"
RIGHT="DP-3"

LEFT_MONITOR="$LEFT"
RIGHT_MONITOR="$RIGHT"

$HYPRCTL keyword monitor "$LEFT_MONITOR,disable"
$HYPRCTL keyword monitor "$RIGHT_MONITOR,disable"
