#!/bin/bash
#
# Restore the center monitor (DP-2) to its native config from hyprland.conf
# (2560x1440@144, position 2560x0, 1x scale). Used as a Sunshine prep "undo".

export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export HYPRLAND_INSTANCE_SIGNATURE=$(ls "$XDG_RUNTIME_DIR/hypr/" | head -1)
HYPRCTL="/usr/bin/hyprctl"

# Monitor name mapping — update these if monitor ports change
CENTER="DP-2"

# `hyprctl keyword` is rejected under Hyprland 0.55+'s Lua parser; use eval.
$HYPRCTL eval "hl.monitor({ output = \"$CENTER\", mode = \"2560x1440@144\", position = \"2560x0\", scale = 1, disabled = false })"
