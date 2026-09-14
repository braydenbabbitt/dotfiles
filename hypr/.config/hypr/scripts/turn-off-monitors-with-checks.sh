#!/bin/bash

# TODO: add check if playing media is in visible in a visible workspace
if playerctl --all-players status 2>/dev/null | grep -q "Playing"; then
	exit 0
fi

if pactl list sink-inputs | grep -q "Corked: no"; then
	exit 0
fi

# LOAD-BEARING — do not remove. Skip DPMS off if hyprlock is running: blanking
# monitors while hyprlock is up crashes it, leaving the session unlocked with an
# error screen. This is an open upstream bug (hyprwm/hyprlock#953), and the AMD
# DPMS half of it is specifically unfixed on this hardware (RX 7900 XT). It
# caused a real hyprlock SIGSEGV here on 2026-04-05; this guard was added the
# next day and there have been no hyprlock crashes since.
#
# Corollary: do NOT "fix" the skipped-lock case by inverting this to require
# hyprlock — that would blank precisely when it is unsafe to. The lock/blank
# ordering is handled upstream by audio-idle-inhibit.sh instead.
if pidof hyprlock >/dev/null; then
	exit 0
fi

# The field is `action`, NOT `state`. hl.dsp.dpms takes an eTogglableAction,
# parsed from the table's `action` field; an unrecognized field yields the
# enum's zero value, TOGGLE_ACTION_TOGGLE, which inverts each monitor instead
# of setting it. With `action` spelled correctly this is absolute and applies
# to every monitor, so no per-output loop is needed.
hyprctl dispatch 'hl.dsp.dpms({ action = "off" })'
