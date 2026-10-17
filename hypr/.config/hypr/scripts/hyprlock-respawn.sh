#!/bin/bash
#
# Run hyprlock, relaunching it whenever it exits without a successful unlock.
#
# If hyprlock dies while locked, Hyprland keeps the session locked behind its
# "lock app died" screen and nothing short of a TTY rescue gets you back in.
# With misc.allow_session_lock_restore enabled in hyprland.lua, a fresh hyprlock
# can take over the orphaned lock, so this relaunches it instead. The session
# never unlocks in between; Hyprland holds it locked until the new client
# attaches.
#
# hyprlock exits 0 only on a successful unlock. Anything else (a crash, a
# signal) is logged with the exit status so the underlying cause can be
# reported upstream; hyprlock's own output was previously discarded.

set -uo pipefail

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/hyprlock"
log="$state_dir/hyprlock.log"
mkdir -p "$state_dir"

# hypridle's lock_cmd and the Super+L bind can both fire; only one respawn loop
# may own the lock, or the loser's hyprlock fails and gets relaunched forever.
exec 9>"$state_dir/respawn.lock"
flock -n 9 || exit 0

if [ -f "$log" ] && [ "$(stat -c %s "$log")" -gt 1048576 ]; then
	tail -n 2000 "$log" >"$log.tmp" && mv "$log.tmp" "$log"
fi

while true; do
	echo "=== $(date -Is) starting hyprlock" >>"$log"
	hyprlock "$@" >>"$log" 2>&1
	status=$?

	if [ "$status" -eq 0 ]; then
		echo "=== $(date -Is) unlocked" >>"$log"
		exit 0
	fi

	echo "=== $(date -Is) hyprlock exited with status $status; relaunching" >>"$log"
	sleep 1
done
