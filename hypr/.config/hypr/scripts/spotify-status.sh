#!/usr/bin/env bash
# Waybar custom module: show the currently playing Spotify track.
# Outputs JSON for waybar (text + tooltip + class). When Spotify is
# not running or nothing is playing, prints empty JSON so the module
# hides via the .empty class.

set -u

PLAYER="spotify"
MAX_LEN=50

if ! command -v playerctl >/dev/null 2>&1; then
  echo '{"text": "", "class": "empty", "alt": "empty"}'
  exit 0
fi

# Only consider the spotify player; ignore browsers, mpv, etc.
status="$(playerctl --player="$PLAYER" status 2>/dev/null || true)"

if [ -z "$status" ]; then
  # Clear cached art when nothing is playing.
  "$(dirname "$0")/spotify-art.sh" >/dev/null 2>&1 &
  echo '{"text": "", "class": "empty", "alt": "empty"}'
  exit 0
fi

# Refresh cached album art. Run synchronously so the image and text
# update on the same waybar tick; spotify-art.sh short-circuits when
# the URL is unchanged so this is cheap on the common path.
"$(dirname "$0")/spotify-art.sh" >/dev/null 2>&1 || true

artist="$(playerctl --player="$PLAYER" metadata artist 2>/dev/null | tr -d '\r\n' || true)"
title="$(playerctl --player="$PLAYER" metadata title 2>/dev/null | tr -d '\r\n' || true)"
status="$(printf '%s' "$status" | tr -d '\r\n')"

if [ -z "$artist" ] && [ -z "$title" ]; then
  echo '{"text": "", "class": "empty", "alt": "empty"}'
  exit 0
fi

case "$status" in
  Playing) icon="" ; class="playing" ;;
  Paused)  icon="" ; class="paused"  ;;
  *)       icon="" ; class="stopped" ;;
esac

ART_PATH="${XDG_CACHE_HOME:-$HOME/.cache}/waybar-spotify-art.jpg"
if [ ! -s "$ART_PATH" ]; then
  class="$class no-art"
fi

if [ -n "$artist" ] && [ -n "$title" ]; then
  label="$artist - $title"
else
  label="${artist}${title}"
fi

# Truncate for the bar; keep full text in the tooltip.
display="$label"
if [ "${#display}" -gt "$MAX_LEN" ]; then
  display="${display:0:$((MAX_LEN - 1))}…"
fi

# Escape for JSON (backslash, double-quote, control chars handled minimally).
json_escape() {
  printf '%s' "$1" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()), end="")'
}

pango_escape() {
  printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}
display_pango=$(pango_escape "$display")
text_json=$(json_escape "$icon  $display_pango")

tooltip_json=$(json_escape "$status: $label")

printf '{"text": %s, "tooltip": %s, "class": "%s", "alt": "%s"}\n' \
  "$text_json" "$tooltip_json" "$class" "$class"
