#!/usr/bin/env bash
# Open Spotify, or focus its window if it's already running.
#
# Spotify is launched at startup onto workspace 12 (see hyprland.conf:
# `exec-once = [workspace 12 silent] spotify-launcher`). If a window exists we
# jump focus to it on whatever workspace it lives on; otherwise we launch it.
set -u

# Spotify's window class is "Spotify"; match case-insensitively to be safe.
if hyprctl -j clients 2>/dev/null | grep -iq '"class": *"spotify"'; then
  hyprctl dispatch focuswindow 'class:(?i)spotify' >/dev/null 2>&1
else
  hyprctl dispatch exec spotify-launcher >/dev/null 2>&1 \
    || spotify-launcher >/dev/null 2>&1 &
fi
