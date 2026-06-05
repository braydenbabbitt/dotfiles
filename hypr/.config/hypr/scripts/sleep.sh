#!/bin/bash

# Lock the session first, then suspend.
# hypridle's before_sleep_cmd will trigger hyprlock via loginctl lock-session.
playerctl pause
systemctl suspend
