#!/bin/bash

# Name the tmux session
SESSION_NAME="dev_env"

# Start a new tmux session with the given name
tmux new-session -d -s "$SESSION_NAME"

# Attach to the session temporarily to initialize pane size
tmux attach-session -t "$SESSION_NAME" \; detach-client

# Get the total width of the terminal
TOTAL_WIDTH=$(tmux display -p '#{pane_width}')

# Calculate the width for the left pane (25% or max 80 characters)
LEFT_WIDTH=$((TOTAL_WIDTH / 4))
if [ "$LEFT_WIDTH" -gt 80 ]; then
  LEFT_WIDTH=80
fi

RIGHT_WIDTH=$((TOTAL_WIDTH - LEFT_WIDTH))
echo "TOTAL_WIDTH = $((TOTAL_WIDTH))"
echo "LEFT_WIDTH = $((LEFT_WIDTH))"

# Split the window vertically, setting the right pane to the calculated width
tmux split-window -h -l "$RIGHT_WIDTH"

# Adjust focus to ensure left pane remains primary (optional)
tmux select-pane -L

# Attach to the session
tmux attach-session -t "$SESSION_NAME"
