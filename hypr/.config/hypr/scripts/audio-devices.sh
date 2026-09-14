#!/usr/bin/env bash
# Audio output status + input/output device switching for waybar.
#
#   watch         Streaming waybar JSON for the output (sink) module. Emits one
#                 line per state change by following `pactl subscribe`, so
#                 volume/mute/default-device changes show instantly (no
#                 polling). The tooltip lists every sink, marking the default.
#   cycle sink    Switch the default output to the next sink and move all
#                 currently playing streams onto it.
#   cycle source  Same for inputs (real sources only, .monitor loopbacks
#                 excluded), moving active recording streams.
#
# The mic module (custom/mic) polls with "signal": 10, so `cycle source`
# pushes RTMIN+10 to refresh it; the output module needs no signal because
# `watch` sees the change via pactl subscribe.

set -euo pipefail

MIC_WAYBAR_SIGNAL=10

# Icon glyphs built from codepoint escapes (not raw characters) so they can't
# be silently mangled into spaces by editors/tools. Same glyphs the built-in
# pulseaudio module used: Font Awesome headphone/phone/car + volume levels,
# nerd-font muted speaker.
ICON_MUTED=$'\U000F0581'
ICON_HEADPHONE=$'\uF025'
ICON_PHONE=$'\uF095'
ICON_CAR=$'\uF1B9'
ICON_VOL_LOW=$'\uF026'
ICON_VOL_MED=$'\uF027'
ICON_VOL_HIGH=$'\uF028'

esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g'; }

# Print "name<TAB>description" per device. $1 = sink|source.
list_devices() {
    pactl --format=json list "${1}s" 2>/dev/null \
        | jq -r '.[] | "\(.name)\t\(.description)"' \
        | { [ "$1" = source ] && grep -v $'^\S*\.monitor\t' || cat; } || true
}

emit_status() {
    local default vol mute icon text class tooltip name desc marker devinfo
    default=$(pactl get-default-sink 2>/dev/null || true)

    if [ -z "$default" ]; then
        printf '{"text":"<span color='\''#808080'\''> 󰖁 </span>","class":"disabled","tooltip":"No output device"}\n'
        return
    fi

    vol=$(pactl get-sink-volume "$default" 2>/dev/null | grep -oP '\d+(?=%)' | head -1)
    vol=${vol:-0}
    mute=$(pactl get-sink-mute "$default" 2>/dev/null | awk '{print $2}')

    if [ "$mute" = "yes" ]; then
        text="<span color='#FF4040'> ${ICON_MUTED} </span> 0% "
        class="muted"
    else
        # Device-type icon like the built-in pulseaudio module: classify the
        # default sink by form factor / icon name / active port, falling back
        # to volume-level speaker icons.
        devinfo=$(pactl --format=json list sinks 2>/dev/null \
            | jq -r --arg n "$default" '.[] | select(.name == $n)
                | "\(.properties["device.form_factor"] // "")|\(.properties["device.icon_name"] // "")|\(.active_port // "")"' \
            || true)
        case "$devinfo" in
            *headphone*|*headset*|*hands-free*) icon="<span color='#BF00FF'> ${ICON_HEADPHONE} </span>" ;;
            *phone*|*portable*) icon="<span color='#00FFFF'> ${ICON_PHONE} </span>" ;;
            *car*) icon="<span color='#FFA500'> ${ICON_CAR} </span>" ;;
            *)
                if   [ "$vol" -le 33 ]; then icon="<span color='#808080'> ${ICON_VOL_LOW} </span>"
                elif [ "$vol" -le 66 ]; then icon="<span color='#FFFF66'> ${ICON_VOL_MED} </span>"
                else                         icon="<span color='#00FF7F'> ${ICON_VOL_HIGH} </span>"
                fi ;;
        esac
        text="${icon} ${vol}% "
        class="unmuted"
    fi

    tooltip="Output: ${vol}%"
    [ "$mute" = yes ] && tooltip="$tooltip (muted)"
    tooltip="$tooltip"$'\n'"Devices:"
    while IFS=$'\t' read -r name desc; do
        [ -z "$name" ] && continue
        [ "$name" = "$default" ] && marker="►" || marker=" "
        tooltip="$tooltip"$'\n'"  $marker $desc"
    done < <(list_devices sink)
    tooltip="$tooltip"$'\n\n'"right-click: next device"

    printf '{"text":"%s","class":"%s","tooltip":"%s"}\n' \
        "$(esc "$text")" "$class" "$(esc "$tooltip")"
}

cmd_watch() {
    emit_status
    # Re-emit on any sink/server/card event ("on sink #" won't match
    # sink-input lines). Bursts of events are collapsed by the drain loop.
    pactl subscribe 2>/dev/null | grep --line-buffered -E "on (sink|server|card) #" \
        | while read -r _; do
            while read -r -t 0.1 _; do :; done
            emit_status
        done
}

cmd_cycle() {
    local kind="$1" default next
    local -a names=()
    while IFS=$'\t' read -r name _; do
        [ -n "$name" ] && names+=("$name")
    done < <(list_devices "$kind")
    [ "${#names[@]}" -lt 2 ] && exit 0

    default=$(pactl "get-default-$kind" 2>/dev/null || true)
    next="${names[0]}"
    for i in "${!names[@]}"; do
        if [ "${names[$i]}" = "$default" ]; then
            next="${names[$(( (i + 1) % ${#names[@]} ))]}"
            break
        fi
    done

    pactl "set-default-$kind" "$next"

    # Changing the default doesn't retarget streams that are already running —
    # move them over so the switch is audible/effective immediately.
    if [ "$kind" = sink ]; then
        pactl list short sink-inputs 2>/dev/null | cut -f1 \
            | while read -r id; do pactl move-sink-input "$id" "$next" 2>/dev/null || true; done
    else
        pactl list short source-outputs 2>/dev/null | cut -f1 \
            | while read -r id; do pactl move-source-output "$id" "$next" 2>/dev/null || true; done
        pkill -RTMIN+"$MIC_WAYBAR_SIGNAL" waybar 2>/dev/null || true
    fi
}

case "${1:-}" in
    watch) cmd_watch ;;
    cycle)
        case "${2:-}" in
            sink|source) cmd_cycle "$2" ;;
            *) echo "usage: $0 cycle {sink|source}" >&2; exit 2 ;;
        esac ;;
    *) echo "usage: $0 {watch|cycle sink|cycle source}" >&2; exit 2 ;;
esac
