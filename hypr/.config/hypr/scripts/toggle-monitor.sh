#!/bin/bash

MONITOR="HDMI-A-1"
MONITOR_CONFIG="HDMI-A-1,2560x1440@144,0x0,1"

if hyprctl monitors | grep -q "^Monitor $MONITOR"; then
  hyprctl keyword monitor "$MONITOR,disable"
  notify-send "Monitor" "$MONITOR disabled"
else
  hyprctl keyword monitor "$MONITOR_CONFIG"
  notify-send "Monitor" "$MONITOR enabled"
fi
