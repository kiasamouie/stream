#!/usr/bin/env bash
set -uo pipefail

set -a
source "$(dirname "$0")/.env"
set +a

PLAYLIST_URL="${1:-${PLAYLIST_URL:-}}"
if [[ -z "$PLAYLIST_URL" && -f "$PLAYLIST_FILE" ]]; then
  PLAYLIST_URL="$(<"$PLAYLIST_FILE")"
fi
if [[ -z "$PLAYLIST_URL" ]]; then
  echo "Error: No playlist URL provided." >&2
  exit 1
fi

# Wait for ALSA Loopback device
until aplay -l | grep -q "Loopback"; do
  echo "[svc_audio] Waiting for ALSA Loopback device..."
  sleep 2
done

echo "[svc_audio] Starting MPV playback on ALSA loopback..."

while true; do
  mpv \
    --no-config \
    --no-video \
    --ytdl=yes \
    --ytdl-format="bestaudio/best" \
    --loop-playlist=inf \
    --ao=alsa --audio-device="alsa/${ALSA_PLAYBACK}" \
    --alsa-buffer-time=500000 \
    --alsa-periods=8 \
    --audio-samplerate=48000 \
    --audio-buffer=0.5 \
    --cache=yes \
    --cache-secs=10 \
    --script="$METADATA_SCRIPT" \
    --idle=yes \
    "$PLAYLIST_URL"

  echo "[svc_audio] MPV exited — restarting in 3 seconds..."
  sleep 3
done
