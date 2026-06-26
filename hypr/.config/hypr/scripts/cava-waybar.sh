#!/usr/bin/env bash
# Waybar audio visualizer: stream cava's raw-ascii frames and map each
# bar value (0..7) to a block glyph, printing one line per frame.
#
# Used by the custom/cava module as a continuous exec (no "interval",
# no "return-type"): waybar keeps this process alive and treats each
# newline-terminated line of stdout as a new module value.
set -u

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/cava/config"

if ! command -v cava >/dev/null 2>&1; then
  # cava not installed yet: emit one empty line so the module renders
  # blank instead of erroring. Install with: pacman -S cava
  echo ""
  exit 0
fi

# Resolve the monitor of the *current* default sink so the bars react to
# whatever is actually playing, even after switching outputs. cava's
# `source = auto` does not reliably pick the running monitor on PipeWire,
# so we pin it explicitly via a runtime config copy.
build_runtime_config() {
  local monitor=""
  if command -v pactl >/dev/null 2>&1; then
    local sink
    sink="$(pactl get-default-sink 2>/dev/null || true)"
    [ -n "$sink" ] && monitor="${sink}.monitor"
  fi

  if [ -z "$monitor" ]; then
    # Fall back to the config as-is (source = auto).
    printf '%s' "$CONFIG"
    return
  fi

  local rt="${XDG_RUNTIME_DIR:-/tmp}/cava-waybar.config"
  # Copy the base config but force the resolved monitor as the source.
  sed -E "s|^[[:space:]]*source[[:space:]]*=.*|source = ${monitor}|" "$CONFIG" > "$rt" 2>/dev/null \
    && { printf '%s' "$rt"; return; }
  printf '%s' "$CONFIG"
}

# Index 0..7 -> block glyphs. Index 0 is a space so silence renders
# blank rather than a static baseline row.
BLOCKS=(' ' '▁' '▂' '▃' '▄' '▅' '▆' '▇')

# Per-height color ramp (Pango markup): low bars stay Spotify green and
# escalate through lime/amber to hot red at the peak, so the bars react
# to their own height. Index matches the BLOCKS height level (1..7);
# index 0 (silence) is uncolored.
COLORS=('' '#1db954' '#1db954' '#1ed760' '#7FFF00' '#FFD700' '#FFA500' '#FF4040')

RUNTIME_CONFIG="$(build_runtime_config)"

# Gate the visualizer on Spotify: cava reads the whole output monitor,
# but we only render bars while Spotify is actively Playing. When it is
# paused/stopped (or some other app is making noise), we emit blank bars
# so the module reacts to music, not arbitrary system audio.
#
# Re-checking playerctl on every frame (~30/s) would be wasteful, so we
# poll it once every CHECK_EVERY frames and cache the result.
CHECK_EVERY=10
frame=0
playing=0

spotify_playing() {
  [ "$(playerctl --player=spotify status 2>/dev/null)" = "Playing" ]
}

# stdbuf -oL keeps cava line-buffered through the pipe so frames arrive
# promptly instead of sitting in a block buffer.
stdbuf -oL cava -p "$RUNTIME_CONFIG" 2>/dev/null | while IFS= read -r line; do
  if [ $((frame % CHECK_EVERY)) -eq 0 ]; then
    if spotify_playing; then playing=1; else playing=0; fi
  fi
  frame=$((frame + 1))

  if [ "$playing" -eq 0 ]; then
    # Spotify not playing: render nothing.
    printf '\n'
    continue
  fi

  out=""
  IFS=';' read -ra vals <<< "$line"
  for v in "${vals[@]}"; do
    # Skip anything that isn't a plain integer (guards against stray
    # control/escape bytes leaking into the stream).
    case "$v" in
      ''|*[!0-9]*) continue ;;
    esac
    [ "$v" -gt 7 ] && v=7
    glyph="${BLOCKS[$v]}"
    color="${COLORS[$v]}"
    if [ -n "$color" ]; then
      out+="<span color='$color'>$glyph</span>"
    else
      out+="$glyph"
    fi
  done
  printf '%s\n' "$out"
done
