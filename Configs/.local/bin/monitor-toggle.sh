#!/usr/bin/env bash

# Configuration
PRIMARY_MONITOR="DP-1"
SECONDARY_MONITOR="HDMI-A-1"

# Check if hyprctl is available
if ! command -v hyprctl &>/dev/null; then
  notify-send "Monitor Toggle" "Error: hyprctl not found"
  exit 1
fi

# Get list of active monitors
MONITORS=$(hyprctl monitors -j)

# Check if Secondary Monitor is active
IS_SECONDARY_ACTIVE=$(echo "$MONITORS" | jq -r ".[] | select(.name == \"$SECONDARY_MONITOR\") | .name")

if [[ -n $IS_SECONDARY_ACTIVE ]]; then
  # Secondary is ACTIVE -> Disable it (Single Mode)
  hyprctl keyword monitor "$SECONDARY_MONITOR, disable"
  notify-send -t 3000 "Monitor Toggle" "Single Monitor Mode Active\nDisabled: $SECONDARY_MONITOR"
else
  # Secondary is INACTIVE -> Enable it (Dual Mode)
  # Re-enable secondary monitor with specific settings
  # Based on monitors.mdx: Sony TV (HDMI-A-1) at 0x0
  hyprctl keyword monitor "$SECONDARY_MONITOR, 1920x1080@60, 0x0, 1"
  notify-send -t 3000 "Monitor Toggle" "Dual Monitor Mode Active\nEnabled: $SECONDARY_MONITOR"
fi
