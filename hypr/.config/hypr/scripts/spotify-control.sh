#!/usr/bin/env bash
# Waybar custom module for a Spotify control button (prev / next).
#
# Usage: spotify-control.sh <prev|next>
#   Prints JSON {text, class}: the button glyph when Spotify is running,
#   or empty with class "empty" when it is not — so the button collapses
#   (via the .empty CSS rule) whenever Spotify isn't running.
set -u

PLAYER="spotify"

case "${1:-}" in
  prev) glyph=$'' ;;  # previous
  next) glyph=$'' ;;  # next
  *)    glyph="" ;;
esac

if ! command -v playerctl >/dev/null 2>&1; then
  echo '{"text": "", "class": "empty"}'
  exit 0
fi

status="$(playerctl --player="$PLAYER" status 2>/dev/null || true)"

if [ -z "$status" ]; then
  echo '{"text": "", "class": "empty"}'
  exit 0
fi

printf '{"text": "%s", "class": "control"}\n' "$glyph"
