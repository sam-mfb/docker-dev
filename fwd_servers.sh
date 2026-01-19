#!/bin/bash

# Name of the tmux session
SESSION_NAME="node_fwd_servers"

# Server commands (with environment variables included)
SERVER1_COMMAND="export GIT_CREDENTIAL_FORWARDER_PORT=38274 && gcf-server"
SERVER2_COMMAND="export OAUTH2_FORWARDER_PORT=48272 && export OAUTH2_FORWARDER_PASSTHROUGH=true && o2f-server"

# Start a new tmux session
tmux new-session -d -s "$SESSION_NAME"

# Split the tmux session into two panes
tmux send-keys -t "$SESSION_NAME:0.0" "$SERVER1_COMMAND" C-m
tmux split-window -h -t "$SESSION_NAME:0"
tmux send-keys -t "$SESSION_NAME:0.1" "$SERVER2_COMMAND" C-m

# Attach to the tmux session
tmux attach -t "$SESSION_NAME"
