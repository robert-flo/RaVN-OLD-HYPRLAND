#!/usr/bin/env bash
# Toggle opacity of active window

notify-send "Toggle Opacity" "Script execution start"
{
  echo "$(date): Script execution start"
  echo "User: $(whoami)"
  echo "PATH: $PATH"
} >> /tmp/toggle_opacity.log

address=$(hyprctl activewindow -j | jq -r '.address')
hyprctl dispatch setprop "address:$address" opaque toggle
notify-send "Transparency Toggled" "Window: $address"
