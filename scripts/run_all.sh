#!/usr/bin/env bash
set -euo pipefail
cd "/home/kia/streamlab"
echo "Installing dependencies (sudo may prompt for your password)..."
sudo apt-get update
sudo apt-get install -y ffmpeg icecast2 liquidsoap moreutils python3-pip fonts-dejavu-core tmux
pip3 install --upgrade yt-dlp requests

echo
echo "NOTE: Edit /home/kia/streamlab/.env to set SC_PLAYLIST and RTMP_URL before streaming."
echo

# Start tmux session with 4 windows
SESSION="streamlab"
tmux has-session -t "$SESSION" 2>/dev/null && { echo "Session $SESSION already running."; exit 0; }
tmux new-session -d -s "$SESSION" -n icecast "icecast2 -b -c /home/kia/streamlab/config/icecast.xml"
sleep 1
tmux new-window  -t "$SESSION"   -n liquidsoap "liquidsoap /home/kia/streamlab/liquidsoap/soundcloud_radio.liq"
tmux new-window  -t "$SESSION"   -n feeder "bash -lc 'cd /home/kia/streamlab && set -a && source .env && set +a && python3 feeder/sc_feeder.py'"
tmux new-window  -t "$SESSION"   -n ffmpeg "bash -lc 'cd /home/kia/streamlab && ./scripts/stream.sh'"
echo "Started tmux session '$SESSION'. Attach with:  tmux attach -t $SESSION"
