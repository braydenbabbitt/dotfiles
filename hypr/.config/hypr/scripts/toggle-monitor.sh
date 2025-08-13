#!/bin/bash

MONITOR="DP-3"

if hyprctl monitors | grep -q "^Monitor $MONITOR"; then
  hyprctl keyword monitor "$MONITOR,disable"
  notify-send "Monitor" "$MONITOR disabled"
else
  hyprctl keyword monitor "$MONITOR,3840x1600,1920x-200,1"
  notify-send "Monitor" "$MONITOR enabled"
fi
