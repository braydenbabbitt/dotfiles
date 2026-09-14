#!/bin/bash
#
# Hold a systemd idle inhibitor for as long as audio is actually playing.
#
# WHY THIS EXISTS
#
# lock_with_checks.sh (300s) and turn-off-monitors-with-checks.sh (330s) each
# ask "is audio playing right now?" and bail if so. But they ask 30 seconds
# apart, so a track that stops in between produces the broken case:
#
#   audio playing at 300s  -> lock SKIPPED
#   audio stopped  at 330s -> monitors BLANK anyway
#
# ...leaving the screens dark on an unlocked session. The two guards decide
# independently about a condition that moves underneath them.
#
# Rather than have the scripts re-sample a moving target, this keeps the idle
# clock from advancing at all while audio plays. hypridle honors
# systemd-inhibit --what=idle (its `ignore_systemd_inhibit` defaults to false),
# so with an inhibitor held neither listener fires; when playback stops the
# inhibitor is released and the full 300s/330s sequence runs in order, lock
# first. The existing guards stay as a backstop for edge cases (e.g. audio
# starting mid-countdown).
#
# NOTE: the DPMS-off path must never run while hyprlock is up — that is an open
# upstream AMD/hyprlock crash (hyprwm/hyprlock#953). Nothing here changes that;
# the `pidof hyprlock` guard in turn-off-monitors-with-checks.sh is load-bearing
# and must stay.

set -uo pipefail

INHIBIT_PID=""

# True while any player reports Playing, or any PulseAudio sink-input is
# uncorked. Mirrors the checks in the two guard scripts so behavior agrees.
audio_active() {
	if playerctl --all-players status 2>/dev/null | grep -q "Playing"; then
		return 0
	fi

	if pactl list sink-inputs 2>/dev/null | grep -q "Corked: no"; then
		return 0
	fi

	return 1
}

release_inhibitor() {
	if [ -n "$INHIBIT_PID" ] && kill -0 "$INHIBIT_PID" 2>/dev/null; then
		kill "$INHIBIT_PID" 2>/dev/null
		wait "$INHIBIT_PID" 2>/dev/null
	fi
	INHIBIT_PID=""
}

# Don't leak the inhibitor if this script is killed or Hyprland exits.
trap 'release_inhibitor; exit 0' TERM INT HUP EXIT

while true; do
	if audio_active; then
		if [ -z "$INHIBIT_PID" ] || ! kill -0 "$INHIBIT_PID" 2>/dev/null; then
			# `sleep infinity` holds the inhibitor; killing it releases.
			systemd-inhibit --what=idle \
				--who="hypr-audio" \
				--why="Audio is playing" \
				--mode=block \
				sleep infinity &
			INHIBIT_PID=$!
		fi
	else
		release_inhibitor
	fi

	sleep 10
done
