#!/usr/bin/env bash
set -euo pipefail

set -a
source "$(dirname "$0")/.env"
set +a

echo "[svc_stream] $(date -Is) starting"

until arecord -l | grep -q "Loopback"; do
  echo "[svc_stream] Waiting for ALSA Loopback device..."
  sleep 2
done

[[ -s "$BG_FILE" ]] || { echo "[svc_stream] ERROR: background video missing: $BG_FILE"; exit 1; }

if [[ ! -s "$ARTWORK_FILE" ]]; then
  ffmpeg -hide_banner -loglevel error -y \
    -f lavfi -i color=size=100x100:rate=1:color=black \
    -frames:v 1 "$ARTWORK_FILE"
fi

ffmpeg -hide_banner -loglevel info \
  -re -stream_loop -1 -thread_queue_size 2048 -i "$BG_FILE" \
  -re -thread_queue_size 1024 -framerate 0.5 -loop 1 -i "$ARTWORK_URL" \
  -thread_queue_size 65536 -f alsa -itsoffset 0.1 -ar 48000 -i "${ALSA_CAPTURE}" \
  -filter_complex "\
[0:v]scale=${STREAM_WIDTH}:${STREAM_HEIGHT},setsar=1[v0]; \
[v0][1:v]overlay=10:10:format=auto:eval=frame, \
drawtext=fontfile=${FONT_PATH}:textfile=${TEXT_FILE}:reload=1:fontsize=24:fontcolor=white:shadowx=2:shadowy=2:x=120:y=15[outv]" \
  -map "[outv]" -map 2:a \
  -c:v libx264 -pix_fmt yuv420p -preset $X264_PRESET -b:v $VIDEO_BR \
  -x264-params keyint=$GOP:min-keyint=$FPS:scenecut=0 \
  -g $GOP -r $FPS \
  -c:a aac -b:a $AUDIO_BR -threads:a 1 -async 1 \
  -fflags +nobuffer -flush_packets 0 \
  -reconnect 1 -reconnect_streamed 1 -reconnect_delay_max 5 \
  -f flv "$YOUTUBE_RTMP"
