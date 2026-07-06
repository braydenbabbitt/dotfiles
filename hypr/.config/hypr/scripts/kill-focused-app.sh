#!/usr/bin/env bash
# Smart close for super+q.
#
# Most apps: just close the focused window (normal `killactive` behaviour).
#
# Known-problematic apps (listed below): closing the window doesn't quit the app — it
# re-spawns the window (e.g. Zoom's home window), so a plain close never gets rid of it.
# For those, we fully quit the app by its known process signature instead.
#
# Why match by a hardcoded process signature rather than walking the pid tree: multi-
# process apps like Zoom reparent their children (their live PPID is no longer the
# launcher), so a downward ppid walk misses most of the tree. We also must NEVER kill by
# process GROUP — a window's pgid can include the shell that started the Hyprland session,
# and killing that group takes down the compositor. A per-app pkill pattern is both
# reliable and safely scoped.
set -u

class=$(hyprctl activewindow -j 2>/dev/null | jq -r '.class // empty')

case "$class" in
  # --- known-problematic apps: full quit by process signature ---
  zoom)
    # Covers the launcher (/usr/bin/zoom, /opt/zoom/zoom) and every ZoomWebviewHost child.
    pkill -TERM -f '/opt/zoom/' 2>/dev/null
    pkill -TERM -x zoom 2>/dev/null
    # Escalate to KILL for anything that ignored TERM.
    ( read -rt 2 _ </dev/null 2>/dev/null || true
      pgrep -f '/opt/zoom/' >/dev/null 2>&1 && pkill -KILL -f '/opt/zoom/' 2>/dev/null
      pgrep -x zoom       >/dev/null 2>&1 && pkill -KILL -x zoom 2>/dev/null ) &
    ;;

  # --- everything else: normal window close ---
  *)
    hyprctl dispatch killactive "" >/dev/null 2>&1
    ;;
esac
exit 0
