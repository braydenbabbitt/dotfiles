#!/usr/bin/env bash
#
# Single-monitor toggle.
# Usage: single-monitor-toggle.sh <L|C|R>
#
# Press a letter to collapse everything onto that one monitor:
#   - disables the other two monitors
#   - moves every window off the disabled monitors onto the selected monitor as
#     new sequential workspaces, grouped by source monitor (windows already on
#     the selected monitor keep their slots first)
#   - records each window's original workspace so it can be restored
#
# Press the *same* letter again to toggle back:
#   - re-enables all three monitors
#   - returns each recorded window to its original workspace
#
# Pressing a *different* letter while in single-monitor mode restores first,
# then collapses onto the new monitor.

set -euo pipefail

# Make hyprctl reachable when launched from a keybind with a minimal env.
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export HYPRLAND_INSTANCE_SIGNATURE="$(ls "$XDG_RUNTIME_DIR/hypr/" | head -1)"
HYPRCTL="/usr/bin/hyprctl"

STATE_FILE="$XDG_RUNTIME_DIR/hypr-single-monitor.state"

# Monitor name mapping — update these if monitor ports change
LEFT="HDMI-A-1"
CENTER="DP-2"
RIGHT="DP-3"

# Canonical monitor configs (must match hyprland.conf)
declare -A MON_CONFIG=(
	["$LEFT"]="$LEFT,2560x1440@144,0x0,1"
	["$CENTER"]="$CENTER,2560x1440@144,2560x0,1"
	["$RIGHT"]="$RIGHT,2560x1440@144,5120x0,1"
)

TARGET_LETTER="${1:-}"
case "$TARGET_LETTER" in
L) TARGET_MON="$LEFT"; BASE=1; LABEL="Left" ;;
C) TARGET_MON="$CENTER"; BASE=6; LABEL="Center" ;;
R) TARGET_MON="$RIGHT"; BASE=11; LABEL="Right" ;;
*)
	notify-send "Single monitor" "Usage: single-monitor-toggle.sh <L|C|R>"
	exit 1
	;;
esac

enable_all_monitors() {
	$HYPRCTL keyword monitor "${MON_CONFIG[$LEFT]}"
	$HYPRCTL keyword monitor "${MON_CONFIG[$CENTER]}"
	$HYPRCTL keyword monitor "${MON_CONFIG[$RIGHT]}"
}

# Move each recorded window back to its original workspace, then clear state.
restore_windows() {
	[ -f "$STATE_FILE" ] || return 0
	# Skip the first line (the active target letter); the rest are "address ws".
	tail -n +2 "$STATE_FILE" | while read -r addr ws; do
		[ -n "$addr" ] || continue
		# Only move windows that still exist.
		if $HYPRCTL clients -j | jq -e --arg a "$addr" '.[] | select(.address==$a)' >/dev/null 2>&1; then
			$HYPRCTL dispatch movetoworkspacesilent "$ws,address:$addr"
		fi
	done
}

# Read the currently-active letter from state (empty if none).
ACTIVE_LETTER=""
if [ -f "$STATE_FILE" ]; then
	ACTIVE_LETTER="$(head -n1 "$STATE_FILE")"
fi

# --- TOGGLE OFF: same letter pressed while active → restore everything ---
if [ "$ACTIVE_LETTER" = "$TARGET_LETTER" ]; then
	enable_all_monitors
	restore_windows
	rm -f "$STATE_FILE"
	notify-send "Monitors restored" "All three monitors re-enabled"
	exit 0
fi

# --- SWITCHING LETTERS: already active on a different monitor ---
# Restore original positions and monitors first, then collapse onto the new one.
if [ -n "$ACTIVE_LETTER" ]; then
	enable_all_monitors
	restore_windows
	rm -f "$STATE_FILE"
fi

# --- ACTIVATE: collapse everything onto TARGET_MON ---

# 1. Snapshot current placement and record origins for restore.
#    Sorted by workspace id so output is deterministic.
SNAPSHOT="$($HYPRCTL clients -j | jq -r 'sort_by(.workspace.id) | .[] | "\(.address) \(.workspace.id)"')"

{
	echo "$TARGET_LETTER"
	echo "$SNAPSHOT"
} >"$STATE_FILE"

# 2. Partition windows into "already on target monitor" vs "off-monitor",
#    where target ownership is decided by the workspace-id range:
#      Left 1-5, Center 6-10, Right 11-15.
RANGE_LO="$BASE"
RANGE_HI="$((BASE + 4))"

ON_TARGET=()   # addresses already on the target monitor's range (keep order)
OFF_TARGET=()  # addresses on the other monitors (ascending workspace id)

while read -r addr ws; do
	[ -n "$addr" ] || continue
	if [ "$ws" -ge "$RANGE_LO" ] && [ "$ws" -le "$RANGE_HI" ]; then
		ON_TARGET+=("$addr")
	else
		OFF_TARGET+=("$addr")
	fi
done <<<"$SNAPSHOT"

# 3. Assign contiguous workspaces starting at BASE.
#    On-target windows are compacted first, then off-target windows appended
#    grouped by source monitor (SNAPSHOT is already ascending by workspace id,
#    so Center windows precede Right windows, etc.).
SLOT="$BASE"
for addr in "${ON_TARGET[@]:-}"; do
	[ -n "$addr" ] || continue
	$HYPRCTL dispatch movetoworkspacesilent "$SLOT,address:$addr"
	SLOT="$((SLOT + 1))"
done
for addr in "${OFF_TARGET[@]:-}"; do
	[ -n "$addr" ] || continue
	$HYPRCTL dispatch movetoworkspacesilent "$SLOT,address:$addr"
	SLOT="$((SLOT + 1))"
done

# 4. Disable the other two monitors.
for mon in "$LEFT" "$CENTER" "$RIGHT"; do
	if [ "$mon" != "$TARGET_MON" ]; then
		$HYPRCTL keyword monitor "$mon,disable"
	fi
done

# 5. Focus the first workspace on the target monitor.
$HYPRCTL dispatch workspace "$BASE"

WS_COUNT="$((SLOT - BASE))"
notify-send "Single monitor" "$LABEL — $WS_COUNT workspace(s)"
