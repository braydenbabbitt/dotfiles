#!/usr/bin/env bash
# Waybar custom module: surface Meridian usage when a local quota
# server is running at http://localhost:3456. If the server isn't
# reachable, output empty JSON so waybar hides the module.
#
# Click to cycle the bucket displayed in the bar; the tooltip always
# lists every bucket and marks the active one.

set -u

URL="http://localhost:3456/v1/usage/quota"
STATE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/waybar-meridian-tracker"
SIGNAL=8
# Re-add "max" to the front of TRACKERS (and the related blocks below)
# if you switch to a Max plan and want the bar to auto-show the highest bucket.
# TRACKERS=(max five_hour seven_day seven_day_sonnet seven_day_omelette)
TRACKERS=(five_hour seven_day seven_day_sonnet seven_day_omelette)

current_tracker() {
  if [ -f "$STATE_FILE" ]; then
    cat "$STATE_FILE"
  else
    # echo "max"
    echo "five_hour"
  fi
}

next_tracker() {
  local cur="$1" i=0
  for t in "${TRACKERS[@]}"; do
    if [ "$t" = "$cur" ]; then
      echo "${TRACKERS[$(( (i + 1) % ${#TRACKERS[@]} ))]}"
      return
    fi
    i=$(( i + 1 ))
  done
  # echo "max"
  echo "five_hour"
}

if [ "${1:-}" = "cycle" ]; then
  next=$(next_tracker "$(current_tracker)")
  mkdir -p "$(dirname "$STATE_FILE")"
  printf '%s\n' "$next" > "$STATE_FILE"
  pkill -RTMIN+$SIGNAL waybar 2>/dev/null || true
  exit 0
fi

response=$(curl -s -m 1 -f "$URL" 2>/dev/null) || response=""

if [ -z "$response" ] || ! printf '%s' "$response" | jq -e . >/dev/null 2>&1; then
  printf '{"text":"","tooltip":""}\n'
  exit 0
fi

label_for() {
  case "$1" in
    # max) echo "Max" ;;
    five_hour) echo "5-hour" ;;
    seven_day) echo "7-day" ;;
    seven_day_sonnet) echo "7-day Sonnet" ;;
    seven_day_omelette) echo "7-day Opus" ;;
    *) echo "$1" ;;
  esac
}

format_time() {
  local ms="$1"
  if [ -z "$ms" ] || [ "$ms" = "null" ]; then
    echo ""
    return
  fi
  local secs=$(( ms / 1000 ))
  local target_date today_date yesterday_date tomorrow_date time_str
  target_date=$(date -d "@$secs" "+%Y-%m-%d")
  today_date=$(date "+%Y-%m-%d")
  yesterday_date=$(date -d "yesterday" "+%Y-%m-%d")
  tomorrow_date=$(date -d "tomorrow" "+%Y-%m-%d")
  time_str=$(date -d "@$secs" "+%-I:%M %p")
  case "$target_date" in
    "$today_date") echo "${time_str}" ;;
    "$tomorrow_date") echo "Tomorrow ${time_str}" ;;
    "$yesterday_date") echo "Yesterday ${time_str}" ;;
    *) date -d "@$secs" "+%a %b %-d %-I:%M %p" ;;
  esac
}

selected=$(current_tracker)

declare -A pcts resets_strs
buckets_order=()
# max_pct=0
# max_pct_type=""

while IFS='|' read -r type util resets; do
  pct_int=$(awk -v u="$util" 'BEGIN { printf "%d", (u*100)+0.5 }')
  pcts[$type]=$pct_int
  resets_strs[$type]=$(format_time "$resets")
  buckets_order+=("$type")
  # if [ "$pct_int" -gt "$max_pct" ]; then
  #   max_pct=$pct_int
  #   max_pct_type=$type
  # fi
done < <(printf '%s' "$response" | jq -r '.buckets[] | "\(.type)|\(.utilization)|\(.resetsAt)"')

# if [ "$selected" = "max" ]; then
#   primary_type=${max_pct_type:-${buckets_order[0]:-}}
#   primary_pct=$max_pct
# else
primary_type=$selected
primary_pct=${pcts[$selected]:-0}
# fi

tooltip=""
for type in "${buckets_order[@]}"; do
  label=$(label_for "$type")
  pct=${pcts[$type]}
  reset=${resets_strs[$type]}
  if [ "$type" = "$primary_type" ]; then
    marker="▶ "
  else
    marker="  "
  fi
  if [ -n "$reset" ]; then
    line="${marker}${label}: ${pct}% (resets ${reset})"
  else
    line="${marker}${label}: ${pct}%"
  fi
  if [ -n "$tooltip" ]; then
    tooltip="${tooltip}"$'\n'
  fi
  tooltip="${tooltip}${line}"
done

mode_label=$(label_for "$selected")
tooltip="Mode: ${mode_label} (click to cycle)"$'\n'"${tooltip}"

text="<span color='#9f79f7'> 󰚩 </span>${primary_pct}% "

jq -n -c --arg text "$text" --arg tooltip "$tooltip" '{text: $text, tooltip: $tooltip}'
