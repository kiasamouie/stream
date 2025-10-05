#!/usr/bin/env bash
set -euo pipefail

set -a
source "$(dirname "$0")/.env"
set +a
export PULSE_SERVER

PLAYLIST_URL="${1:-${PLAYLIST_URL:-}}"
if [[ -z "$PLAYLIST_URL" && -f "$PLAYLIST_FILE" ]]; then
  PLAYLIST_URL="$(<"$PLAYLIST_FILE")"
fi
if [[ -z "$PLAYLIST_URL" ]]; then
  echo "Error: No playlist URL provided." >&2
  exit 1
fi

# Wait until system PulseAudio is up
until pactl info >/dev/null 2>&1; do
  echo "[svc_audio] Waiting for PulseAudio system daemon..."
  sleep 2
done

# Ensure null sink exists (system mode)
if ! pactl list short sinks | grep -q "$NULL_SINK_NAME"; then
  pactl load-module module-null-sink sink_name="$NULL_SINK_NAME" sink_properties=device.description="YTStream" >/dev/null
fi

mpv \
  --no-config \
  --no-video \
  --ytdl=yes \
  --ytdl-format="bestaudio/best" \
  --loop-playlist=inf \
  --ao=pulse --audio-device="pulse/$NULL_SINK_NAME" \
  --script="$METADATA_SCRIPT" \
  "$PLAYLIST_URL"
