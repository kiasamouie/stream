#!/usr/bin/env bash
set -euo pipefail
SESSION="streamlab"
tmux kill-session -t "$SESSION" 2>/dev/null || true
echo "Stopped session $SESSION."
