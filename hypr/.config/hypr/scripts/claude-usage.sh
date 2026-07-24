#!/usr/bin/env bash
# Waybar custom module: surface Claude Code usage quota by calling Anthropic's
# oauth/usage endpoint directly, using the OAuth token the Claude CLI already
# stores in ~/.claude/.credentials.json. No local proxy/daemon required.
#
# If credentials are missing or the endpoint isn't reachable, output empty JSON
# so waybar hides the module.
#
# Click to cycle the bucket displayed in the bar; the tooltip always lists every
# available bucket and marks the active one. The access token is refreshed via
# the stored refresh token when it has expired, and written back so the CLI
# stays in sync.

set -u

CREDS="$HOME/.claude/.credentials.json"
USAGE_URL="https://api.anthropic.com/api/oauth/usage"
TOKEN_URL="https://platform.claude.com/v1/oauth/token"
CLIENT_ID="9d1c250a-e61b-44d9-88ed-5944d1962f5e"
BETA_HEADER="anthropic-beta: oauth-2025-04-20"
STATE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/waybar-claude-usage-tracker"
SIGNAL=8
# The buckets to cycle through in the bar, in order. Buckets the plan doesn't
# provide come back null from the endpoint and are skipped in the tooltip.
TRACKERS=(five_hour seven_day seven_day_sonnet seven_day_omelette)

empty() {
  printf '{"text":"","tooltip":""}\n'
  exit 0
}

current_tracker() {
  if [ -f "$STATE_FILE" ]; then
    cat "$STATE_FILE"
  else
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
  echo "five_hour"
}

if [ "${1:-}" = "cycle" ]; then
  next=$(next_tracker "$(current_tracker)")
  mkdir -p "$(dirname "$STATE_FILE")"
  printf '%s\n' "$next" > "$STATE_FILE"
  pkill -RTMIN+$SIGNAL waybar 2>/dev/null || true
  exit 0
fi

[ -f "$CREDS" ] || empty

# --- token handling: refresh in-place when expired ------------------------
access_token=$(jq -r '.claudeAiOauth.accessToken // empty' "$CREDS" 2>/dev/null)
expires_at=$(jq -r '.claudeAiOauth.expiresAt // 0' "$CREDS" 2>/dev/null)
[ -n "$access_token" ] || empty

now_ms=$(( $(date +%s) * 1000 ))
# Refresh a minute early to avoid racing the expiry.
if [ "$expires_at" -le "$(( now_ms + 60000 ))" ] 2>/dev/null; then
  refresh_token=$(jq -r '.claudeAiOauth.refreshToken // empty' "$CREDS" 2>/dev/null)
  if [ -n "$refresh_token" ]; then
    body=$(jq -n -c \
      --arg ct refresh_token --arg cid "$CLIENT_ID" --arg rt "$refresh_token" \
      '{grant_type: $ct, client_id: $cid, refresh_token: $rt}')
    resp=$(curl -s -m 25 -X POST "$TOKEN_URL" \
      -H "Content-Type: application/json" \
      -H "$BETA_HEADER" \
      -H "User-Agent: claude-cli/1.0" \
      -d "$body" 2>/dev/null) || resp=""
    new_access=$(printf '%s' "$resp" | jq -r '.access_token // empty' 2>/dev/null)
    if [ -n "$new_access" ]; then
      new_refresh=$(printf '%s' "$resp" | jq -r '.refresh_token // empty' 2>/dev/null)
      [ -n "$new_refresh" ] || new_refresh="$refresh_token"
      expires_in=$(printf '%s' "$resp" | jq -r '.expires_in // 3600' 2>/dev/null)
      case "$expires_in" in ''|*[!0-9]*) expires_in=3600 ;; esac
      new_expires=$(( ( $(date +%s) * 1000 ) + (expires_in * 1000) ))
      updated=$(jq -c \
        --arg at "$new_access" --arg rt "$new_refresh" --argjson ea "$new_expires" \
        '.claudeAiOauth.accessToken = $at
         | .claudeAiOauth.refreshToken = $rt
         | .claudeAiOauth.expiresAt = $ea' "$CREDS" 2>/dev/null)
      if [ -n "$updated" ]; then
        printf '%s\n' "$updated" > "$CREDS"
        chmod 600 "$CREDS" 2>/dev/null || true
      fi
      access_token="$new_access"
    fi
    # If refresh failed, fall through and try the (possibly stale) token anyway.
  fi
fi

# --- fetch usage ------------------------------------------------------------
response=$(curl -s -m 10 -f "$USAGE_URL" \
  -H "Authorization: Bearer $access_token" \
  -H "$BETA_HEADER" 2>/dev/null) || response=""

if [ -z "$response" ] || ! printf '%s' "$response" | jq -e . >/dev/null 2>&1; then
  empty
fi

label_for() {
  case "$1" in
    five_hour) echo "5-hour" ;;
    seven_day) echo "7-day" ;;
    seven_day_sonnet) echo "7-day Sonnet" ;;
    seven_day_omelette) echo "7-day Opus" ;;
    *) echo "$1" ;;
  esac
}

# The endpoint returns resets_at as an ISO-8601 timestamp.
format_time() {
  local iso="$1"
  if [ -z "$iso" ] || [ "$iso" = "null" ]; then
    echo ""
    return
  fi
  local secs target_date today_date yesterday_date tomorrow_date time_str
  secs=$(date -d "$iso" "+%s" 2>/dev/null) || { echo ""; return; }
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

# Each tracker is a top-level object keyed by name; null means the plan doesn't
# have that bucket, so skip it. utilization is already a 0..100 percentage.
for type in "${TRACKERS[@]}"; do
  read -r util resets < <(printf '%s' "$response" \
    | jq -r --arg t "$type" '
        (.[$t]) as $b
        | if $b == null then "SKIP -"
          else "\($b.utilization // 0) \($b.resets_at // "null")"
          end')
  [ "$util" = "SKIP" ] && continue
  pct_int=$(awk -v u="$util" 'BEGIN { printf "%d", u+0.5 }')
  pcts[$type]=$pct_int
  resets_strs[$type]=$(format_time "$resets")
  buckets_order+=("$type")
done

# If the selected bucket isn't available, fall back to the first available one.
if [ -z "${pcts[$selected]:-}" ]; then
  selected="${buckets_order[0]:-five_hour}"
fi

primary_type=$selected
primary_pct=${pcts[$selected]:-0}

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
