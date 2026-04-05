#!/usr/bin/env bash

sleep 2

WALLPAPER_DIR="$HOME/pictures/wallpapers"
WALLPAPER=$(find "$WALLPAPER_DIR" -type f | shuf -n 1)

# hyprpaper 0.8+ is IPC-only via hyprctl
# Ensure hyprpaper is running
if ! pgrep -x hyprpaper > /dev/null; then
    hyprpaper &
    sleep 2
fi

# Set wallpaper on all monitors
for monitor in $(hyprctl monitors -j | jq -r '.[].name'); do
    hyprctl hyprpaper wallpaper "$monitor,$WALLPAPER"
done
