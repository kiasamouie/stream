#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source .env

if [ ! -f "$BG_MP4" ]; then
  echo "Background video not found at: $BG_MP4"
  echo "Put a file at that path or edit BG_MP4 in $PWD/.env"
  exit 1
fi

ffmpeg \
 -re -stream_loop -1 -i "$BG_MP4" \
 -re -i "http://127.0.0.1:8000/live.mp3" \
 -f image2 -framerate 2 -loop 1 -i "$PWD/tmp/artwork.png" \
 -filter_complex "\
 [0:v]scale=1920:1080:force_original_aspect_ratio=decrease,setsar=1,format=yuv420p[bg]; \
 [2:v]scale=300:-1[art]; \
 [bg][art]overlay=main_w-320:main_h-320:format=auto[v1]; \
 [v1]drawbox=x=iw-340:y=ih-340:w=320:h=320:color=black@0.4:t=fill[v2]; \
 [v2]drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf:\
      textfile=$PWD/tmp/nowplaying.txt:reload=1:\
      x=40:y=(h-120):fontsize=36:fontcolor=white:box=1:boxcolor=0x000000AA:boxborderw=10[vout]" \
 -map "[vout]" -map 1:a \
 -c:v libx264 -preset veryfast -b:v 4500k -maxrate 5000k -bufsize 10M -pix_fmt yuv420p \
 -c:a aac -b:a 160k -ar 44100 -ac 2 \
 -f flv "$RTMP_URL"
