#!/bin/bash

# Restores the center monitor (DP-2) to its original resolution,
# position, and scale (1x) from hyprland.conf.

export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export HYPRLAND_INSTANCE_SIGNATURE=$(ls "$XDG_RUNTIME_DIR/hypr/" | head -1)
HYPRCTL="/usr/bin/hyprctl"

# Monitor name mapping — update these if monitor ports change
CENTER="DP-2"

# `hyprctl keyword` is rejected under Hyprland 0.55+'s Lua parser; use eval.
$HYPRCTL eval "hl.monitor({ output = \"$CENTER\", mode = \"2560x1440@144\", position = \"2560x0\", scale = 1, disabled = false })"
