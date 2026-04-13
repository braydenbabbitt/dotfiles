#!/bin/bash

# Monitor name mapping — update these if monitor ports change
LEFT="HDMI-A-1"

MONITOR="$LEFT"
MONITOR_CONFIG="$LEFT,2560x1440@144,0x0,1"

if hyprctl monitors | grep -q "^Monitor $MONITOR"; then
	hyprctl keyword monitor "$MONITOR,disable"
	notify-send "Monitor" "$MONITOR disabled"
else
	hyprctl keyword monitor "$MONITOR_CONFIG"
	notify-send "Monitor" "$MONITOR enabled"
fi
