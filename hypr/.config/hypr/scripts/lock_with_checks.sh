#!/bin/bash

if playerctl --all-players status 2>/dev/null | grep -q "Playing"; then
  exit 0
fi

if pactl list sink-inputs | grep -q "Corked: no"; then
  exit 0
fi

loginctl lock-session
