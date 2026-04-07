#!/bin/bash

# TODO: add check if playing media is in visible in a visible workspace
if playerctl --all-players status 2>/dev/null | grep -q "Playing"; then
	exit 0
fi

if pactl list sink-inputs | grep -q "Corked: no"; then
	exit 0
fi

# Skip DPMS off if hyprlock is running — turning off monitors while
# hyprlock is active can cause hyprlock to crash, leaving the session
# unlocked with an error screen.
if pidof hyprlock >/dev/null; then
	exit 0
fi

hyprctl dispatch dpms off
