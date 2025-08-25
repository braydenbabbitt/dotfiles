#!/bin/bash
trap '' SIGUSR1 SIGUSR2

WAYBAR_PID=$(pgrep waybar)
SCREEN_HEIGHT=$(hyprctl monitors -j | jq '.[0].height')
CLOSED_TRIGGER_ZONE=10
OPEN_TRIGGER_ZONE=32
DELAY_TIME=0 # seconds to wait before showing waybar

at_top_start_time=0
waybar_temporarily_visible=false

# Function to check if waybar is visible (you might need to adjust this)
is_waybar_visible() {
  hyprctl layers -j | jq -r 'to_entries[] | .value.levels."2"[]? | select(.namespace == "waybar" and .h > 0) | [.namespace, .h] | @tsv' | while IFS=$'\t' read -r namespace height; do
    echo "DEBUG: namespace=$namespace height=$height" >&2
    if [ "$height" -gt 0 ]; then
      return 0
    fi
  done
  return 1
}

# TODO: fix this from repeatedly opening

while true; do
  # Get cursor position
  CURSOR_INFO=$(hyprctl cursorpos)
  Y_POS=$(echo $CURSOR_INFO | cut -d',' -f2 | tr -d ' ')

  current_time=$(date +%s.%N)

  # Update WAYBAR_PID in case Waybar is restarted
  WAYBAR_PID=$(pgrep waybar)

  # DEBUG: Call is_waybar_visible and print exit code
  is_waybar_visible
  waybar_visible_status=$?
  echo "is_waybar_visible exit status: $waybar_visible_status"
  # echo "Y_POS: $Y_POS, WAYBAR_PID: $WAYBAR_PID, waybar_temporarily_visible: $waybar_temporarily_visible, waybar_visible: $(is_waybar_visible), at_top_start_time: $at_top_start_time"

  # Only show Waybar if it is closed and not shown by script
  if [ "$waybar_temporarily_visible" = false ] && ! is_waybar_visible; then
    TRIGGER_ZONE=$CLOSED_TRIGGER_ZONE
    if [ "$Y_POS" -le "$TRIGGER_ZONE" ]; then
      if [ "$at_top_start_time" = "0" ]; then
        at_top_start_time=$current_time
      else
        elapsed=$(echo "$current_time - $at_top_start_time" | bc -l)
        if (($(echo "$elapsed >= $DELAY_TIME" | bc -l))); then
          kill -SIGUSR2 $WAYBAR_PID 2>/dev/null
          sleep 0.1 # Wait for Waybar to become visible
          if is_waybar_visible; then
            waybar_temporarily_visible=true
            at_top_start_time=0
          fi
        fi
      fi
    else
      at_top_start_time=0
    fi
  fi

  # Only hide Waybar if it was shown by the script
  if [ "$waybar_temporarily_visible" = true ]; then
    TRIGGER_ZONE=$CLOSED_TRIGGER_ZONE
    if is_waybar_visible; then
      if [ "$Y_POS" -gt "$TRIGGER_ZONE" ]; then
        waybar_temporarily_visible=false
        at_top_start_time=0
        kill -SIGUSR1 $WAYBAR_PID 2>/dev/null
      fi
    else
      # Waybar was closed by another mechanism, reset the flag
      waybar_temporarily_visible=false
      at_top_start_time=0
    fi
  fi

  # When Waybar is visible and not shown by script, do absolutely nothing

  sleep 0.05
done
