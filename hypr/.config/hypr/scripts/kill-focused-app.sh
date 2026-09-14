#!/usr/bin/env bash
# Smart close for super+q.
#
# Currently this just closes the focused window (normal `killactive`). It stays a
# dedicated script (rather than inlining `killactive` in the keybind) so a per-app
# special-case can be re-added here later without touching hyprland.conf.
#
# History / why there's no Zoom special-case anymore: closing a Zoom window does
# not quit Zoom — it hides-not-quits and the process lingers in the background.
# That used to be handled here by pkill'ing Zoom on super+q, but that only fired
# when Zoom happened to be focused as you pressed the key. It's now handled
# properly and app-wide by the zoom-autoquit.sh watcher (launched from
# hyprland.conf via exec-once), which kills Zoom whenever its LAST window closes,
# however that window is closed. So super+q can just close the window normally.
#
# If you ever add a problem-app back here, NEVER kill by process GROUP — a window's
# pgid can include the shell that started the Hyprland session, and killing that
# group takes down the compositor. Use a per-app `pkill -x <name>` instead.
set -u

hyprctl dispatch 'hl.dsp.window.close()' >/dev/null 2>&1
exit 0
