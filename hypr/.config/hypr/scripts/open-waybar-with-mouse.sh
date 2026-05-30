#!/bin/bash
# Reveal Waybar on hover at the top of the screen.
#
# On Hyprland, Waybar's SIGUSR1/mode toggle does NOT move the bar (the
# hide/invisible modes require Sway IPC), so visibility is controlled by
# the process itself: launch waybar to show, kill it to hide.
#
# Behavior:
#   - When waybar is NOT running, dwelling the cursor at the top edge for
#     DWELL_MS launches it. Moving the cursor below the bar kills it again.
#   - If waybar is running because you started it some other way (e.g. the
#     Mod+W toggle), the script leaves it alone — it only ever kills a bar
#     it launched itself.

TOP_ZONE=8        # px from the top edge that counts as "hovering"
DWELL_MS=150      # how long the cursor must stay in the zone before revealing
POLL_MS=40        # cursor poll interval
BAR_HEIGHT=42     # waybar layer height (32px bar + margins); hide below this

waybar_running() { pgrep -x waybar >/dev/null; }

now_ms() { echo $(( $(date +%s%N) / 1000000 )); }

# Wait briefly for the bar to actually appear after launching.
wait_visible() {
  for _ in $(seq 1 30); do
    waybar_running && return 0
    sleep 0.02
  done
  return 1
}

dwell_start=0       # epoch-ms when the cursor entered the top zone (0 = not in zone)
shown_by_script=0   # 1 if we launched the currently-running bar

while true; do
  y=$(hyprctl cursorpos 2>/dev/null | cut -d',' -f2 | tr -d ' ')
  if [[ ! "$y" =~ ^[0-9]+$ ]]; then
    sleep "0.$(printf '%03d' "$POLL_MS")"
    continue
  fi

  if waybar_running; then
    if [ "$shown_by_script" -eq 1 ] && [ "$y" -ge "$BAR_HEIGHT" ]; then
      # We revealed it and the cursor has left the bar — hide it.
      pkill -x waybar
      shown_by_script=0
    fi
    dwell_start=0
  else
    # Bar is hidden. If it disappeared while we owned it, drop ownership.
    shown_by_script=0
    if [ "$y" -le "$TOP_ZONE" ]; then
      if [ "$dwell_start" -eq 0 ]; then
        dwell_start=$(now_ms)
      elif [ $(( $(now_ms) - dwell_start )) -ge "$DWELL_MS" ]; then
        waybar >/dev/null 2>&1 & disown
        wait_visible && shown_by_script=1
        dwell_start=0
      fi
    else
      dwell_start=0
    fi
  fi

  sleep "0.$(printf '%03d' "$POLL_MS")"
done
