#!/usr/bin/env bash
# Waybar play/pause button for Spotify.
#
#   (no arg)  print JSON {text, class, tooltip} with the glyph reflecting
#             the current playback state.
#   toggle    flip playback, then signal waybar (SIGRTMIN+9) so this
#             module's glyph refreshes immediately instead of waiting for
#             the next interval tick.
set -u

PLAYER="spotify"
SIGNAL=9

if ! command -v playerctl >/dev/null 2>&1; then
  echo '{"text": "", "class": "empty", "tooltip": "playerctl not installed"}'
  exit 0
fi

if [ "${1:-}" = "toggle" ]; then
  playerctl --player="$PLAYER" play-pause 2>/dev/null || true
  pkill -RTMIN+"$SIGNAL" waybar 2>/dev/null || true
  exit 0
fi

status="$(playerctl --player="$PLAYER" status 2>/dev/null || true)"
status="$(printf '%s' "$status" | tr -d '\r\n')"

case "$status" in
  Playing) glyph="" ; class="playing" ;;   # show pause icon (click to pause)
  Paused)  glyph="" ; class="paused"  ;;   # show play icon (click to play)
  *)       glyph="" ; class="stopped" ;;
esac

# The text is a single static glyph (no user data), so a hand-rolled
# printf JSON is safe here.
printf '{"text": "%s", "class": "%s", "tooltip": "%s"}\n' \
  "$glyph" "$class" "${status:-Stopped}"
