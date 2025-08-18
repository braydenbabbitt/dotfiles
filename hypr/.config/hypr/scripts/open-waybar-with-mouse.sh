#!/bin/bash
trap '' SIGUSR1 SIGUSR2

WAYBAR_PID=$(pgrep waybar)
SCREEN_HEIGHT=$(hyprctl monitors -j | jq '.[0].height')
CLOSED_TRIGGER_ZONE=10
OPEN_TRIGGER_ZONE=32
DELAY_TIME=0 # seconds to wait before showing waybar

at_top_start_time=0
waybar_visible=false

# Function to check if waybar is visible (you might need to adjust this)
is_waybar_visible() {
  hyprctl clients -j | jq -r '.[] | select(.class=="waybar") | [.mapped, .geometry.height] | @tsv' | while IFS=$'\t' read -r mapped height; do
    if [ "$mapped" = true ] && [ "$height" -gt 0 ]; then
      return 0
    fi
  done
  return 1
}

while true; do
  # Get cursor position
  CURSOR_INFO=$(hyprctl cursorpos)
  Y_POS=$(echo $CURSOR_INFO | cut -d',' -f2 | tr -d ' ')

  current_time=$(date +%s.%N)

  # Update WAYBAR_PID in case Waybar is restarted
  WAYBAR_PID=$(pgrep waybar)
  if [ "$waybar_visible" = true ]; then
    TRIGGER_ZONE=$OPEN_TRIGGER_ZONE
  else
    TRIGGER_ZONE=$CLOSED_TRIGGER_ZONE
  fi

  if [ "$Y_POS" -le "$TRIGGER_ZONE" ]; then
    # Cursor is at the top
    if [ "$at_top_start_time" = "0" ]; then
      # Just entered the top zone, start timing
      at_top_start_time=$current_time
    elif [ "$waybar_visible" = false ]; then
      # Check if enough time has passed
      elapsed=$(echo "$current_time - $at_top_start_time" | bc -l)
      if (($(echo "$elapsed >= $DELAY_TIME" | bc -l))); then
        # Show waybar
        kill -SIGUSR2 $WAYBAR_PID 2>/dev/null
        waybar_visible=true
      fi
    fi
  else
    # Cursor left the top zone
    at_top_start_time=0

    if [ "$waybar_visible" = true ]; then
      # Hide waybar immediately
      kill -SIGUSR1 $WAYBAR_PID 2>/dev/null
      waybar_visible=false
    fi
  fi

  sleep 0.05
done
