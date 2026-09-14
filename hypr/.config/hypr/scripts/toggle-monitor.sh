#!/bin/bash

# Monitor name mapping — update these if monitor ports change
LEFT="HDMI-A-1"

MONITOR="$LEFT"

# `hyprctl keyword` is rejected under Hyprland 0.55+'s Lua parser; monitor
# changes go through `hyprctl eval` with an hl.monitor() call.
if hyprctl monitors | grep -q "^Monitor $MONITOR"; then
	hyprctl eval "hl.monitor({ output = \"$MONITOR\", disabled = true })"
	notify-send "Monitor" "$MONITOR disabled"
else
	hyprctl eval "hl.monitor({ output = \"$MONITOR\", mode = \"2560x1440@144\", position = \"0x0\", scale = 1, disabled = false })"
	notify-send "Monitor" "$MONITOR enabled"
fi
