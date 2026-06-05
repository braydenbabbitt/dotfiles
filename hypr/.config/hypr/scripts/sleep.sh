#!/bin/bash

# Lock the session first, then suspend.
# Hypridle's before_sleep_cmd will trigger hyprlock via loginctl lock-session.
playerctl pause

# Ensure all processes are stopped properly before sleep
echo "Suspending system..." >> /tmp/sleep.log
sleep 1

# Use hybrid-sleep or direct suspend based on availability
if systemctl is-active --quiet systemd-hybrid-sleep.service; then
    echo "Using hybrid-sleep..." >> /tmp/sleep.log
    systemctl hybrid-sleep
else
    echo "Using regular suspend..." >> /tmp/sleep.log
    systemctl suspend
fi

echo "System resumed." >> /tmp/sleep.log
