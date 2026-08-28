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
#
# Rate limiting. api/oauth/usage is aggressively rate limited — roughly a
# handful of requests before it returns 429 with a retry-after measured in
# minutes. Two things here keep us under that ceiling:
#
#   1. The response is cached on disk (CACHE_FILE) and reused for CACHE_TTL
#      seconds. Waybar instantiates this module once PER OUTPUT, each with its
#      own independent timer, so on a 3-monitor setup three copies fire at
#      essentially the same instant. Without a shared cache that is 3x the
#      request rate and enough to trip the limit in a single tick. The first
#      instance to win the lock fetches; the others read what it wrote.
#   2. On any fetch failure the last good response is served instead of empty
#      output, so a 429 shows slightly stale numbers rather than making the
#      module vanish for the whole retry-after window.

set -u

CREDS="$HOME/.claude/.credentials.json"
USAGE_URL="https://api.anthropic.com/api/oauth/usage"
TOKEN_URL="https://platform.claude.com/v1/oauth/token"
CLIENT_ID="9d1c250a-e61b-44d9-88ed-5944d1962f5e"
BETA_HEADER="anthropic-beta: oauth-2025-04-20"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}"
STATE_FILE="$CACHE_DIR/waybar-claude-usage-tracker"
CACHE_FILE="$CACHE_DIR/waybar-claude-usage-response.json"
LOCK_FILE="$CACHE_DIR/waybar-claude-usage.lock"
# Serve the cached response rather than refetching if it is younger than this.
# Slightly under the module's poll interval so a tick isn't skipped outright,
# while still collapsing the simultaneous per-output calls into one request.
CACHE_TTL=240
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

mkdir -p "$CACHE_DIR"

cache_age() {
  local mtime
  mtime=$(stat -c %Y "$CACHE_FILE" 2>/dev/null) || { echo 999999; return; }
  echo $(( $(date +%s) - mtime ))
}

# Echo the cached response if it is valid JSON, else nothing.
read_cache() {
  [ -f "$CACHE_FILE" ] || return 1
  local c
  c=$(cat "$CACHE_FILE" 2>/dev/null) || return 1
  printf '%s' "$c" | jq -e . >/dev/null 2>&1 || return 1
  printf '%s' "$c"
}

# A fresh cache short-circuits everything below, including the credential read
# and the token-expiry check — no point touching either if we aren't fetching.
response=""
if [ "$(cache_age)" -lt "$CACHE_TTL" ]; then
  response=$(read_cache) || response=""
fi

if [ -z "$response" ]; then
# ---- cache miss: one instance fetches, the rest reuse its result ----------
# Serialize the per-output instances. Whoever gets the lock does the fetch;
# the others block briefly and then re-read the cache it just wrote, turning
# N simultaneous requests into one.
exec 9>"$LOCK_FILE"
flock 9 2>/dev/null || true

# The lock holder may have just refreshed the cache while we waited.
if [ "$(cache_age)" -lt "$CACHE_TTL" ]; then
  response=$(read_cache) || response=""
fi
fi

if [ -z "$response" ]; then

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

if [ -n "$response" ] && printf '%s' "$response" | jq -e . >/dev/null 2>&1; then
  # Write via temp file + rename so a reader never sees a partial response.
  tmp=$(mktemp "$CACHE_FILE.XXXXXX" 2>/dev/null) && {
    printf '%s\n' "$response" > "$tmp" && mv -f "$tmp" "$CACHE_FILE" || rm -f "$tmp"
  }
else
  # Fetch failed (429, network blip, expired token). Fall back to the last good
  # response regardless of age — stale numbers beat a module that disappears.
  response=$(read_cache) || empty
fi

fi  # end cache-miss branch

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
