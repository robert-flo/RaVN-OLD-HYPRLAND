#!/usr/bin/env bash
set -euo pipefail

# Screen recording utility (WF-Recorder wrapper) for video/GIF
MODE="${1:-video}" # video | gif
OUTDIR="$HOME/Videos"
TS="$(date +'%Y-%m-%d_%H-%M-%S')"
TMP="$OUTDIR/.recording_tmp.mp4"

if ! command -v wf-recorder &>/dev/null; then
  notify-send -u critical "wf-recorder" "Error: wf-recorder is not installed. Please install it."
  exit 1
fi

if ! command -v slurp &>/dev/null; then
  notify-send -u critical "wf-recorder" "Error: slurp is not installed. Please install it."
  exit 1
fi

mkdir -p "$OUTDIR"

# Detect focused monitor and scale
MON_INFO="$(hyprctl monitors -j | jq -r '.[] | select(.focused)')"
MON_NAME="$(jq -r '.name' <<<"$MON_INFO")"
MON_WIDTH="$(jq -r '.width' <<<"$MON_INFO")"
MON_HEIGHT="$(jq -r '.height' <<<"$MON_INFO")"
MON_REFRESH="$(jq -r '.refreshRate' <<<"$MON_INFO")"
MON_X="$(jq -r '.x' <<<"$MON_INFO")"
MON_Y="$(jq -r '.y' <<<"$MON_INFO")"
MON_SCALE="$(jq -r '.scale' <<<"$MON_INFO")"

restore_scale() {
  if [[ -f "/tmp/hyde_record_rule_$MON_NAME" ]]; then
    local orig_rule
    orig_rule=$(cat "/tmp/hyde_record_rule_$MON_NAME")
    rm -f "/tmp/hyde_record_rule_$MON_NAME"
    hyprctl keyword monitor "$orig_rule" >/dev/null
  else
    hyprctl keyword monitor "$MON_NAME,preferred,auto,1.5" >/dev/null
  fi
}

if pgrep -x wf-recorder >/dev/null; then
  notify-send "wf-recorder" "Recording stopped"
  pkill -INT wf-recorder
  # Wait for wf-recorder to fully terminate
  while pgrep -x wf-recorder >/dev/null; do
    sleep 0.1
  done

  if [[ "$MODE" == "gif" && -f "$TMP" ]]; then
    GIF="$OUTDIR/recording-$TS.gif"
    notify-send "wf-recorder" "Converting to GIF…"

    ffmpeg -y -i "$TMP" \
      -vf "fps=12,scale=1280:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" \
      "$GIF"

    wl-copy --type image/gif <"$GIF"
    printf 'file://%s\n' "$GIF" | wl-copy --type text/uri-list

    rm -f "$TMP"
    notify-send "wf-recorder" "GIF copied to clipboard"
  fi
  restore_scale
else
  notify-send "wf-recorder" "Recording started (scale → 1)"

  # Save the original monitor rule to a temp file before we change it
  ORIG_RULE="${MON_NAME},${MON_WIDTH}x${MON_HEIGHT}@${MON_REFRESH},${MON_X}x${MON_Y},${MON_SCALE}"
  echo "$ORIG_RULE" > "/tmp/hyde_record_rule_$MON_NAME"

  # Force scale to 1 keeping original resolution and position
  hyprctl keyword monitor "${MON_NAME},${MON_WIDTH}x${MON_HEIGHT}@${MON_REFRESH},${MON_X}x${MON_Y},1" >/dev/null
  sleep 0.25 # allow compositor to settle

  OUTFILE="$(
    [[ "$MODE" == "gif" ]] && echo "$TMP" ||
      echo "$OUTDIR/recording-$TS.mp4"
  )"

  wf-recorder -g "$(slurp)" -f "$OUTFILE"
fi
