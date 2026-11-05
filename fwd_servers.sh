#!/bin/bash

# Name of the tmux session
SESSION_NAME="node_fwd_servers"

# Server commands (with environment variables included)
SERVER1_COMMAND="export GIT_CREDENTIAL_FORWARDER_PORT=38274 && gcf-server"
SERVER2_COMMAND="export OAUTH2_FORWARDER_PORT=48272 && export OAUTH2_FORWARDER_PASSTHROUGH=true && o2f-server"

# Check each forwarder package for a newer version on npm and offer to
# upgrade it. Never upgrades without an explicit "y".
check_for_update() {
    local pkg="$1"
    local installed latest answer

    installed=$(npm ls -g --depth=0 --json "$pkg" 2>/dev/null \
        | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{console.log(JSON.parse(s).dependencies["'"$pkg"'"].version)}catch{}})')
    latest=$(npm view "$pkg" version 2>/dev/null)

    if [ -z "$latest" ]; then
        echo "Could not check npm for the latest version of $pkg; skipping."
        return
    fi
    if [ -z "$installed" ]; then
        echo "$pkg is not installed globally (latest is $latest)."
        read -r -p "Install $pkg@$latest now? [y/N] " answer
    elif [ "$installed" = "$latest" ]; then
        echo "$pkg is up to date ($installed)."
        return
    else
        echo "$pkg: installed $installed, latest $latest."
        read -r -p "Upgrade $pkg to $latest? [y/N] " answer
    fi

    case "$answer" in
        [yY]|[yY][eE][sS]) npm install -g "$pkg@$latest" ;;
        *) echo "Leaving $pkg as is." ;;
    esac
}

check_for_update git-credential-forwarder
check_for_update oauth2-forwarder

# Start a new tmux session
tmux new-session -d -s "$SESSION_NAME"

# Split the tmux session into two panes
tmux send-keys -t "$SESSION_NAME:0.0" "$SERVER1_COMMAND" C-m
tmux split-window -h -t "$SESSION_NAME:0"
tmux send-keys -t "$SESSION_NAME:0.1" "$SERVER2_COMMAND" C-m

# Attach to the tmux session
tmux attach -t "$SESSION_NAME"
