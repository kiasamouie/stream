#!/bin/bash
set -e

SESSION="streamlab"
LOGDIR="$HOME/streamlab/logs"
SCRIPTDIR="$HOME/streamlab/scripts"

mkdir -p "$LOGDIR"

# Kill old session if exists
tmux has-session -t $SESSION 2>/dev/null && tmux kill-session -t $SESSION

# Create new session
tmux new-session -d -s $SESSION -n icecast

# Icecast
tmux send-keys -t $SESSION:0 "cd ~/streamlab && icecast2 -c config/icecast.xml 2>&1 | tee $LOGDIR/icecast.log" C-m

# Liquidsoap
tmux new-window -t $SESSION -n liquidsoap
tmux send-keys -t $SESSION:1 "cd ~/streamlab && liquidsoap liquidsoap/soundcloud_radio.liq 2>&1 | tee $LOGDIR/liquidsoap.log" C-m

# Feeder
tmux new-window -t $SESSION -n feeder
tmux send-keys -t $SESSION:2 "cd ~/streamlab && set -a && source .env && set +a && python3 feeder/sc_feeder.py 2>&1 | tee $LOGDIR/feeder.log" C-m

# FFmpeg
tmux new-window -t $SESSION -n ffmpeg
tmux send-keys -t $SESSION:3 "cd ~/streamlab && ./scripts/stream.sh 2>&1 | tee $LOGDIR/ffmpeg.log" C-m

echo "✅ Streamlab started in tmux session '$SESSION'."
echo "Use:   tmux attach -t $SESSION   to view."
echo "Logs:  $LOGDIR/"
