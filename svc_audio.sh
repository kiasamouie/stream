#!/usr/bin/env bash
set -euo pipefail

# Load environment variables
set -a
source "$(dirname "$0")/.env"
set +a

PLAYLIST_URL="${1:-${PLAYLIST_URL:-}}"
if [[ -z "$PLAYLIST_URL" && -f "$PLAYLIST_FILE" ]]; then
  PLAYLIST_URL="$(<"$PLAYLIST_FILE")"
fi
if [[ -z "$PLAYLIST_URL" ]]; then
  echo "Error: No playlist URL provided. Put it in $PLAYLIST_FILE, set PLAYLIST_URL, or pass as arg." >&2
  exit 1
fi

# make sure the null sink exists
if ! pactl list short sinks | grep -q "$NULL_SINK_NAME"; then
  pactl load-module module-null-sink sink_name="$NULL_SINK_NAME" sink_properties=device.description="YTStream" >/dev/null
fi

# just play audio to null sink + run Lua metadata script
mpv \
  --no-config \
  --no-video \
  --ytdl=yes \
  --ytdl-format="bestaudio/best" \
  --loop-playlist=inf \
  --ao=pulse --audio-device="pulse/$NULL_SINK_NAME" \
  --script="$METADATA_SCRIPT" \
  "$PLAYLIST_URL"
