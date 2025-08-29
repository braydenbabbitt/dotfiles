#!/bin/bash

# Usage: change-monitor-scaling.sh <scaling_factor>
if [ -z "$1" ]; then
  SCALING=1
else
  SCALING="$1"
fi

# Find the currently focused monitor's name
MONITOR=$(hyprctl monitors | awk '/Monitor/{name=$2} /focused: yes/{print name}')

if [ -z "$MONITOR" ]; then
  echo "Could not determine the focused monitor."
  exit 2
fi

# Apply the scaling to the focused monitor
RESOLUTION=$(hyprctl monitors | awk -v mon="$MONITOR" '/Monitor/{name=$2} $2==mon {getline; split($1,a,"@"); print a[1]}' | head -n1)
REFRESH=$(hyprctl monitors | awk -v mon="$MONITOR" '/Monitor/{name=$2} $2==mon {getline; split($1,a,"@"); print a[2]}' | head -n1)
POSITION=$(hyprctl monitors | awk -v mon="$MONITOR" '/Monitor/{name=$2} $2==mon {getline; print $4}' | head -n1)

# Fallbacks if parsing fails
if [ -z "$RESOLUTION" ]; then RESOLUTION="2560x1440"; fi
if [ -z "$REFRESH" ]; then REFRESH="144.00"; fi
if [ -z "$POSITION" ]; then POSITION="2560x0"; fi

hyprctl keyword monitor "$MONITOR,$RESOLUTION@$REFRESH,$POSITION,$SCALING"
notify-send "Monitor Scaling" "Set scaling of $MONITOR to $SCALING with $RESOLUTION@$REFRESH at $POSITION"
