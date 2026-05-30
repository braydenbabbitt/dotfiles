#!/usr/bin/env bash
# Downloads the current Spotify track's album art and re-encodes it as
# a square JPEG into a cache file so waybar's image module (and the
# tooltip <img>) can display it.
#
# Requires imagemagick (`magick` v7 or `convert` v6). If neither is
# installed we send a single notify-send per session and fall back to
# writing the raw bytes unchanged.

set -u

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}"
ART_PATH="$CACHE_DIR/waybar-spotify-art.jpg"
URL_STATE="$CACHE_DIR/waybar-spotify-art.url"
EMPTY_PATH="$CACHE_DIR/waybar-spotify-art-empty.jpg"
WARN_FLAG="$CACHE_DIR/waybar-spotify-art.no-magick-warned"

mkdir -p "$CACHE_DIR"

# Locate imagemagick (v7 ships `magick`, v6 ships `convert`).
MAGICK=""
if command -v magick >/dev/null 2>&1; then
  MAGICK="magick"
elif command -v convert >/dev/null 2>&1; then
  MAGICK="convert"
else
  # Warn once per boot so we don't spam every interval tick.
  if [ ! -f "$WARN_FLAG" ] && command -v notify-send >/dev/null 2>&1; then
    notify-send -u normal -a "waybar-spotify" \
      "Album art: imagemagick missing" \
      "Install imagemagick (pacman -S imagemagick) so waybar can render the Spotify album art cleanly."
    touch "$WARN_FLAG"
  fi
fi

# Tiny placeholder JPEG (8x8 black) for the "nothing playing" state.
# Built once with imagemagick if available; otherwise we just truncate
# the art file so waybar shows nothing.
ensure_empty() {
  if [ -f "$EMPTY_PATH" ]; then return; fi
  if [ -n "$MAGICK" ]; then
    "$MAGICK" -size 8x8 xc:none -background none "$EMPTY_PATH" 2>/dev/null || true
  fi
}

url="$(playerctl --player=spotify metadata mpris:artUrl 2>/dev/null | tr -d '\r\n' || true)"

if [ -z "$url" ]; then
  # No track — remove the cached image so waybar's image module hides.
  rm -f "$ART_PATH" "$URL_STATE"
  exit 0
fi

prev_url=""
[ -f "$URL_STATE" ] && prev_url="$(cat "$URL_STATE")"

if [ "$url" = "$prev_url" ] && [ -s "$ART_PATH" ]; then
  exit 0
fi

TMP_RAW="$ART_PATH.raw"
if ! curl -fsSL --max-time 5 "$url" -o "$TMP_RAW" 2>/dev/null; then
  rm -f "$TMP_RAW"
  exit 0
fi

if [ -n "$MAGICK" ]; then
  if "$MAGICK" "$TMP_RAW" -resize 256x256^ -gravity center -extent 256x256 -quality 85 "$ART_PATH.tmp" 2>/dev/null; then
    mv -f "$ART_PATH.tmp" "$ART_PATH"
    printf '%s' "$url" > "$URL_STATE"
  else
    rm -f "$ART_PATH.tmp"
  fi
else
  mv -f "$TMP_RAW" "$ART_PATH"
  printf '%s' "$url" > "$URL_STATE"
fi
rm -f "$TMP_RAW"
