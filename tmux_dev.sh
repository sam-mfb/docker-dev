#!/bin/bash

#Max and min widths
MAX_WIDTH=80
MIN_WIDTH=40

# Name the tmux session
SESSION_NAME="dev_env"

# Set the working directory to the first argument, or default to the current working directory
WORKING_DIR="${1:-$PWD}"

# Normalize the working directory to an absolute path
WORKING_DIR=$(realpath "$WORKING_DIR")

# Verify that the working directory exists
if [ ! -d "$WORKING_DIR" ]; then
  echo "Error: Directory '$WORKING_DIR' does not exist."
  exit 1
fi

# Start a new tmux session with the given name
tmux new-session -d -s "$SESSION_NAME" -c "$WORKING_DIR"

# Attach to the session temporarily to initialize pane size
tmux attach-session -t "$SESSION_NAME" \; detach-client

# Get the total width of the terminal
TOTAL_WIDTH=$(tmux display -p '#{pane_width}')

# Calculate the width for the left pane (25% or max 80 characters)
LEFT_WIDTH=$((TOTAL_WIDTH / 4))
if [ "$LEFT_WIDTH" -gt "$MAX_WIDTH" ]; then
  LEFT_WIDTH=$MAX_WIDTH
fi
if [ "$LEFT_WIDTH" -lt "$MIN_WIDTH" ]; then
  LEFT_WIDTH=$MIN_WIDTH
fi

RIGHT_WIDTH=$((TOTAL_WIDTH - LEFT_WIDTH))
echo "TOTAL_WIDTH = $((TOTAL_WIDTH))"
echo "LEFT_WIDTH = $((LEFT_WIDTH))"

# Split the window vertically, setting the right pane to the calculated width
tmux split-window -h -l "$RIGHT_WIDTH" -c "$WORKING_DIR"

# Adjust focus to ensure left pane remains primary (optional)
tmux select-pane -L

# Attach to the session
tmux attach-session -t "$SESSION_NAME"

