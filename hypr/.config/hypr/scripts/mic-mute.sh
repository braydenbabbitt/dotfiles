#!/usr/bin/env bash
# Global microphone mute toggle + waybar status for ALL real input sources.
#
# Operates on every real PipeWire source reported by `pactl list short sources`,
# excluding `.monitor` sources (those are loopback taps of output sinks, not mics).
#
#   toggle  If every real source is muted, unmute all; otherwise mute all. This
#           resolves a mixed state toward muted-everything. Pushes an immediate
#           waybar refresh afterward.
#   status  Emit waybar JSON for the derived state (unmuted / muted /
#           indeterminate / no-device), with a per-source tooltip.
#
# The waybar module uses "signal": 10, so we refresh with RTMIN+10.

set -euo pipefail

WAYBAR_SIGNAL=10

# Print real capture sources, one name per line (skip .monitor loopbacks).
real_sources() {
    pactl list short sources 2>/dev/null | awk '{print $2}' | grep -v '\.monitor$' || true
}

refresh_waybar() {
    pkill -RTMIN+"$WAYBAR_SIGNAL" waybar 2>/dev/null || true
}

# Echo the count of total real sources and muted real sources: "<total> <muted>".
count_states() {
    local total=0 muted=0 s state
    while IFS= read -r s; do
        [ -z "$s" ] && continue
        total=$((total + 1))
        state=$(pactl get-source-mute "$s" 2>/dev/null | awk '{print $2}')
        [ "$state" = "yes" ] && muted=$((muted + 1))
    done < <(real_sources)
    echo "$total $muted"
}

set_all_mute() {
    # $1 = 1 to mute, 0 to unmute
    local target="$1" s
    while IFS= read -r s; do
        [ -z "$s" ] && continue
        pactl set-source-mute "$s" "$target" 2>/dev/null || true
    done < <(real_sources)
}

cmd_toggle() {
    read -r total muted < <(count_states)
    if [ "$total" -eq 0 ]; then
        exit 0
    fi
    if [ "$muted" -eq "$total" ]; then
        set_all_mute 0   # all muted -> unmute all
    else
        set_all_mute 1   # all unmuted OR mixed -> mute all
    fi
    refresh_waybar
}

cmd_status() {
    read -r total muted < <(count_states)

    local class text tooltip
    if [ "$total" -eq 0 ]; then
        class="disabled"
        text="<span color='#808080'>  </span>"
        tooltip="No microphone detected"
    elif [ "$muted" -eq 0 ]; then
        class="unmuted"
        text="<span color='#00FF7F'>  </span>"
        tooltip="Mic: on (all $total unmuted)"
    elif [ "$muted" -eq "$total" ]; then
        class="muted"
        text="<span color='#FF4040'>  </span>"
        tooltip="Mic: muted (all $total)"
    else
        class="indeterminate"
        text="<span color='#FFA500'>  </span>"
        tooltip="Mic: mixed ($muted/$total muted)"
    fi

    # Per-source detail in the tooltip.
    local s state line
    while IFS= read -r s; do
        [ -z "$s" ] && continue
        state=$(pactl get-source-mute "$s" 2>/dev/null | awk '{print $2}')
        [ "$state" = "yes" ] && line="muted" || line="on"
        tooltip="$tooltip"$'\n'"  • $s: $line"
    done < <(real_sources)

    # Emit waybar JSON. Escape backslashes/quotes, and encode newlines as \n.
    esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g'; }
    printf '{"text":"%s","alt":"%s","class":"%s","tooltip":"%s"}\n' \
        "$(esc "$text")" "$class" "$class" "$(esc "$tooltip")"
}

case "${1:-status}" in
    toggle) cmd_toggle ;;
    status) cmd_status ;;
    *) echo "usage: $0 {toggle|status}" >&2; exit 2 ;;
esac
