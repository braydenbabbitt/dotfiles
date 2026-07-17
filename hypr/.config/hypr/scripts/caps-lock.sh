#!/usr/bin/env bash
# Caps Lock indicator: waybar status + Hyprland OSD notification.
#
# State is read from the kernel LED sysfs entries (/sys/class/leds/*::capslock),
# which reflect the real physical toggle regardless of which keyboard flipped it.
# Any LED reporting brightness > 0 means Caps Lock is on.
#
#   status  Emit waybar JSON for the current state (on / off). The module uses
#           "signal": 11, so the watcher refreshes it with RTMIN+11.
#   osd     Fire a dunst notification showing the current state. Uses a stable
#           notify id (dunst replace_id) so repeated toggles replace the same
#           popup instead of stacking.
#   watch   Long-lived loop that polls the LED state and, on every change, fires
#           the OSD + refreshes waybar. Launched from hyprland.conf via
#           exec-once. This deliberately does NOT bind the Caps_Lock key —
#           binding a lock key in Hyprland risks swallowing its normal toggle,
#           so we observe the resulting LED state instead.

set -euo pipefail

WAYBAR_SIGNAL=11
NOTIFY_ID=8801   # stable id -> dunst replaces the previous caps-lock popup

# Return 0 (on) if any capslock LED is lit, 1 (off) otherwise.
caps_on() {
    local f
    for f in /sys/class/leds/*::capslock/brightness; do
        [ -e "$f" ] || continue
        if [ "$(cat "$f" 2>/dev/null || echo 0)" != "0" ]; then
            return 0
        fi
    done
    return 1
}

refresh_waybar() {
    pkill -RTMIN+"$WAYBAR_SIGNAL" waybar 2>/dev/null || true
}

cmd_status() {
    local text tooltip class
    if caps_on; then
        class="on"
        text="<span color='#FFD700'> 󰪛 </span>"
        tooltip="Caps Lock: ON"
    else
        class="off"
        text=""   # empty text -> waybar hides the module entirely
        tooltip="Caps Lock: OFF"
    fi
    printf '{"text":"%s","alt":"%s","class":"%s","tooltip":"%s"}\n' \
        "$text" "$class" "$class" "$tooltip"
}

cmd_osd() {
    if caps_on; then
        notify-send -a "caps-lock" -r "$NOTIFY_ID" -u low -t 1200 \
            "Caps Lock" "ON  󰪛"
    else
        notify-send -a "caps-lock" -r "$NOTIFY_ID" -u low -t 1200 \
            "Caps Lock" "OFF"
    fi
    refresh_waybar
}

# Poll the LED state; on every change, show the OSD and refresh waybar.
cmd_watch() {
    local prev cur
    if caps_on; then prev=1; else prev=0; fi
    while true; do
        if caps_on; then cur=1; else cur=0; fi
        if [ "$cur" != "$prev" ]; then
            cmd_osd
            prev="$cur"
        fi
        sleep 0.2
    done
}

case "${1:-status}" in
    status) cmd_status ;;
    osd)    cmd_osd ;;
    watch)  cmd_watch ;;
    *) echo "usage: $0 {status|osd|watch}" >&2; exit 2 ;;
esac
